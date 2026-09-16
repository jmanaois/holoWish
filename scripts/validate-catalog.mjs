import { readFile } from 'node:fs/promises';

const path = new URL('../HoloWish/Resources/cards.json', import.meta.url);
const payload = JSON.parse(await readFile(path, 'utf8'));

if (payload.sourceLanguage !== 'ja') throw new Error('Expected a Japanese catalog');
if (payload.count !== payload.cards.length) throw new Error('Catalog count does not match card data');
if (payload.cards.some((card) => !card.id || !card.name || !card.number || !card.sourceUrl)) {
  throw new Error('A card is missing a required field');
}
if (new Set(payload.cards.map((card) => card.id)).size !== payload.cards.length) {
  throw new Error('Catalog contains duplicate official IDs');
}
const products = payload.products || [];
if (new Set(products.map((product) => product.code)).size !== products.length) {
  throw new Error('Catalog contains duplicate product codes');
}
if (products.some((product) => !product.englishName)) {
  throw new Error('Every product must have an English display name');
}
const officialEnglishSets = new Set(products.map((product) => product.englishName).filter(Boolean));
const invalidEnglishSets = new Set(
  payload.cards.flatMap((card) => card.englishSets || []).filter((name) => !officialEnglishSets.has(name))
);
if (invalidEnglishSets.size) {
  throw new Error(`Cards contain unverified English set aliases: ${[...invalidEnglishSets].join(', ')}`);
}

console.log(`Validated ${payload.cards.length} Japanese cards and ${products.length} product mappings from ${new URL(payload.source).host}`);
