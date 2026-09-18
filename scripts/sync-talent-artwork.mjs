#!/usr/bin/env node

import { writeFileSync } from "node:fs";

const directoryURL = "https://hololive.hololivepro.com/en/talents/";
const outputPath = process.argv[2] ?? "HoloWish/Resources/talent-artwork.json";

async function fetchHTML(url) {
  const response = await fetch(url, {
    headers: { "User-Agent": "holoWish/1.0 personal collection app" },
  });
  if (!response.ok) throw new Error(`${response.status} while fetching ${url}`);
  return response.text();
}

function decodeName(value) {
  return value
    .replaceAll("&#8217;", "’")
    .replace(/^\[(Affiliate|Alum|Retirement)\] /, "")
    .trim();
}

async function mapWithConcurrency(values, limit, transform) {
  const results = new Array(values.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < values.length) {
      const index = nextIndex++;
      results[index] = await transform(values[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, values.length) }, worker));
  return results;
}

const directoryHTML = await fetchHTML(directoryURL);
const list = directoryHTML.match(/<ul class="talent_list clearfix">([\s\S]*?)<\/ul>/)?.[1];
if (!list) throw new Error("Could not find the official talent list.");

const talents = [...list.matchAll(
  /<li>[\s\S]*?<a href="([^"]+)">[\s\S]*?<h3>\s*([^<\r\n]+)<span>([^<]*)<\/span>/g
)].map((match) => ({
  name: decodeName(match[2]),
  japaneseName: match[3].trim(),
  profileURL: match[1],
}));

const records = await mapWithConcurrency(talents, 6, async (talent) => {
  const profileHTML = await fetchHTML(talent.profileURL);
  const artworkURLs = [...profileHTML.matchAll(/src="([^"]+)"\s+alt="全身画像"/g)]
    .map((match) => match[1])
    .filter((url, index, values) => values.indexOf(url) === index);
  process.stdout.write(`\rFetched ${talent.name.padEnd(34)} ${artworkURLs.length} pose(s)`);
  return { ...talent, artworkURLs };
});

process.stdout.write("\n");
writeFileSync(outputPath, `${JSON.stringify({ source: directoryURL, records }, null, 2)}\n`);
console.log(`Wrote ${records.length} talent artwork records to ${outputPath}.`);
