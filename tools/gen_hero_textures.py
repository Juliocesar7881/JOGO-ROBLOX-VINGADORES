"""Paint the signature patterns of the owner's picture (16/10): a galaxy for
Surfista Cósmico's cape, flames for Motoqueiro Chama's pads and gold runes for
Doutor Místico's coat. All three are ours, drawn here from noise and shapes.

    python tools/gen_hero_textures.py

Also armour finishes in the armour block's layout (tools/gen_armor_assets.py:
near-white with a shade toward the rims and an inset panel line, so the mesh's
VertexColor tints them to each piece's colour) with a pattern drawn in grey:
a spider web, fish scales, circuit traces and tiger stripes.

    python tools/gen_hero_textures.py [--carrier NAME] [names...]

Writes every texture to assets/meshes/<name>.png and assets/meshes/<carrier>.obj
(+ .mtl, default hero_textures) with one grouped plane per requested texture,
so Studio's 3D importer uploads them in one go (free) and reports each id as a
MeshPart's TextureID. Their ids go in src/shared/Config.luau (Config.Art).
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "meshes"
SIZE = 512


def noise(rng: np.random.Generator, size: int, octaves: int = 5) -> np.ndarray:
    """Smooth value noise in 0..1 (sum of upsampled random grids)."""
    total = np.zeros((size, size))
    weight = 0.0
    for o in range(octaves):
        cells = 4 * 2 ** o
        grid = rng.random((cells + 1, cells + 1))
        layer = np.array(Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)) / 255.0
        amp = 0.55 ** o
        total += layer * amp
        weight += amp
    return total / weight


def galaxy() -> Image.Image:
    rng = np.random.default_rng(7)
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE
    base = np.stack([0.08 + 0.10 * y, 0.04 + 0.03 * y, 0.22 + 0.16 * (1 - y)], axis=-1)
    cloud = noise(rng, SIZE)
    swirl = noise(rng, SIZE, 4)
    pink = np.clip((cloud - 0.45) * 2.4, 0, 1)[..., None] * np.array([0.85, 0.25, 0.75])
    blue = np.clip((swirl - 0.5) * 2.2, 0, 1)[..., None] * np.array([0.2, 0.45, 1.0])
    image = np.clip(base + pink * 0.7 + blue * 0.6, 0, 1)
    canvas = Image.fromarray((image * 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(canvas)
    for _ in range(260):
        px, py = rng.integers(0, SIZE, 2)
        r = rng.choice([1, 1, 1, 2, 2, 3])
        tone = int(rng.integers(200, 256))
        draw.ellipse((px - r, py - r, px + r, py + r), fill=(tone, tone, 255))
    glow = canvas.filter(ImageFilter.GaussianBlur(2))
    return Image.blend(glow, canvas, 0.7)


def flames() -> Image.Image:
    """Orange-gold tongues of fire rising from the bottom, on transparency."""
    rng = np.random.default_rng(11)
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE
    n = noise(rng, SIZE, 4)
    tongues = 0.5 + 0.5 * np.sin(x * np.pi * 10 + n * 6)
    height = (1 - y) * 1.15 - 0.15 + (tongues - 0.5) * 0.45 + (n - 0.5) * 0.3
    heat = np.clip(1 - height * 1.4, 0, 1)
    alpha = np.clip((heat - 0.25) * 3, 0, 1)
    core = np.clip((heat - 0.6) * 2.5, 0, 1)
    r = np.ones_like(heat)
    g = 0.35 + 0.55 * core
    b = 0.05 + 0.35 * core ** 2
    rgba = np.stack([r, g, b, alpha], axis=-1)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(1.2))


def runes() -> Image.Image:
    """Glowing gold runes down the middle, on transparency."""
    rng = np.random.default_rng(3)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    gold = (255, 206, 90, 255)
    cx = SIZE // 2
    for i in range(5):
        cy = 50 + i * 100
        kind = i % 3
        if kind == 0:
            draw.ellipse((cx - 34, cy - 34, cx + 34, cy + 34), outline=gold, width=7)
            draw.line((cx, cy - 34, cx, cy + 34), fill=gold, width=6)
        elif kind == 1:
            draw.polygon([(cx, cy - 40), (cx + 34, cy), (cx, cy + 40), (cx - 34, cy)], outline=gold, width=7)
            draw.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=gold)
        else:
            draw.line((cx - 34, cy - 30, cx + 34, cy + 30), fill=gold, width=7)
            draw.line((cx + 34, cy - 30, cx - 34, cy + 30), fill=gold, width=7)
            draw.arc((cx - 40, cy - 40, cx + 40, cy + 40), 200, 340, fill=gold, width=6)
    # A gold edge on both sides, like a coat's trim.
    draw.rectangle((14, 0, 30, SIZE), fill=gold)
    draw.rectangle((SIZE - 31, 0, SIZE - 15, SIZE), fill=gold)
    glow = canvas.filter(ImageFilter.GaussianBlur(6))
    return Image.alpha_composite(glow, canvas)


def armour_base(size: int = SIZE) -> np.ndarray:
    """The armour finish's shading (as in tools/gen_armor_assets.py), 0..1 grey."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1)
    edge = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    shade = 0.86 + 0.14 * np.clip(edge / 0.22, 0, 1) ** 0.6
    frame = np.abs(np.maximum(np.abs(x - 0.5), np.abs(y - 0.5)) - (0.5 - 0.17))
    line = np.clip(1 - frame / 0.012, 0, 1)
    return shade * (0.97 + 0.03 * (1 - y)) * (1 - 0.22 * line)


