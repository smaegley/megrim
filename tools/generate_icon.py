#!/usr/bin/env python3
"""Render Megrim launcher icons with PIL: a head glyph with radiating 'throb' waves
on a purple gradient. Produces a full icon and a transparent adaptive foreground."""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024
PURPLE_TOP = (123, 31, 162)     # #7B1FA2
PURPLE_BOT = (74, 20, 140)      # #4A148C
WHITE = (255, 255, 255, 255)


def gradient_bg():
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        t = y / (S - 1)
        r = int(PURPLE_TOP[0] * (1 - t) + PURPLE_BOT[0] * t)
        g = int(PURPLE_TOP[1] * (1 - t) + PURPLE_BOT[1] * t)
        b = int(PURPLE_TOP[2] * (1 - t) + PURPLE_BOT[2] * t)
        for x in range(S):
            px[x, y] = (r, g, b)
    return img


ACCENT = (255, 138, 76)  # warm coral — the 'pain point'


def draw_glyph(draw, alpha=255):
    """A clean head (vertical oval) with a warm pain-point at the temple and 3 throb
    arcs radiating from it."""
    w = (255, 255, 255, alpha)
    # Head as a vertical egg-oval, shifted slightly left so the right-side waves
    # balance the composition around the canvas centre.
    cx, cy = S * 0.42, S * 0.48
    rw, rh = S * 0.19, S * 0.235
    draw.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=w)

    # Pain point on the upper-right temple (sits on the head edge).
    px, py = cx + rw * 0.62, cy - rh * 0.52
    pr = S * 0.055
    draw.ellipse([px - pr, py - pr, px + pr, py + pr],
                 fill=(ACCENT[0], ACCENT[1], ACCENT[2], alpha))

    # Throb: 3 concentric arcs radiating outward from the pain point.
    for i, rr in enumerate([S * 0.115, S * 0.175, S * 0.235]):
        bbox = [px - rr, py - rr, px + rr, py + rr]
        aa = int(alpha * (0.9 - i * 0.16))
        draw.arc(bbox, start=-70, end=25, fill=(255, 255, 255, aa),
                 width=int(S * 0.026))


def main():
    # Full icon (gradient + glyph).
    bg = gradient_bg().convert("RGBA")
    overlay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_glyph(ImageDraw.Draw(overlay))
    full = Image.alpha_composite(bg, overlay).convert("RGB")
    full.save("/home/aiuser/projects/megrim/app/assets/icon.png")

    # Adaptive foreground: glyph only on transparent, inset to the safe zone (~66%).
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inner = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_glyph(ImageDraw.Draw(inner))
    scale = 0.72
    small = inner.resize((int(S * scale), int(S * scale)), Image.LANCZOS)
    fg.paste(small, (int(S * (1 - scale) / 2), int(S * (1 - scale) / 2)), small)
    fg.save("/home/aiuser/projects/megrim/app/assets/icon_foreground.png")
    print("wrote icon.png and icon_foreground.png")


if __name__ == "__main__":
    main()
