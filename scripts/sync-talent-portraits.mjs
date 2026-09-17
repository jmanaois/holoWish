#!/usr/bin/env node

import { mkdirSync, readFileSync } from "node:fs";
import { basename, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const htmlPath = process.argv[2];
const outputDirectory = process.argv[3];

if (!htmlPath || !outputDirectory) {
  console.error("Usage: node scripts/sync-talent-portraits.mjs <talents.html> <output-directory>");
  process.exit(1);
}

const html = readFileSync(htmlPath, "utf8");
const list = html.match(/<ul class="talent_list clearfix">([\s\S]*?)<\/ul>/)?.[1];

if (!list) {
  throw new Error("Could not find the official talent list in the supplied HTML.");
}

const entries = [...list.matchAll(
  /<li>[\s\S]*?<a href="([^"]+)">[\s\S]*?<img[^>]+src="([^"]+)"[^>]*>[\s\S]*?<h3>\s*([^<\r\n]+)<span>([^<]*)<\/span>/g
)].map((match) => ({
  profileURL: match[1],
  imageURL: match[2],
  name: match[3].trim().replaceAll("&#8217;", "’"),
  japaneseName: match[4].trim(),
}));

if (entries.length < 1) {
  throw new Error("No talent entries were found in the supplied HTML.");
}

mkdirSync(outputDirectory, { recursive: true });

for (const entry of entries) {
  const destination = resolve(outputDirectory, basename(new URL(entry.imageURL).pathname));
  const result = spawnSync("curl", ["-L", "--fail", "--silent", "--show-error", entry.imageURL, "-o", destination], {
    stdio: "inherit",
  });
  if (result.status !== 0) process.exit(result.status ?? 1);

  const resize = spawnSync("sips", ["-Z", "192", destination], { stdio: "ignore" });
  if (resize.status !== 0) {
    throw new Error(`Could not resize ${entry.name}'s portrait with sips.`);
  }
}

console.log(`Downloaded ${entries.length} official talent portraits to ${outputDirectory}.`);