def finish(draw_pattern) -> Image.Image:
    """An armour finish with a grey pattern drawn over it."""
    base = armour_base()
    ink = Image.new("L", (SIZE, SIZE), 0)
    draw_pattern(ImageDraw.Draw(ink))
    ink = np.array(ink.filter(ImageFilter.GaussianBlur(1.0))) / 255.0
    value = np.clip(base * (1 - 0.45 * ink), 0, 1)
    rgb = (np.stack([value, value, value], axis=-1) * 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB")


def web() -> Image.Image:
    def draw(d: ImageDraw.ImageDraw) -> None:
        c = SIZE / 2
        for k in range(8):
            a = k * math.pi / 4
            d.line((c, c, c + math.cos(a) * SIZE, c + math.sin(a) * SIZE), fill=255, width=7)
        for ring in (0.13, 0.25, 0.37, 0.5):
            r = ring * SIZE
            pts = [(c + math.cos(k * math.pi / 4) * r, c + math.sin(k * math.pi / 4) * r) for k in range(9)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                mx, my = (x0 + x1) / 2, (y0 + y1) / 2
                dist = max(1.0, math.hypot(c - mx, c - my))
                sag = 0.12 * r
                d.line((x0, y0, mx + (c - mx) / dist * sag, my + (c - my) / dist * sag, x1, y1), fill=255, width=6, joint="curve")
    return finish(draw)


def scales() -> Image.Image:
    def draw(d: ImageDraw.ImageDraw) -> None:
        r = SIZE / 8
        for row in range(10):
            y = row * r * 0.85
            offset = (row % 2) * r
            for col in range(-1, 6):
                x = col * 2 * r + offset
                d.arc((x - r, y - r, x + r, y + r), 20, 160, fill=255, width=7)
    return finish(draw)


def circuit() -> Image.Image:
    rng = np.random.default_rng(5)

    def draw(d: ImageDraw.ImageDraw) -> None:
        for _ in range(14):
            x, y = (int(v) for v in rng.integers(60, SIZE - 60, 2))
            length = int(rng.integers(50, 160))
            horizontal = rng.random() < 0.5
            x1, y1 = (x + length, y) if horizontal else (x, y + length)
            x1, y1 = min(x1, SIZE - 50), min(y1, SIZE - 50)
            bend = int(rng.integers(30, 80))
            x2, y2 = (x1, y1 + bend) if horizontal else (x1 + bend, y1)
            x2, y2 = min(x2, SIZE - 50), min(y2, SIZE - 50)
            d.line((x, y, x1, y1, x2, y2), fill=255, width=6)
            d.ellipse((x - 11, y - 11, x + 11, y + 11), outline=255, width=6)
            d.ellipse((x2 - 9, y2 - 9, x2 + 9, y2 + 9), fill=255)
    return finish(draw)


def tiger() -> Image.Image:
    rng = np.random.default_rng(9)

    def draw(d: ImageDraw.ImageDraw) -> None:
        for k in range(7):
            y = 30 + k * 70 + int(rng.integers(-12, 12))
            left = int(rng.integers(0, 2)) == 0
            x0 = 0 if left else SIZE
            length = int(rng.integers(150, 260))
            x1 = x0 + length if left else x0 - length
            d.polygon([(x0, y - 22), (x1, y + 4), (x0, y + 22)], fill=255)
    return finish(draw)


TEXTURES = {"web": web, "scales": scales, "circuit": circuit, "tiger": tiger}


def write_planes(names: list[str], carrier: str = "hero_textures") -> None:
    lines = ["# Doomsday hero texture carriers (tools/gen_hero_textures.py)", f"mtllib {carrier}.mtl"]
    mtl = []
    vertex = 0
    for i, name in enumerate(names):
        x = i * 1.5
        # Studio's importer splits an OBJ into meshes by group ("g"), one material each.
        lines.append(f"o Texture_{name}")
        lines.append(f"g Texture_{name}")
        lines += [f"v {x - 0.5:.3f} -0.5 0", f"v {x + 0.5:.3f} -0.5 0", f"v {x + 0.5:.3f} 0.5 0", f"v {x - 0.5:.3f} 0.5 0"]
        lines += ["vt 0 0", "vt 1 0", "vt 1 1", "vt 0 1", "vn 0 0 1"]
        lines.append(f"usemtl {name}")
        v, t, n = vertex + 1, vertex + 1, i + 1
        lines.append(f"f {v}/{t}/{n} {v + 1}/{t + 1}/{n} {v + 2}/{t + 2}/{n}")
        lines.append(f"f {v}/{t}/{n} {v + 2}/{t + 2}/{n} {v + 3}/{t + 3}/{n}")
        vertex += 4
        mtl.append(f"newmtl {name}\nKa 1 1 1\nKd 1 1 1\nd 1\nillum 1\nmap_Kd {name}.png\n")
    (OUT / f"{carrier}.obj").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (OUT / f"{carrier}.mtl").write_text("\n".join(mtl), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*", help="textures for the carrier (default: galaxy flames runes)")
    parser.add_argument("--carrier", default="hero_textures")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    galaxy().save(OUT / "galaxy.png")
    flames().save(OUT / "flames.png")
    runes().save(OUT / "runes.png")
    for name, make in TEXTURES.items():
        make().save(OUT / f"{name}.png")
    names = args.names or ["galaxy", "flames", "runes"]
    write_planes(names, args.carrier)
    print(f"textures and {args.carrier}.obj ({', '.join(names)}) written to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
