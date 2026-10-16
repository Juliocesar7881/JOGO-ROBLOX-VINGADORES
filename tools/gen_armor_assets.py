"""Generate the heroes' armour block: a unit box with well-rounded edges and the
painted finish it wears (owner, 16/10: "faça tudo necessário... só precisa ser
gratuito", with two pictures of glossy, chunky armoured toys).

    python tools/gen_armor_assets.py

Writes assets/meshes/armor_block.obj (+ .mtl) and assets/meshes/armor_detail.png.
The mesh spans -0.5..0.5 on every axis (a SpecialMesh FileMesh scales it to any
piece: Scale = the piece's size), its edges rounded with a radius of 0.16, each
face mapped onto the whole texture. The texture is near-white so the mesh's
VertexColor tints it to the piece's colour: a soft shade toward the rims and an
inset panel line, the painted detail of the pictures' armour. Both files are
our own, made here; Studio's 3D importer uploads them to the owner's account
(free) and their asset ids go in src/shared/Config.luau (Config.Art).
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "meshes"
RADIUS = 0.16
BAND_STEPS = 6


def grid() -> list[float]:
    """Coordinates along one axis: dense across the rounded rims, sparse in the flat middle."""
    rim = [-0.5 + RADIUS * (1 - math.cos(k / BAND_STEPS * math.pi / 2)) for k in range(BAND_STEPS + 1)]
    inner = -0.5 + RADIUS
    middle = [inner + (1 - 2 * RADIUS) * t for t in (0.25, 0.5, 0.75)]
    left = rim
    right = [-v for v in reversed(rim)]
    return left + middle + right


def rounded(point: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    inner = 0.5 - RADIUS
    core = np.clip(point, -inner, inner)
    offset = point - core
    length = np.linalg.norm(offset)
    if length < 1e-9:
        return point, None
    normal = offset / length
    return core + normal * RADIUS, normal


FACES = [
    # (normal axis, sign, u axis, v axis)
    (0, 1, 2, 1), (0, -1, 2, 1),
    (1, 1, 0, 2), (1, -1, 0, 2),
    (2, 1, 0, 1), (2, -1, 0, 1),
]


def build_mesh() -> tuple[list, list, list, list]:
    coords = grid()
    vertices, normals, uvs, faces = [], [], [], []
    for axis, sign, ua, va in FACES:
        base = len(vertices)
        n = len(coords)
        for j, v in enumerate(coords):
            for i, u in enumerate(coords):
                p = np.zeros(3)
                p[axis] = 0.5 * sign
                p[ua] = u
                p[va] = v
                q, normal = rounded(p)
                if normal is None:
                    normal = np.zeros(3)
                    normal[axis] = sign
                vertices.append(q)
                normals.append(normal)
                uvs.append((u + 0.5, v + 0.5))
        for j in range(n - 1):
            for i in range(n - 1):
                a = base + j * n + i
                b, c, d = a + 1, a + n, a + n + 1
                # Counter-clockwise seen from outside.
                tri1, tri2 = (a, b, d), (a, d, c)
                pa, pb, pc = vertices[tri1[0]], vertices[tri1[1]], vertices[tri1[2]]
                outward = np.dot(np.cross(pb - pa, pc - pa), normals[a] + normals[d])
                if outward < 0:
                    tri1, tri2 = (a, d, b), (a, c, d)
                faces.append(tri1)
                faces.append(tri2)
    return vertices, normals, uvs, faces


def write_obj(vertices, normals, uvs, faces) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["# Doomsday armour block: unit box, edges rounded r=0.16 (tools/gen_armor_assets.py)",
             "mtllib armor_block.mtl", "o ArmorBlock"]
    lines += [f"v {p[0]:.5f} {p[1]:.5f} {p[2]:.5f}" for p in vertices]
    lines += [f"vt {u:.5f} {v:.5f}" for u, v in uvs]
    lines += [f"vn {n[0]:.5f} {n[1]:.5f} {n[2]:.5f}" for n in normals]
    lines.append("usemtl ArmorDetail")
    lines += [f"f {a + 1}/{a + 1}/{a + 1} {b + 1}/{b + 1}/{b + 1} {c + 1}/{c + 1}/{c + 1}" for a, b, c in faces]
    (OUT / "armor_block.obj").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (OUT / "armor_block.mtl").write_text(
        "newmtl ArmorDetail\nKa 1 1 1\nKd 1 1 1\nKs 0 0 0\nd 1\nillum 1\nmap_Kd armor_detail.png\n", encoding="utf-8")


def write_texture(size: int = 512) -> None:
    """Near-white so VertexColor sets the hue: a soft shade toward the rims, an
    inset panel line with a light edge under it, and a faint top light."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1)
    edge = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    shade = 0.86 + 0.14 * np.clip(edge / 0.22, 0, 1) ** 0.6
    inset = 0.17
    frame = np.abs(np.maximum(np.abs(x - 0.5), np.abs(y - 0.5)) - (0.5 - inset))
    line = np.clip(1 - frame / 0.012, 0, 1)
    glint = np.clip(1 - np.abs(np.maximum(np.abs(x - 0.5), np.abs(y - 0.5)) - (0.5 - inset - 0.022)) / 0.01, 0, 1)
    top = 0.97 + 0.03 * (1 - y)
    value = shade * top * (1 - 0.22 * line) + 0.06 * glint
    rgb = np.clip(value, 0, 1)
    image = Image.fromarray((np.stack([rgb, rgb, rgb], axis=-1) * 255).astype(np.uint8), "RGB")
    image = image.filter(ImageFilter.GaussianBlur(0.6))
    image.save(OUT / "armor_detail.png")


def main() -> int:
    vertices, normals, uvs, faces = build_mesh()
    write_obj(vertices, normals, uvs, faces)
    write_texture()
    print(f"armor_block.obj: {len(vertices)} vertices, {len(faces)} triangles; armor_detail.png written to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
