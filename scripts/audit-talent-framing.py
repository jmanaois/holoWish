"""Audit every catalog outfit and render labeled Home-artwork preview sheets.

Requires Pillow. Source images are cached outside the repository; originals are
never modified. Run with: python3 scripts/audit-talent-framing.py /tmp/holowish-framing
"""
import concurrent.futures
import hashlib
import json
import math
from pathlib import Path
import sys
import urllib.request

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1])
cache = output / "sources"
cache.mkdir(parents=True, exist_ok=True)
records = json.loads((root / "HoloWish/Resources/talent-artwork.json").read_text())["records"]
entries = [(r["name"], i + 1, url) for r in records for i, url in enumerate(r["artworkURLs"])]


def inspect(entry):
    name, look, url = entry
    path = cache / (hashlib.sha256(url.encode()).hexdigest() + Path(url).suffix)
    try:
        if not path.exists():
            request = urllib.request.Request(url, headers={"User-Agent": "holoWish/1.0 personal collection app"})
            with urllib.request.urlopen(request, timeout=60) as response:
                path.write_bytes(response.read())
        with Image.open(path) as source:
            image = source.convert("RGBA")
            bounds = image.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError("Empty artwork")
            x0, y0, x1, y1 = bounds
            crop_width, crop_height = x1 - x0, y1 - y0
            checks = []
            for width in (288, 343, 370, 398, 736):
                scale = min(width * 0.78 / crop_width, 278 * 1.68 / crop_height)
                rendered_width = crop_width * scale
                center = min(width * 0.67, width - 20 - rendered_width / 2)
                left = center - rendered_width / 2
                assert left >= 20 - 0.001 and left + rendered_width <= width - 20 + 0.001
                checks.append({"width": width, "left": left, "top": 16, "height": crop_height * scale})
            return dict(name=name, look=look, url=url, path=str(path), size=image.size,
                        bounds=bounds, checks=checks, sourceTouchesTop=y0 == 0)
    except Exception as error:
        return dict(name=name, look=look, url=url, error=str(error))


with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(inspect, entries))

font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
for page in range(math.ceil(len(results) / 30)):
    sheet = Image.new("RGB", (6 * 246, 5 * 220), "#12151c")
    draw = ImageDraw.Draw(sheet)
    for slot, result in enumerate(results[page * 30:(page + 1) * 30]):
        x, y = (slot % 6) * 246, (slot // 6) * 220
        draw.text((x + 8, y + 5), f'{page * 30 + slot + 1}. {result["name"]}', font=font, fill="white")
        draw.text((x + 8, y + 23), f'Look {result["look"]}', font=font, fill="#aabaca")
        if "error" in result:
            draw.text((x + 8, y + 60), "DOWNLOAD/DECODE FAILED", font=font, fill="red")
            continue
        with Image.open(result["path"]) as source:
            crop = source.convert("RGBA").crop(result["bounds"])
        width, height = 370, 278
        scale = min(width * 0.78 / crop.width, height * 1.68 / crop.height)
        rw, rh = round(crop.width * scale), round(crop.height * scale)
        center = min(width * 0.67, width - 20 - crop.width * scale / 2)
        card = Image.new("RGBA", (width, height), "#485568")
        card.alpha_composite(crop.resize((rw, rh), Image.Resampling.LANCZOS), (round(center - rw / 2), 16))
        overlay = ImageDraw.Draw(card)
        overlay.rounded_rectangle((0, 0, width - 1, height - 1), radius=28, outline="#9db9d2", width=2)
        overlay.text((18, 22), "OSHI HUB", font=font, fill="white")
        overlay.text((18, 235), result["name"], font=font, fill="white")
        sheet.paste(card.convert("RGB").resize((230, 173), Image.Resampling.LANCZOS), (x + 8, y + 42))
    sheet.save(output / f"sheet-{page + 1:02d}.jpg", quality=90)

(output / "report.json").write_text(json.dumps(results, indent=2) + "\n")
failed = [r for r in results if "error" in r]
print(json.dumps({"talents": len(records), "outfits": len(results), "failures": failed,
                  "sourceTouchesTop": [f'{r["name"]} look {r["look"]}' for r in results if r.get("sourceTouchesTop")],
                  "sheets": math.ceil(len(results) / 30)}, indent=2))
sys.exit(bool(failed))
