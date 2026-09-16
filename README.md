# holoWish for iOS

A native SwiftUI collection tracker for the Japanese edition of the hololive OFFICIAL CARD GAME.

## Run it

1. Open `HoloWish.xcodeproj` in Xcode 16 or newer.
2. Select an iOS 17+ simulator or device.
3. Choose your development team under **Signing & Capabilities** when running on a physical device.
4. Press Run.

The app uses SwiftUI and SwiftData with no third-party runtime dependencies. Card metadata works offline, and official Japanese card artwork is downloaded into Application Support for offline viewing. Downloads run at low concurrency, can be paused from Home, and resume by filling in missing images whenever the app becomes active. Artwork file reads and thumbnail decoding stay off the main UI thread. Wishlist, collection quantities, and custom lists persist on-device.

The bundled catalog is the first-run fallback. The app stores newer validated catalogs in Application Support and checks the repository update feed at launch or foregrounding, at most once every 24 hours. A refresh button in the Cards screen also supports manual checks.

## Refresh the card catalog

```bash
npm run sync:cards
```

The sync requires Node.js 20+. It reads the public Japanese card list, waits between requests, retries transient failures, and atomically updates `HoloWish/Resources/cards.json`. For a short importer test, run `npm run sync:cards -- --pages=3`.

Run `npm run validate:catalog` to check the bundled data for required fields, counts, and duplicate official IDs.

To publish new cards: run `npm run sync:cards`, validate with `npm run validate:catalog`, commit `HoloWish/Resources/cards.json`, and push to the `main` branch. Installed apps will pick up the newer `syncedAt` catalog without an App Store release.

The catalog sync also cross-references the official English card list by card number. Japanese records remain authoritative, while available official English card names and set names are included as search aliases.

## Current MVP

- Dashboard-first navigation with large shortcuts to Wishlist, Collection, Search, and custom lists
- Six persistent color themes inspired by SWG Hazakura Light, GMK Ishtar, SWG Lavender, GMK Tako, GMK Shoko, and GMK Abyssal, each with accessible light and dark palettes
- Browse compact set tiles using official Japanese product/booster artwork, with Japanese or English names and live collection completion progress
- Search within any set, sort in either direction by card number, name, rarity, type, or color, and filter using only values available in that set
- Search Japanese and official English names, card numbers, tags, and sets
- Filter by rarity, card type, color, bloom level, set, or parallel status
- Wishlist and collection lists, plus custom lists
- Per-card collection quantities
- Native SwiftData persistence
- Adaptive iPhone and iPad card grid
- Resumable on-device artwork library for offline card images
- Card details with links to the official Japanese source
- On-demand Yuyutei sale-price lookup by card number and rarity, with stock status, direct listing links, and a 12-hour on-device cache

## Next production step

On-device lists make the MVP usable without accounts. The natural next step is CloudKit sync, or authentication backed by hosted Postgres if Android/web clients are planned. For production, run the catalog sync server-side on a daily schedule and ship reviewed catalog updates through the app or an API.

Card data and images belong to their respective rights holders. Before a public/commercial launch, review the official site's terms and applicable fan-content guidelines.
