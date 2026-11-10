#!/usr/bin/env python3
"""Make the App Store product page header (backlog #29) from the store screenshots.

    tools/store_header.py                      # from screenshots/ios/iphone-6.9/ (the Mac's set)
    tools/store_header.py --shots <dir>        # any folder with 02-analytics-overview.png and
                                               # 09-analytics-dark.png
    tools/store_header.py --guides             # also draw the safe area, to check the layout

Writes screenshots/ios/header/header-3840x1646.png (gitignored with the rest of screenshots/ios),
for App Store Connect › the version page › Product Page Information › Header and Search Results.

Apple's specs (creative assets specifications, read 2026-11-10): the header is 21:9, 3840 × 1646,
.png/.jpg, no alpha. Devices crop it differently, so the logo, the name and the line of text sit
in the centred safe area (about 1646 × 661, measured from Apple's templates by a third party;
check with the product page preview in App Store Connect). The phones either side may be cropped.
No search-results asset: without one, the App Store shows the screenshots there instead, which
is what Apple's guidance asks that asset to look like anyway.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "app" / "assets"
OUT = ROOT / "screenshots" / "ios" / "header"

W, H = 3840, 1646
SAFE_W, SAFE_H = 1646, 661
BG = (29, 25, 41)  # the launcher icon's background (app/assets/icon.png)
GLOW = (124, 58, 237)  # the purple at the bottom of the icon's shield
TEXT = (245, 240, 255)
SUBTLE = (196, 181, 253)

NAME = "Megrim"
LINE = "A private migraine diary"
DETAIL = "Offline  ·  No account  ·  Open source"


def font(bold, size):
    return ImageFont.truetype(str(ASSETS / "fonts" / ("NotoSans-Bold.ttf" if bold else "NotoSans-Regular.ttf")), size)


def background():
    img = Image.new("RGB", (W, H), BG)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W // 2 - 1300, H // 2 - 700, W // 2 + 1300, H // 2 + 700), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    return Image.composite(Image.new("RGB", (W, H), GLOW), img, glow)


def phone(shot, height):
    """A screenshot scaled to `height`, with rounded corners and a thin frame, as RGBA."""
    s = Image.open(shot).convert("RGB")
    s = s.resize((round(s.width * height / s.height), height), Image.LANCZOS)
    radius = s.width // 9
    frame = 14
    out = Image.new("RGBA", (s.width + 2 * frame, s.height + 2 * frame), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle((0, 0, out.width - 1, out.height - 1), radius + frame, fill=(12, 10, 18, 255))
    mask = Image.new("L", s.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s.width - 1, s.height - 1), radius, fill=255)
    out.paste(s, (frame, frame), mask)
    return out


def shadow(img, offset=(0, 40), blur=60, opacity=150):
    a = img.split()[-1].point(lambda v: opacity if v else 0)
    sh = Image.new("RGBA", (img.width + 4 * blur, img.height + 4 * blur), (0, 0, 0, 0))
    sh.paste(Image.new("RGBA", img.size, (0, 0, 0, 255)), (2 * blur + offset[0], 2 * blur + offset[1]), a)
    return sh.filter(ImageFilter.GaussianBlur(blur))


def place(canvas, img, cx, cy):
    sh = shadow(img)
    canvas.paste(sh, (cx - sh.width // 2, cy - sh.height // 2), sh)
    canvas.paste(img, (cx - img.width // 2, cy - img.height // 2), img)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shots", type=Path, default=ROOT / "screenshots" / "ios" / "iphone-6.9")
    ap.add_argument("--out", type=Path, default=OUT)
    ap.add_argument("--guides", action="store_true", help="draw the safe area (not for upload)")
    args = ap.parse_args()

    light = args.shots / "02-analytics-overview.png"
    dark = args.shots / "09-analytics-dark.png"
    for f in (light, dark):
        if not f.exists():
            sys.exit(f"store_header: {f} is missing (take the iOS screenshots first: tools/screenshots.sh iphone-69)")

    canvas = background().convert("RGBA")

    # Phones either side of the safe area, partly cropped by the bottom edge on purpose.
    ph = 1500
    left, right = phone(light, ph), phone(dark, ph)
    place(canvas, left, W // 2 - SAFE_W // 2 - 430, H // 2 + 260)
    place(canvas, right, W // 2 + SAFE_W // 2 + 430, H // 2 + 260)

    # Logo, name and line, centred in the safe area.
    d = ImageDraw.Draw(canvas)
    icon = Image.open(ASSETS / "icon.png").convert("RGBA").resize((360, 360), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 359, 359), 80, fill=255)
    f_name, f_line, f_detail = font(True, 190), font(False, 92), font(False, 62)
    name_w = d.textlength(NAME, font=f_name)
    gap = 56
    row_w = icon.width + gap + name_w
    x0 = int((W - row_w) // 2)
    block_h = icon.height + 230 + 42  # logo row down to the bottom of the last line
    top = (H - SAFE_H) // 2 + (SAFE_H - block_h) // 2  # centred in the safe area
    canvas.paste(icon, (x0, top), mask)
    d.text((x0 + icon.width + gap, top + icon.height // 2), NAME, font=f_name, fill=TEXT, anchor="lm")
    d.text((W // 2, top + icon.height + 120), LINE, font=f_line, fill=TEXT, anchor="mm")
    d.text((W // 2, top + icon.height + 230), DETAIL, font=f_detail, fill=SUBTLE, anchor="mm")

    if args.guides:
        sx, sy = (W - SAFE_W) // 2, (H - SAFE_H) // 2
        d.rectangle((sx, sy, sx + SAFE_W, sy + SAFE_H), outline=(255, 80, 80), width=6)

    args.out.mkdir(parents=True, exist_ok=True)
    name = "header-3840x1646-guides.png" if args.guides else "header-3840x1646.png"
    out = args.out / name
    canvas.convert("RGB").save(out, optimize=True)  # RGB: Apple rejects alpha
    print(f"wrote {out.relative_to(ROOT) if out.is_relative_to(ROOT) else out}")


if __name__ == "__main__":
    main()
