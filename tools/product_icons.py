"""Draw an icon for every Robux product: assets/store/product_icons/<kind>_<key>.png.

    python tools/product_icons.py            # all 55 (41 heroes, 5 passes, 9 consumables)
    python tools/product_icons.py --only hero_thor product_goldBoost

Heroes are the real game figures (Figure.Hero, ray cast by tools/render_figure.py
at twice the size and scaled down) on a backdrop in their rarity colour, with a
sticker outline; passes and consumables are drawn shapes in the style of the
badges (assets/store/badges). A pack that lets the player choose a hero shows a
silhouette with a question mark, never a hero it does not promise. 512x512 PNG,
no words (numbers only), no third-party marks. Upload each one on its product's
Creator Hub page (Monetization > Developer Products / Passes > Configure).
"""
from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import render_figure  # noqa: E402

OUT = ROOT / "assets" / "store" / "product_icons"
S = 512
SUPER = 2
INK = (24, 28, 39, 255)
GOLD = (244, 190, 58, 255)
GOLD_LIGHT = (255, 226, 120, 255)
GOLD_DARK = (176, 120, 30, 255)
CREAM = (240, 232, 212, 255)
RARITY = {"common": (176, 188, 204), "rare": (70, 156, 250), "epic": (168, 96, 250), "legendary": (250, 176, 48), "mythic": (250, 76, 104)}
PORTRAIT = (0.70, 1.3)   # centre height and camera distance, in figure heights
FULL = (0.5, 2.2)
FONTS = ["C:/Windows/Fonts/ariblk.ttf", "C:/Windows/Fonts/arialbd.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]


def font(size):
    for path in FONTS:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def label(im, xy, text, size, fill=GOLD_LIGHT):
    ImageDraw.Draw(im).text(xy, text, font=font(size), fill=fill, anchor="mm", stroke_width=max(5, size // 10), stroke_fill=INK)


def catalog_facts():
    """Hero rarity, every hero sold for Robux, and what the starter pack gives."""
    catalog = (ROOT / "src" / "shared" / "Catalog.luau").read_text(encoding="utf-8")
    config = (ROOT / "src" / "shared" / "Config.luau").read_text(encoding="utf-8").replace("\r\n", "\n")
    rarity = {m.group(1): m.group(2) for m in re.finditer(r'id = "([a-z0-9]+)", rarity = "([a-z]+)"', catalog)}
    # The later heroes are rows: {"id","Nome","Name","rarity",...}.
    rarity.update({m.group(1): m.group(2) for m in re.finditer(r'\{"([a-z0-9]+)","[^"]*","[^"]*","([a-z]+)"', catalog)})
    start = config.index("Heroes = {")
    block = config[start:config.index("\n\t\t},", start)]
    heroes = re.findall(r"\b([a-z0-9]+) = \{ id = \d+ \}", block)
    starter = re.search(r'starterPack = \{[^\n]*heroId = "([a-z0-9]+)"', catalog)
    return rarity, heroes, starter.group(1) if starter else None


def rounded_mask(inset=0, radius=84):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((inset, inset, S - 1 - inset, S - 1 - inset), radius=radius, fill=255)
    return mask


def backdrop(color, accent=None):
    """A rounded square in a colour, a soft light behind the subject, faint rays and a dark rim."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark = tuple(int(c * 0.42) for c in color) + (255,)
    d.rounded_rectangle((0, 0, S - 1, S - 1), radius=84, fill=dark)
    d.rounded_rectangle((14, 14, S - 15, S - 15), radius=72, fill=tuple(color) + (255,))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    light = tuple(min(255, int(c * 0.55 + 255 * 0.45)) for c in (accent or color)) + (200,)
    ImageDraw.Draw(glow).ellipse((70, 50, S - 70, S - 90), fill=light)
    im = Image.alpha_composite(im, glow.filter(ImageFilter.GaussianBlur(44)))
    rays = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for i in range(12):
        a = i * math.pi / 6
        rd.polygon([(S / 2, S / 2), (S / 2 + 400 * math.cos(a - 0.08), S / 2 + 400 * math.sin(a - 0.08)), (S / 2 + 400 * math.cos(a + 0.08), S / 2 + 400 * math.sin(a + 0.08))], fill=(255, 255, 255, 24))
    im.paste(Image.alpha_composite(im, rays), (0, 0), rounded_mask(14, 72))
    # A darker floor band so a figure or a pile stands on something.
    floor = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(floor).ellipse((40, S - 150, S - 40, S + 40), fill=(0, 0, 0, 60))
    im.paste(Image.alpha_composite(im, floor.filter(ImageFilter.GaussianBlur(20))), (0, 0), rounded_mask(14, 72))
    return im


def sticker(figure, ink=INK, width=7, shadow=True):
    """The figure with a thick dark outline and a soft drop shadow, like a sticker."""
    alpha = figure.split()[3]
    grown = alpha.filter(ImageFilter.MaxFilter(width * 2 + 1)).filter(ImageFilter.GaussianBlur(1))
    out = Image.new("RGBA", figure.size, (0, 0, 0, 0))
    if shadow:
        drop = Image.new("RGBA", figure.size, (0, 0, 0, 0))
        drop.paste((0, 0, 0, 120), (10, 12), grown)
        out = Image.alpha_composite(out, drop.filter(ImageFilter.GaussianBlur(8)))
    edge = Image.new("RGBA", figure.size, (0, 0, 0, 0))
    edge.paste(ink, (0, 0), grown)
    out = Image.alpha_composite(out, edge)
    return Image.alpha_composite(out, figure)


def figures(ids, framing):
    """The game's own figures, RGBA S x S each, keyed by hero id."""
    out = {}
    mid, dist = framing
    for start in range(0, len(ids), 8):
        pieces, heroes = render_figure.parse(render_figure.dump(ids[start:start + 8]))
        for hero, x in heroes:
            own = [p for p in pieces if p.hero == hero]
            top = max(p.c[1] + p.size.max() / 2 for p in own)
            center = np.array([x, top * mid, 0])
            eye = center + np.array([top * dist * 0.2, top * 0.08, -top * dist])
            big = render_figure.render(own, center, eye, (S * SUPER, S * SUPER), fov=34, transparent=True)
            out[hero] = big.resize((S, S), Image.LANCZOS)
    return out


def finish(im, out, name):
    im.putalpha(Image.fromarray(np.minimum(np.array(im.split()[3]), np.array(rounded_mask()))))
    im.save(out / f"{name}.png")


def hero_icons(ids, rarity, out):
    for hero, figure in figures(ids, PORTRAIT).items():
        im = backdrop(RARITY.get(rarity.get(hero, "common"), (120, 130, 150)))
        im = Image.alpha_composite(im, sticker(figure))
        finish(im, out, f"hero_{hero}")


def coin(d, cx, cy, r):
    d.ellipse((cx - r, cy - r * 0.42 + r * 0.2, cx + r, cy + r * 0.42 + r * 0.2), fill=GOLD_DARK, outline=INK, width=6)
    d.ellipse((cx - r, cy - r * 0.42, cx + r, cy + r * 0.42), fill=GOLD, outline=INK, width=6)
    d.ellipse((cx - r * 0.62, cy - r * 0.25, cx + r * 0.62, cy + r * 0.25), outline=GOLD_DARK, width=6)
    d.arc((cx - r * 0.8, cy - r * 0.34, cx + r * 0.2, cy + r * 0.3), 200, 260, fill=GOLD_LIGHT, width=6)


def coin_pile(im, rows, r=62, base_y=410, cx=256):
    """A heap of coins: `rows` rows, each one coin narrower, stacked bottom up."""
    d = ImageDraw.Draw(im)
    for row in range(rows):
        count = rows - row
        y = base_y - row * r * 0.62
        for k in range(count):
            x = cx + (k - (count - 1) / 2) * r * 1.35
            coin(d, x, y, r)


def coin_stack(im, cx, base_y, n, r=58):
    d = ImageDraw.Draw(im)
    for k in range(n):
        coin(d, cx, base_y - k * r * 0.3, r)


def sparkle(d, cx, cy, r, fill=CREAM):
    d.polygon([(cx, cy - r), (cx + r * 0.22, cy - r * 0.22), (cx + r, cy), (cx + r * 0.22, cy + r * 0.22), (cx, cy + r), (cx - r * 0.22, cy + r * 0.22), (cx - r, cy), (cx - r * 0.22, cy - r * 0.22)], fill=fill, outline=INK)


def star(d, cx, cy, r, fill):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=INK, width=5)


def silhouette(figure, fill, scale=1.0, offset=(0, 0)):
    """A hero's outline filled with one colour and a question mark: a hero to choose."""
    alpha = figure.split()[3]
    if scale != 1.0:
        size = int(S * scale)
        alpha = alpha.resize((size, size), Image.LANCZOS)
    top = (S - alpha.size[0]) // 2 + offset[0], (S - alpha.size[1]) // 2 + offset[1]
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body.paste(fill, top, alpha)
    layer = sticker(body)
    bbox = body.split()[3].getbbox()
    if bbox:
        cx = (bbox[0] + bbox[2]) / 2
        cy = bbox[1] + (bbox[3] - bbox[1]) * 0.36
        label(layer, (cx, cy), "?", int(150 * scale), fill=CREAM)
    return layer


def drawn_icons(out, starter_hero, pick_figure):
    # Gold packs: a bigger heap and a bigger number for each tier.
    for key, rows, amount, colour in (("gold1000", 2, "1K", (86, 170, 96)), ("gold5000", 3, "5K", (64, 150, 214)), ("gold12000", 4, "12K", (150, 96, 222)), ("gold30000", 5, "30K", (232, 140, 36))):
        im = backdrop(colour, (255, 220, 120))
        coin_pile(im, rows, r=74 - rows * 6, base_y=420)
        d = ImageDraw.Draw(im)
        if rows >= 4:
            sparkle(d, 120, 230, 30)
            sparkle(d, 400, 200, 24)
        label(im, (256, 118), amount, 128)
        finish(im, out, f"product_{key}")
    # Starter Pack: the hero it gives, and its Gold.
    im = backdrop((52, 168, 120), (255, 230, 150))
    if starter_hero is not None:
        hero = starter_hero.resize((int(S * 0.95), int(S * 0.95)), Image.LANCZOS)
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        layer.paste(hero, (-70, 20), hero)
        im = Image.alpha_composite(im, sticker(layer))
    coin_stack(im, 372, 440, 5, r=64)
    label(im, (372, 300), "5K", 96)
    finish(im, out, "product_starterPack")
    # Double Gold for an hour of play: a big coin, a big 2x and a clock.
    im = backdrop((222, 116, 36), (255, 220, 120))
    d = ImageDraw.Draw(im)
    coin(d, 256, 360, 150)
    d.ellipse((330, 60, 460, 190), fill=CREAM, outline=INK, width=8)
    d.line((395, 125, 395, 82), fill=INK, width=10)
    d.line((395, 125, 428, 140), fill=INK, width=10)
    label(im, (220, 190), "2x", 190)
    finish(im, out, "product_goldBoost")
    # Season Pass for one season: a ribbon with a star.
    im = backdrop((20, 148, 140), (180, 255, 240))
    d = ImageDraw.Draw(im)
    d.polygon([(150, 100), (362, 100), (362, 410), (256, 344), (150, 410)], fill=(28, 50, 108, 255), outline=INK, width=8)
    d.line((176, 130, 176, 370), fill=(84, 170, 255, 255), width=10)
    star(d, 256, 214, 92, GOLD)
    finish(im, out, "product_seasonPass")
    # Legendary Pack: a legendary hero of your choice and 12,000 Gold.
    im = backdrop((240, 166, 36), (255, 240, 170))
    if pick_figure is not None:
        im = Image.alpha_composite(im, silhouette(pick_figure, GOLD, 0.92, (-40, 0)))
    coin_stack(im, 390, 450, 4, r=60)
    label(im, (390, 330), "12K", 80)
    d = ImageDraw.Draw(im)
    sparkle(d, 92, 120, 30)
    finish(im, out, "product_legendaryBundle")
    # Team Pack: three rare heroes of your choice.
    im = backdrop((52, 112, 216), (180, 220, 255))
    if pick_figure is not None:
        for scale, offset in ((0.74, (-128, 40)), (0.74, (128, 40)), (0.86, (0, 10))):
            im = Image.alpha_composite(im, silhouette(pick_figure, (84, 170, 255, 255), scale, offset))
    finish(im, out, "product_teamBundle")
    # Passes.
    im = backdrop((88, 98, 204), (200, 210, 255))  # collector drone: a magnet pulling a coin
    d = ImageDraw.Draw(im)
    d.arc((136, 110, 376, 350), 180, 360, fill=INK, width=92)
    d.arc((144, 118, 368, 342), 180, 360, fill=(222, 58, 58, 255), width=76)
    for x in (136, 300):
        d.rectangle((x, 230, x + 76, 330), fill=(222, 58, 58, 255), outline=INK, width=8)
        d.rectangle((x, 290, x + 76, 330), fill=CREAM, outline=INK, width=8)
    coin(d, 256, 420, 52)
    for k, y in enumerate((356, 380)):
        d.line((200 + k * 20, y, 220 + k * 20, y + 14), fill=CREAM, width=8)
        d.line((312 - k * 20, y, 292 - k * 20, y + 14), fill=CREAM, width=8)
    finish(im, out, "pass_collector")
    im = backdrop((128, 78, 200), (230, 200, 255))  # training: an open book under a star
    d = ImageDraw.Draw(im)
    d.polygon([(110, 190), (256, 222), (256, 410), (110, 378)], fill=CREAM, outline=INK, width=8)
    d.polygon([(402, 190), (256, 222), (256, 410), (402, 378)], fill=CREAM, outline=INK, width=8)
    for k in range(3):
        d.line((140, 250 + k * 36, 230, 270 + k * 36), fill=(160, 150, 180, 255), width=8)
        d.line((372, 250 + k * 36, 282, 270 + k * 36), fill=(160, 150, 180, 255), width=8)
    star(d, 256, 140, 64, GOLD)
    finish(im, out, "pass_training")
    im = backdrop((204, 150, 36), (255, 240, 170))  # VIP: a crown
    d = ImageDraw.Draw(im)
    d.polygon([(120, 350), (140, 160), (208, 262), (256, 140), (304, 262), (372, 160), (392, 350)], fill=GOLD, outline=INK, width=8)
    d.rectangle((120, 340, 392, 396), fill=GOLD_DARK, outline=INK, width=8)
    for cx in (176, 256, 336):
        d.ellipse((cx - 18, 350, cx + 18, 386), fill=(222, 58, 58, 255), outline=INK, width=5)
    for cx, cy in ((140, 160), (256, 140), (372, 160)):
        d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=CREAM, outline=INK, width=5)
    finish(im, out, "pass_vip")
    im = backdrop((36, 168, 108), (190, 255, 220))  # 3x speed: three chevrons and a 3x
    d = ImageDraw.Draw(im)
    for i in range(3):
        x = 116 + i * 84
        d.polygon([(x, 220), (x + 74, 320), (x, 420), (x + 44, 420), (x + 118, 320), (x + 44, 220)], fill=CREAM, outline=INK, width=6)
    label(im, (256, 130), "3x", 150)
    finish(im, out, "pass_speed3")
    im = backdrop((20, 148, 140), (180, 255, 240))  # permanent season pass: star over a track
    d = ImageDraw.Draw(im)
    for i in range(5):
        d.rounded_rectangle((100 + i * 64, 340, 156 + i * 64, 396), radius=10, fill=GOLD if i < 3 else CREAM, outline=INK, width=6)
    star(d, 256, 200, 110, GOLD)
    finish(im, out, "pass_season")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="*", default=None, help="icon names, e.g. hero_thor product_goldBoost")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    rarity, heroes, starter = catalog_facts()
    wanted = set(args.only or [])
    hero_ids = [h for h in heroes if not wanted or f"hero_{h}" in wanted]
    if hero_ids:
        hero_icons(hero_ids, rarity, OUT)
    if not wanted or any(not w.startswith("hero_") for w in wanted):
        legendary = next((h for h in heroes if rarity.get(h) == "legendary"), heroes[0])
        full = figures([h for h in {starter, legendary} if h], FULL)
        drawn_icons(OUT, full.get(starter), full.get(legendary))
    print(f"{len(list(OUT.glob('*.png')))} icons in {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
