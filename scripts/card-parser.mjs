export const ORIGIN = 'https://hololive-official-cardgame.com';
export const ENGLISH_ORIGIN = 'https://en.hololive-official-cardgame.com';

export function decodeEntities(value = '') {
  const entities = { amp: '&', apos: "'", gt: '>', lt: '<', nbsp: ' ', quot: '"' };
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, decimal) => String.fromCodePoint(Number(decimal)))
    .replace(/&([a-z]+);/gi, (match, name) => entities[name.toLowerCase()] ?? match);
}

export function textContent(value = '') {
  return decodeEntities(value)
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<img\b[^>]*alt=["']([^"']*)["'][^>]*>/gi, ' $1 ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[\t\r\n ]+/g, ' ')
    .trim();
}

function pick(html, pattern) { return pattern.exec(html)?.[1]?.trim() ?? ''; }

function detailsFrom(html) {
  const details = {};
  for (const match of html.matchAll(/<dt[^>]*>([\s\S]*?)<\/dt>\s*<dd[^>]*>([\s\S]*?)<\/dd>/gi)) {
    details[textContent(match[1])] = textContent(match[2]);
  }
  return details;
}

function detailHtml(html, label) {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`<dt[^>]*>\\s*${escaped}\\s*<\\/dt>\\s*<dd[^>]*>([\\s\\S]*?)<\\/dd>`, 'i').exec(html)?.[1] || '';
}

export function parseCards(html, { origin = ORIGIN, language = 'ja' } = {}) {
  const labels = language === 'en' ? {
    type: 'Card Type', tags: 'Tags', rarity: 'Rarity', sets: 'Card Set',
    color: 'Color', bloom: 'Bloom Level', hp: 'HP', life: 'LIFE'
  } : {
    type: 'カードタイプ', tags: 'タグ', rarity: 'レアリティ', sets: '収録商品',
    color: '色', bloom: 'Bloomレベル', hp: 'HP', life: 'LIFE'
  };
  const cards = [];
  const itemPattern = /<li(?:\s[^>]*)?>\s*<a\s+href=["']([^"']*\/cardlist\/\?[^"']*\bid=(\d+)[^"']*)["'][^>]*>([\s\S]*?)<\/a>\s*<\/li>/gi;
  for (const match of html.matchAll(itemPattern)) {
    const body = match[3];
    const details = detailsFrom(body);
    const imagePath = pick(body, /<div class=["']img[^"']*["'][^>]*>[\s\S]*?<img[^>]+src=["']([^"']+)["']/i);
    const rarity = details[labels.rarity] || '';
    const sets = detailHtml(body, labels.sets).split(/<br\s*\/?>/i).map(textContent).filter(Boolean);
    const colors = [...detailHtml(body, labels.color).matchAll(/alt=["']([^"']+)["']/gi)]
      .map((color) => decodeEntities(color[1])).map((color) => color === '◇' ? '無' : color);
    const card = {
      id: Number(match[2]),
      number: textContent(pick(body, /<p class=["']number["']>([\s\S]*?)<\/p>/i)),
      name: textContent(pick(body, /<p class=["']name["']>([\s\S]*?)<\/p>/i)),
      image: imagePath ? new URL(imagePath, origin).href : '',
      sourceUrl: `${origin}/cardlist/?id=${match[2]}`,
      type: details[labels.type] || '', rarity,
      color: colors.join('・') || details[labels.color] || '', colors,
      set: sets[0] || details[labels.sets] || '', sets,
      tags: (details[labels.tags] || '').match(/#[^#\s]+/g) || [],
      bloomLevel: details[labels.bloom] || '',
      hp: details[labels.hp] ? Number(details[labels.hp]) : null,
      life: details[labels.life] ? Number(details[labels.life]) : null,
      parallel: ['SR', 'S', 'UR', 'OUR', 'SEC', 'SY', 'HR'].includes(rarity)
    };
    if (card.number && card.name) cards.push(card);
  }
  return cards;
}

export function pageCount(html) { return Number(pick(html, /var\s+max_page\s*=\s*(\d+)/)) || 1; }

export function parseProducts(html, { origin = ORIGIN } = {}) {
  const products = [];
  const itemPattern = /<li class=["'][^"']*\bproduct-item\b[^"']*["'][^>]*>([\s\S]*?)<\/li>/gi;
  for (const match of html.matchAll(itemPattern)) {
    const body = match[1];
    const code = pick(body, /href=["'][^"']*[?&]expansion=([^&"']+)/i);
    const imagePath = pick(body, /<div class=["']thumb["'][^>]*>\s*<img[^>]+src=["']([^"']+)["']/i);
    const name = textContent(pick(body, /<div class=["']name[^"']*["'][^>]*>([\s\S]*?)<\/div>/i)) ||
      textContent(pick(body, /<img[^>]+alt=["']([^"']+)["']/i));
    const category = textContent(pick(body, /<div class=["']cat[^"']*["'][^>]*>([\s\S]*?)<\/div>/i));
    if (code && name && imagePath) {
      products.push({ code: decodeEntities(code), name, image: new URL(imagePath, origin).href, category });
    }
  }
  return [...new Map(products.map((product) => [product.name, product])).values()];
}
