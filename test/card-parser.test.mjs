import test from 'node:test';
import assert from 'node:assert/strict';
import { pageCount, parseCards, parseProducts, textContent } from '../scripts/card-parser.mjs';

const fixture = `<script>var max_page = 12;</script>
<li class="ex-item"><a href="/cardlist/?id=42&amp;view=text"><div class="img w100"><img src="/wp-content/images/cardlist/hBP01/card.png" alt="星街すいせい"></div>
<p class="number">hBP01-001</p><p class="name">星街すいせい</p><dl><dt>カードタイプ</dt><dd>ホロメン</dd><dt>タグ</dt><dd>#JP #0期生</dd>
<dt>レアリティ</dt><dd>SR</dd><dt>収録商品</dt><dd>ブースターパック「ブルーミングレディアンス」<br>PRカード</dd></dl>
<dl><dt>色</dt><dd><img src="type_blue.png" alt="青"><img src="type_red.png" alt="赤"></dd><dt>HP</dt><dd>120</dd><dt>Bloomレベル</dt><dd>1st</dd></dl></a></li>`;

test('parses official card-list fields', () => {
  const [card] = parseCards(fixture);
  assert.equal(card.id, 42); assert.equal(card.name, '星街すいせい');
  assert.equal(card.number, 'hBP01-001'); assert.equal(card.color, '青・赤');
  assert.equal(card.hp, 120); assert.equal(card.parallel, true);
  assert.deepEqual(card.tags, ['#JP', '#0期生']);
  assert.deepEqual(card.sets, ['ブースターパック「ブルーミングレディアンス」', 'PRカード']);
});

test('extracts page count and accessible image text', () => {
  assert.equal(pageCount(fixture), 12);
  assert.equal(textContent('青 <img src="x" alt="◇"> &amp; 白'), '青 ◇ & 白');
});

test('parses official English aliases', () => {
  const englishFixture = `<li><a href="/cardlist/?id=99"><div class="img"><img src="/card.png"></div>
  <p class="number">hBP01-001</p><p class="name">Hoshimachi Suisei</p><dl>
  <dt>Card Type</dt><dd>holomem</dd><dt>Rarity</dt><dd>R</dd>
  <dt>Card Set</dt><dd>Booster Pack – Blooming Radiance</dd><dt>Color</dt><dd><img alt="Blue"></dd>
  <dt>Bloom Level</dt><dd>1st</dd><dt>HP</dt><dd>120</dd></dl></a></li>`;
  const [card] = parseCards(englishFixture, { origin: 'https://en.example.com', language: 'en' });
  assert.equal(card.name, 'Hoshimachi Suisei');
  assert.deepEqual(card.sets, ['Booster Pack – Blooming Radiance']);
  assert.equal(card.type, 'holomem');
});

test('parses official product artwork', () => {
  const productFixture = `<li class="item product-item product-type-deck product-type-boosters">
  <a href="/cardlist/cardsearch/?expansion=hBP09"><div class="thumb"><img src="/wp-content/images/thumb/hBP09.png" alt="Volume Vortex"></div>
  <div class="cat boosters bold">BOOSTERS</div><div class="name Sans">ブースターパック「ボリュームヴォルテックス」</div></a></li>`;
  const [product] = parseProducts(productFixture);
  assert.equal(product.code, 'hBP09');
  assert.equal(product.category, 'BOOSTERS');
  assert.equal(product.image, 'https://hololive-official-cardgame.com/wp-content/images/thumb/hBP09.png');
});
