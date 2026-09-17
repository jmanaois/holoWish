#!/usr/bin/env node

import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { basename, extname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";

const portraitDirectory = process.argv[2];
if (!portraitDirectory) {
  console.error("Usage: node scripts/extract-talent-colors.mjs <portrait-directory>");
  process.exit(1);
}

function hsv(red, green, blue) {
  const maximum = Math.max(red, green, blue);
  const minimum = Math.min(red, green, blue);
  const delta = maximum - minimum;
  const saturation = maximum === 0 ? 0 : delta / maximum;
  if (delta === 0) return { hue: 0, saturation, value: maximum };
  let rawHue;
  if (maximum === red) rawHue = ((green - blue) / delta) % 6;
  else if (maximum === green) rawHue = (blue - red) / delta + 2;
  else rawHue = (red - green) / delta + 4;
  return { hue: (rawHue * 60 + 360) % 360, saturation, value: maximum };
}

function dominantColors(buffer) {
  const pixelOffset = buffer.readUInt32LE(10);
  const width = buffer.readInt32LE(18);
  const height = Math.abs(buffer.readInt32LE(22));
  const bitsPerPixel = buffer.readUInt16LE(28);
  if (bitsPerPixel !== 32) throw new Error(`Expected a 32-bit BMP, got ${bitsPerPixel}-bit.`);

  const buckets = new Map();
  for (let index = 0; index < width * height; index += 1) {
    const offset = pixelOffset + index * 4;
    const blue = buffer[offset] / 255;
    const green = buffer[offset + 1] / 255;
    const red = buffer[offset + 2] / 255;
    const alpha = buffer[offset + 3] / 255;
    const color = hsv(red, green, blue);
    if (alpha < 0.5 || color.saturation < 0.22 || color.value < 0.18 || color.value > 0.98) continue;

    const key = Math.floor(color.hue / 15) * 3 + Math.min(2, Math.floor(color.value * 3));
    const weight = alpha * Math.pow(color.saturation, 1.6) * (0.45 + color.value);
    const bucket = buckets.get(key) ?? { score: 0, red: 0, green: 0, blue: 0 };
    bucket.score += weight;
    bucket.red += red * weight;
    bucket.green += green * weight;
    bucket.blue += blue * weight;
    buckets.set(key, bucket);
  }

  const ranked = [...buckets.values()].sort((left, right) => right.score - left.score);
  const result = [];
  for (const bucket of ranked) {
    const red = bucket.red / bucket.score;
    const green = bucket.green / bucket.score;
    const blue = bucket.blue / bucket.score;
    const hue = hsv(red, green, blue).hue;
    const isSeparated = result.every((existing) => {
      const distance = Math.abs(existing.hue - hue);
      return Math.min(distance, 360 - distance) >= 28;
    });
    if (!isSeparated && result.length > 0) continue;
    const packed = Math.round(red * 255) * 0x10000 + Math.round(green * 255) * 0x100 + Math.round(blue * 255);
    result.push({ hue, packed });
    if (result.length === 2) break;
  }
  return result.map(({ packed }) => `0x${packed.toString(16).padStart(6, "0").toUpperCase()}`);
}

const temporaryDirectory = mkdtempSync(join(tmpdir(), "holowish-colors-"));
try {
  const files = readdirSync(portraitDirectory)
    .filter((file) => [".png", ".webp", ".jpg", ".jpeg"].includes(extname(file).toLowerCase()))
    .sort();

  for (const file of files) {
    const output = join(temporaryDirectory, `${basename(file, extname(file))}.bmp`);
    const result = spawnSync("sips", ["-z", "80", "80", "-s", "format", "bmp", join(portraitDirectory, file), "--out", output]);
    if (result.status !== 0) throw new Error(result.stderr.toString());
    console.log([file, ...dominantColors(readFileSync(output))].join("\t"));
  }
} finally {
  rmSync(temporaryDirectory, { recursive: true, force: true });
}
