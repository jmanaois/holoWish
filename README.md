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
- Searchable portrait themes for all 83 entries in the current official hololive talent directory, grouped by branch and including affiliates, alumni, and staff. Each portrait-derived palette adapts to light and dark appearance; Bijou remains the default.
- Talent spotlights, full-body artwork showcases, and per-talent card progress bring official character art throughout the app.
- Browse compact set tiles using official Japanese product/booster artwork, with Japanese or English names and live collection completion progress
- Search within any set, sort in either direction by card number, name, rarity, type, or color, and filter using only values available in that set
- Search Japanese and official English names, card numbers, tags, and sets
- Filter by rarity, card type, color, bloom level, set, or parallel status
- Wishlist and collection lists, plus custom lists
- Per-card collection quantities
- Optional JPY purchase price per copy when adding to a collection or custom list, editable from card details
- Collection worth summary with quantity-adjusted total paid, missing-price counts, and cached Yuyutei shop estimates
- Native SwiftData persistence
- Adaptive iPhone and iPad card grid
- Resumable on-device artwork library for offline card images
- Card details with links to the official Japanese source
- On-demand Yuyutei sale-price lookup by card number and rarity, with stock status, direct listing links, and a 12-hour on-device cache

## Purchase prices and collection worth

Tap a collection or custom list in a card's details to enter quantity and an optional whole-yen purchase price per copy. For copies purchased at different prices, enter the average per copy, rounded to whole yen. Tap the purchase price below the list name to edit it later or clear it. Changing quantity applies that same per-copy price to all copies. Cancelling the editor leaves the list unchanged.

Open the collection from Home or My Lists to see **Total paid** and a separate Yuyutei shop estimate. Unknown purchase prices are excluded and counted; a price of zero means a free card. Shop estimates use the lowest cached listing matching the card number and rarity, including out-of-stock listings, multiplied by quantity. Missing quotes are explicitly shown as incomplete coverage. These are shop-price estimates and may not distinguish artwork variants with the same number and rarity.

**Refresh Yuyutei value** fetches the collection's prices. Previously cached quotes remain available offline, with the oldest lookup date displayed. Purchase prices and quantities persist in local SwiftData storage; cloud sync is disabled. Existing items start with an unknown purchase price.

On macOS 14+ with Xcode installed, run the native totals/persistence regression check:

```bash
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" HoloWish/Models/CardList.swift test/collection-persistence.swift -o /tmp/holowish-collection-check
/tmp/holowish-collection-check
```

Before releasing, build in Xcode and verify on a simulator/device: upgrade an existing populated install; add, cancel, edit, and clear a price; enter zero and invalid input; change quantities and remove cards; relaunch in airplane mode and check saved totals. Refresh shop values online, then offline, checking partial coverage and retained cached quotes. Also check custom lists, unchanged wishlist behavior, and larger Dynamic Type sizes. Native build, migration, and device UI checks require macOS/Xcode and cannot run from the Windows development workspace.

## Theme palettes

Choose a theme from Settings. The picker uses square portraits from the [official talent directory](https://hololive.hololivepro.com/en/talents/) and is searchable by English or Japanese name. Themes are grouped into hololive, Indonesia, English, DEV_IS, ASOBI★MAWARI-TAI!, holoAN, and Alumni & Staff.

Each palette starts with two prominent colors extracted from its portrait. Light and dark surfaces are generated from those colors, and primary text, secondary text, and both accents maintain at least 4.5:1 calculated contrast against their background and surface colors. Dashboard icons use the background color against accent fills so they remain legible in both appearances. These are UI adaptations rather than official brand color specifications.

On a Mac, verify each theme in the iOS simulator in both appearances, including Home, Search, My Lists, card details, and sheets. Toggle appearance while the theme picker is open, then relaunch to confirm the selected member is retained. Check larger Dynamic Type sizes and VoiceOver selection announcements. Palette contrast checks do not replace native rendering checks.

## Next production step

On-device lists make the MVP usable without accounts. The natural next step is CloudKit sync, or authentication backed by hosted Postgres if Android/web clients are planned. For production, run the catalog sync server-side on a daily schedule and ship reviewed catalog updates through the app or an API.

Card data and images belong to their respective rights holders. Before a public/commercial launch, review the official site's terms and applicable fan-content guidelines.
