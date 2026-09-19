# Talent artwork framing audit

Reviewed September 18, 2026 against `HoloWish/Resources/talent-artwork.json`.

## Coverage and result

- All 83 talents and all 526 catalog artwork entries downloaded and decoded successfully.
- All 526 outfits visually reviewed in 18 labeled preview sheets, in catalog order.
- Each outfit's geometry checked at Home card widths of 288, 343, 370, 398, and 736 points (height 278 points): 2,630 passing checks.
- The Home crop retains all nontransparent pixels before layout, places the topmost visible pixel 16 points below the card's top, and keeps both sides at least 20 points inside the card.
- The lower body is intentionally allowed below the card, preserving the upper-body composition. Wide poses and large accessories scale down to fit horizontally.
- Hakui Koyori's fifth source image has visible pixels at the source's top edge. It still receives the same 16-point display margin; source artwork is not reconstructed or retouched.
- Suisei's first three looks and Aki's saved look also checked in the running iPhone simulator. Preview sheets approximate image placement, not the full SwiftUI styling; this is not a claim that every outfit was opened individually in the simulator.

## Implementation

`TalentArtworkStore` computes visible bounds once when decoding an image and caches the original and trimmed presentations together. Only Home uses the trimmed presentation; the Oshi Hub showcase keeps its original aspect-fit canvas. This replaces aspect-ratio-dependent negative offsets and extra scaling that could push heads outside the card.

## Repeat the audit

Requires Python 3 and Pillow:

```sh
python3 scripts/audit-talent-framing.py /tmp/holowish-framing
```

The script caches source files in the output directory and creates `report.json` with one entry per outfit plus numbered preview sheets. It exits unsuccessfully for download, decode, or geometry failures. Keep its layout constants in sync with `TalentArtworkView` when changing the Home composition. Source images and generated sheets are deliberately not bundled with the app or committed.
