import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ENGLISH_ORIGIN, ORIGIN, pageCount, parseCards, parseProducts } from './card-parser.mjs';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const outputPath = join(scriptDir, '..', 'HoloWish', 'Resources', 'cards.json');
const requestedPages = Number(process.argv.find((value) => value.startsWith('--pages='))?.split('=')[1] || 0);
const concurrency = Math.min(4, Math.max(1, Number(process.env.SYNC_CONCURRENCY || 3)));
const delayMs = Math.max(100, Number(process.env.SYNC_DELAY_MS || 250));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Official English product names take priority. These curated translations cover
// Japanese releases that do not yet have a matching product on the English site.
const japaneseProductTranslations = new Map([
  ['hBP09', 'Booster Pack – Volume Vortex'],
  ['hEB01', 'Extra Booster – Summer Hologram'],
  ['hBP08', 'Booster Pack – Bouncer Bound'],
  ['hWF01', 'hololive OFFICIAL CARD GAME Twin Wafer'],
  ['hCO01', 'Official HoloCa Collection – 2025 Live Set'],
  ['hSD14', 'Live Start Deck – Shirakami Fubuki'],
  ['hSD15', 'Live Start Deck – Juufuutei Raden'],
  ['hSD16', 'Live Start Deck – Sakura Miko'],
  ['hSD17', 'Live Start Deck – Hoshimachi Suisei'],
  ['hSD18', 'Live Start Deck – Mori Calliope'],
  ['hSD19', 'Live Start Deck – Oozora Subaru'],
  ['hBP07', 'Booster Pack – Diva Fever'],
  ['hSD10', 'Start Deck – FLOW GLOW Oshi Rindo Chihaya'],
  ['hSD11', 'Start Deck – FLOW GLOW Oshi Koganei Niko'],
  ['hSD08', 'Start Deck – White Amane Kanata'],
  ['hSD09', 'Start Deck – Red Houshou Marine'],
  ['hSD2025summer', 'Event Exclusive Start Deck Set – 2025 HoloNatsu Paradise ver.'],
  ['hCS01', '1st Anniversary Celebration Set'],
  ['hPC01', 'Event Exclusive Official HoloCa Collection – PC Set']
]);

async function request(url, attempts = 3) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { 'User-Agent': 'holoWish/0.1 card indexer (personal collection app)' },
        signal: AbortSignal.timeout(30_000)
      });
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
      return await response.text();
    } catch (error) {
      if (attempt === attempts) throw error;
      await sleep(attempt * 1_000);
    }
  }
}

async function fetchCatalog(origin, language) {
  const baseUrl = `${origin}/cardlist/cardsearch/`;
  console.log(`Fetching official ${language === 'ja' ? 'Japanese' : 'English'} card list…`);
  const firstHtml = await request(`${baseUrl}?view=text`);
  const totalPages = requestedPages ? Math.min(requestedPages, pageCount(firstHtml)) : pageCount(firstHtml);
  const pages = Array.from({ length: totalPages }, (_, index) => index + 1);
  const parsedPages = new Map([[1, parseCards(firstHtml, { origin, language })]]);
  let cursor = 1;
  async function worker() {
    while (cursor < pages.length) {
      const page = pages[cursor++];
      const html = await request(`${origin}/cardlist/cardsearch_ex?view=text&page=${page}`);
      parsedPages.set(page, parseCards(html, { origin, language }));
      console.log(`${language.toUpperCase()} page ${page}/${totalPages}`);
      await sleep(delayMs);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, Math.max(0, totalPages - 1)) }, worker));
  return pages.flatMap((page) => parsedPages.get(page) || []);
}

async function main() {
  const [japaneseCards, englishCards, productHtml, englishProductHtml] = await Promise.all([
    fetchCatalog(ORIGIN, 'ja'),
    fetchCatalog(ENGLISH_ORIGIN, 'en'),
    request(`${ORIGIN}/cardlist/`),
    request(`${ENGLISH_ORIGIN}/cardlist/`)
  ]);
  const japaneseProducts = parseProducts(productHtml);
  const englishProductsByCode = new Map(
    parseProducts(englishProductHtml, { origin: ENGLISH_ORIGIN }).map((product) => [product.code, product])
  );
  const products = japaneseProducts.map((product) => ({
    ...product,
    englishName: englishProductsByCode.get(product.code)?.name || japaneseProductTranslations.get(product.code) || ''
  }));
  const productByJapaneseName = new Map(products.map((product) => [product.name, product]));
  const englishByNumber = new Map();
  for (const card of englishCards) {
    const key = card.number.toLocaleLowerCase('en-US');
    const existing = englishByNumber.get(key);
    if (!existing || (card.name && card.sets.length > existing.sets.length)) englishByNumber.set(key, card);
  }
  const localizedCards = japaneseCards.map((card) => {
    const english = englishByNumber.get(card.number.toLocaleLowerCase('en-US'));
    const englishSets = card.sets
      .map((setName) => productByJapaneseName.get(setName)?.englishName || '')
      .filter(Boolean);
    return { ...card, englishName: english?.name || '', englishSets };
  });
  const uniqueCards = [...new Map(localizedCards.map((card) => [card.id, card])).values()];
  let previousCount = 0;
  try { previousCount = JSON.parse(await readFile(outputPath, 'utf8')).cards.length; } catch {}
  const payload = {
    source: `${ORIGIN}/cardlist/cardsearch/?view=text`, sourceLanguage: 'ja', syncedAt: new Date().toISOString(),
    count: uniqueCards.length, cards: uniqueCards, products
  };
  const temporaryPath = `${outputPath}.tmp`;
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(temporaryPath, `${JSON.stringify(payload)}\n`);
  await rename(temporaryPath, outputPath);
  const change = uniqueCards.length - previousCount;
  console.log(`Matched ${uniqueCards.filter((card) => card.englishName).length} Japanese cards to official English names.`);
  console.log(`Matched ${products.length} official product images.`);
  console.log(`Saved ${uniqueCards.length} cards (${change >= 0 ? '+' : ''}${change}) to ${outputPath}`);
}

main().catch((error) => { console.error(`Sync failed: ${error.message}`); process.exitCode = 1; });
