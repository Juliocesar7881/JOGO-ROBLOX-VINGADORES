"""Ornate armour for the heroes (owner, 16/10: "vá além"): a curved shoulder pad
and gold filigree for the chest, ours, made here.

    python tools/gen_ornate_assets.py

Writes assets/meshes/armor_ornate.obj (+ .mtl) with two groups, so Studio's 3D
importer uploads everything in one go (free):
  - ArmorPad: a domed pauldron, round-cornered square in plan (a squircle), a
    rising dome over a short upright band with a lip at the rim; it spans
    -0.5..0.5 on every axis (a SpecialMesh FileMesh scales it to the pad), and
    wears pad_finish.png: near-white with a groove above the rim and a soft
    ridge, so VertexColor tints it to the pad's colour.
  - Texture_filigree: a plane carrying filigree.png, gold scrollwork on
    transparency, worn as a Decal on a thin plate in front of the chest.
Their ids go in src/shared/Config.luau (Config.Art: padMesh, padTexture,
filigree).
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "meshes"
SEGMENTS = 48
SQUIRCLE = 3.2


def squircle(angle: float) -> tuple[float, float]:
    """A unit round-cornered square, as a function of the angle."""
    c, s = math.cos(angle), math.sin(angle)
    r = (abs(c) ** SQUIRCLE + abs(s) ** SQUIRCLE) ** (-1 / SQUIRCLE)
    return c * r, s * r


def pad_profile() -> list[tuple[float, float]]:
    """(y, radius) from the rim's underside up to the crown."""
    rows = [(-0.5, 0.0), (-0.5, 0.47), (-0.44, 0.5), (-0.36, 0.5), (-0.32, 0.47), (-0.3, 0.47)]
    for k in range(1, 11):
        t = k / 10
        y = -0.3 + 0.8 * t
        r = 0.47 * (1 - t ** 2.4) ** (1 / 2.4)
        rows.append((y, max(r, 0.0)))
    return rows


def build_pad():
    rows = pad_profile()
    vertices, uvs, faces = [], [], []
    for j, (y, r) in enumerate(rows):
        for i in range(SEGMENTS + 1):
            angle = i / SEGMENTS * math.pi * 2
            x, z = squircle(angle)
            vertices.append((x * r, y, z * r))
            uvs.append((i / SEGMENTS, (y + 0.5)))
    width = SEGMENTS + 1
    for j in range(len(rows) - 1):
        for i in range(SEGMENTS):
            a = j * width + i
            b, c, d = a + 1, a + width, a + width + 1
            faces.append((a, c, b))
            faces.append((b, c, d))
    return vertices, uvs, faces


def pad_texture(size: int = 512) -> Image.Image:
    y = np.mgrid[0:size, 0:size][0] / (size - 1)
    v = 1 - y  # image row 0 is the top of the texture (v = 1)
    value = np.full((size, size), 0.95)
    value *= 1 - 0.35 * np.clip(1 - np.abs(v - 0.2) / 0.018, 0, 1)   # groove above the rim
    value *= 1 + 0.05 * np.clip(1 - np.abs(v - 0.23) / 0.012, 0, 1)  # its light edge
    value *= 0.9 + 0.1 * np.clip((v - 0.2) / 0.5, 0, 1)                 # darker toward the rim
    rgb = (np.stack([value, value, value], axis=-1).clip(0, 1) * 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB").filter(ImageFilter.GaussianBlur(0.8))


def filigree(size: int = 512) -> Image.Image:
    """Gold scrollwork: a central diamond, mirrored scrolls and a border."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    gold, light = (238, 186, 58, 255), (255, 226, 130, 255)
    c = size / 2
    # A thin frame (the hero's own emblem keeps the middle).
    draw.rounded_rectangle((22, 22, size - 22, size - 22), radius=56, outline=gold, width=8)
    # Mirrored scrolls (spirals) in the four corners, curling inward.
    for side in (-1, 1):
        for up in (-1, 1):
            cx, cy = c + side * 168, c + up * 150
            points = []
            for k in range(60):
                t = k / 59 * math.pi * 2.6
                r = 54 * (1 - k / 75)
                points.append((cx + side * math.cos(t) * r, cy + up * math.sin(t) * r))
            draw.line(points, fill=gold, width=9, joint="curve")
            draw.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=light)
    # Two small diamonds at the top and bottom of the frame.
    for up in (-1, 1):
        y = c + up * (c - 22)
        draw.polygon([(c, y - 18), (c + 18, y), (c, y + 18), (c - 18, y)], fill=light)
    glow = canvas.filter(ImageFilter.GaussianBlur(5))
    return Image.alpha_composite(glow, canvas)


def write_obj(vertices, uvs, faces) -> None:
    lines = ["# Doomsday ornate armour (tools/gen_ornate_assets.py)", "mtllib armor_ornate.mtl", "o ArmorPad", "g ArmorPad"]
    lines += [f"v {x:.5f} {y:.5f} {z:.5f}" for x, y, z in vertices]
    lines += [f"vt {u:.5f} {v:.5f}" for u, v in uvs]
    lines.append("usemtl pad_finish")
    lines += [f"f {a + 1}/{a + 1} {b + 1}/{b + 1} {c + 1}/{c + 1}" for a, b, c in faces]
    base = len(vertices)
    tb = len(uvs)
    lines += ["o Texture_filigree", "g Texture_filigree"]
    lines += ["v 1.0 -0.5 0", "v 2.0 -0.5 0", "v 2.0 0.5 0", "v 1.0 0.5 0", "vt 0 0", "vt 1 0", "vt 1 1", "vt 0 1"]
    lines.append("usemtl filigree")
    lines.append(f"f {base + 1}/{tb + 1} {base + 2}/{tb + 2} {base + 3}/{tb + 3}")
    lines.append(f"f {base + 1}/{tb + 1} {base + 3}/{tb + 3} {base + 4}/{tb + 4}")
    (OUT / "armor_ornate.obj").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (OUT / "armor_ornate.mtl").write_text(
        "newmtl pad_finish\nKa 1 1 1\nKd 1 1 1\nd 1\nillum 1\nmap_Kd pad_finish.png\n\n"
        "newmtl filigree\nKa 1 1 1\nKd 1 1 1\nd 1\nillum 1\nmap_Kd filigree.png\n", encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    vertices, uvs, faces = build_pad()
    write_obj(vertices, uvs, faces)
    pad_texture().save(OUT / "pad_finish.png")
    filigree().save(OUT / "filigree.png")
    print(f"armor_ornate.obj: pad {len(vertices)} vertices, {len(faces)} triangles; pad_finish.png, filigree.png in {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
