"""Render the real generated maps to PNG, without Roblox Studio.

Run: python tools/render_preview.py [--map manhattan] [--out previews]

Builds a map with the real WorldBuilder against the test stand-ins, dumps
every visible part, and draws two pictures with a tiny pure-Python
rasteriser: a top-down plan (layout, clearances, streets) and a perspective
view from a commander standing on the field. It is flat-shaded boxes — no
materials, shadows or glow — so it judges composition, not final looks.
Studio playtests remain the real visual acceptance gate.
"""
from __future__ import annotations

import argparse
import math
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

DUMP = r'''
local Stubs = __STUBS__
local Catalog = __CATALOG__
local WorldBuilder = __WORLD__
local world = WorldBuilder.new(Catalog, function() end)
local target = workspace.DoomLobby
if "__MAP__" ~= "lobby" then
	world:Build("__MAP__")
	for index, spot in ipairs({ { 20, 20 }, { -20, -32 }, { 44, 0 } }) do
		world:MakeTower("preview" .. index, Catalog.HeroOrder[index], Stubs.v3(spot[1], 0, spot[2]), 1)
	end
	target = workspace.DoomWorld
end
local function num(value) return string.format("%.3f", value or 0) end
for _, item in ipairs(target:GetDescendants()) do
	if item:IsA("BasePart") and (item.Transparency or 0) < 0.99 then
		local cf, size, color = item.CFrame, item.Size, item.Color or Color3.new(0.5, 0.5, 0.5)
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		print(table.concat({ "P", item.Name, num(cf.X), num(cf.Y), num(cf.Z), num(r.X), num(r.Y), num(r.Z),
			num(u.X), num(u.Y), num(u.Z), num(-l.X), num(-l.Y), num(-l.Z), num(size.X), num(size.Y), num(size.Z),
			num(color.R), num(color.G), num(color.B), num(item.Transparency or 0),
			item.Material and item.Material.Name or "Plastic", item.Shape and item.Shape.Name or "Block",
			item.ClassName or "Part" }, "|"))
	end
end
for name, color in pairs(rawget(workspace.Terrain, "__materialColors") or {}) do
	print(table.concat({ "M", name, num(color.R), num(color.G), num(color.B) }, "|"))
end
for _, fill in ipairs(rawget(workspace.Terrain, "__fills") or {}) do
	local p = fill.cframe and fill.cframe.Position or fill.center
	local s = fill.size or Stubs.v3(fill.radius * 2, fill.radius * 2, fill.radius * 2)
	print(table.concat({ "T", fill.kind, num(p.X), num(p.Y), num(p.Z), num(s.X), num(s.Y), num(s.Z), fill.material.Name }, "|"))
end
'''

TERRAIN_DEFAULTS = {
    "Grass": (0.42, 0.5, 0.25), "LeafyGrass": (0.35, 0.45, 0.22), "Sand": (0.78, 0.66, 0.46), "Snow": (0.9, 0.92, 0.95),
    "Rock": (0.45, 0.45, 0.45), "Basalt": (0.3, 0.3, 0.32), "Water": (0.2, 0.4, 0.6), "Mud": (0.3, 0.26, 0.2),
    "Ground": (0.4, 0.36, 0.28), "Concrete": (0.5, 0.5, 0.5), "Pavement": (0.45, 0.46, 0.48), "Asphalt": (0.2, 0.2, 0.22),
    "Slate": (0.35, 0.36, 0.38),
}


def run_dump(map_id: str) -> str:
    source = DUMP.replace("__MAP__", map_id)
    for token, relative in (("__STUBS__", "tests/roblox_stubs.luau"), ("__CATALOG__", "src/shared/Catalog.luau"), ("__WORLD__", "src/server/WorldBuilder.luau")):
        body = (ROOT / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function()\n" + body + "\nend)()")
    with tempfile.TemporaryDirectory(prefix="doomsday-preview-") as temporary:
        script = Path(temporary) / "dump.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(ROOT / ".tools" / "luau" / "luau.exe"), str(script)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise SystemExit(result.stdout + result.stderr)
    return result.stdout


class Box:
    __slots__ = ("name", "c", "axes", "half", "color", "alpha", "material", "top")

    def __init__(self, name, c, axes, half, color, alpha, material):
        self.name, self.c, self.axes, self.half = name, c, axes, half
        self.color, self.alpha, self.material = color, alpha, material
        self.top = max(p[1] for p in self.corners())

    def corners(self):
        (cx, cy, cz), axes, (hx, hy, hz) = self.c, self.axes, self.half
        out = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    out.append((
                        cx + axes[0][0] * hx * sx + axes[1][0] * hy * sy + axes[2][0] * hz * sz,
                        cy + axes[0][1] * hx * sx + axes[1][1] * hy * sy + axes[2][1] * hz * sz,
                        cz + axes[0][2] * hx * sx + axes[1][2] * hy * sy + axes[2][2] * hz * sz,
                    ))
        return out


def parse(dump: str):
    boxes, terrain, colors = [], [], {}
    for line in dump.splitlines():
        fields = line.split("|")
        if fields[0] == "P" and len(fields) >= 24:
            v = [float(x) for x in fields[2:21]]
            c = (v[0], v[1], v[2])
            axes = ((v[3], v[4], v[5]), (v[6], v[7], v[8]), (v[9], v[10], v[11]))
            half = (v[12] / 2, v[13] / 2, v[14] / 2)
            boxes.append(Box(fields[1], c, axes, half, (v[15], v[16], v[17]), 1 - v[18], fields[21]))
        elif fields[0] == "M":
            colors[fields[1]] = tuple(float(x) for x in fields[2:5])
        elif fields[0] == "T":
            v = [float(x) for x in fields[2:8]]
            terrain.append((fields[1], v, fields[8]))
    for order, (kind, v, material) in enumerate(terrain):
        if material == "Air":
            continue
        color = colors.get(material, TERRAIN_DEFAULTS.get(material, (0.5, 0.5, 0.5)))
        (x, y, z, sx, sy, sz) = v
        if kind == "Ball":
            boxes.append(Box("Terrain" + material, (x, y, z), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (sx / 2, sx / 2, sx / 2), color, 1, material))
            continue
        # Terrain is drawn as its top surface in 16-stud tiles, so a camera
        # standing on it never loses the whole ground to near-plane clipping.
        # Later fills sit a hair higher, as they overwrite earlier ones.
        top = y + sy / 2 + order * 0.002
        tile = 16.0
        tx = x - sx / 2
        while tx < x + sx / 2 - 1e-6:
            w = min(tile, x + sx / 2 - tx)
            tz = z - sz / 2
            while tz < z + sz / 2 - 1e-6:
                d = min(tile, z + sz / 2 - tz)
                boxes.append(Box("Terrain" + material, (tx + w / 2, top - 0.05, tz + d / 2), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (w / 2, 0.05, d / 2), color, 1, material))
                tz += d
            tx += w
    return boxes


class Canvas:
    def __init__(self, width, height, background):
        self.w, self.h = width, height
        self.rgb = bytearray(bytes(int(c * 255) for c in background) * (width * height))
        self.depth = [math.inf] * (width * height)

    def put(self, x, y, color, depth=None, alpha=1.0):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        i = y * self.w + x
        if depth is not None:
            if depth >= self.depth[i]:
                return
            if alpha >= 0.99:
                self.depth[i] = depth
        o = i * 3
        for k in range(3):
            value = max(0.0, min(1.0, color[k]))
            if alpha < 0.99:
                value = self.rgb[o + k] / 255 * (1 - alpha) + value * alpha
            self.rgb[o + k] = int(value * 255)

    def save(self, path: Path):
        raw = b"".join(b"\x00" + bytes(self.rgb[y * self.w * 3:(y + 1) * self.w * 3]) for y in range(self.h))

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
        path.write_bytes(png)


def hull(points):
    points = sorted(set(points))
    if len(points) <= 2:
        return points

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def fill_polygon(canvas, polygon, color, alpha=1.0):
    if len(polygon) < 3:
        return
    ys = [p[1] for p in polygon]
    for y in range(max(0, int(min(ys))), min(canvas.h - 1, int(max(ys))) + 1):
        yc = y + 0.5
        xs = []
        for i in range(len(polygon)):
            (x1, y1), (x2, y2) = polygon[i], polygon[(i + 1) % len(polygon)]
            if (y1 <= yc < y2) or (y2 <= yc < y1):
                xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for a, b in zip(xs[::2], xs[1::2]):
            for x in range(max(0, int(a + 0.5)), min(canvas.w - 1, int(b + 0.5)) + 1):
                canvas.put(x, y, color, None, alpha)


def plan(boxes, path: Path, reach=150, scale=3):
    size = reach * 2 * scale
    canvas = Canvas(size, size, (0.05, 0.06, 0.08))
    for box in sorted(boxes, key=lambda b: b.top):
        shade = 0.75 + min(0.35, max(0.0, box.top) / 120)
        color = tuple(min(1.0, c * shade) for c in box.color)
        points = [((p[0] + reach) * scale, (p[2] + reach) * scale) for p in box.corners()]
        fill_polygon(canvas, hull(points), color, box.alpha)
    # The build boundary, for judging clearances.
    for t in range(-106 * scale, 106 * scale):
        for a, b in ((t, -106 * scale), (t, 106 * scale), (-106 * scale, t), (106 * scale, t)):
            canvas.put(int(a + reach * scale), int(b + reach * scale), (1, 0.2, 0.9))
    canvas.save(path)


FACES = (((0, 2, 3, 1), (-1, 0, 0)), ((4, 5, 7, 6), (1, 0, 0)), ((0, 1, 5, 4), (0, -1, 0)),
         ((2, 6, 7, 3), (0, 1, 0)), ((0, 4, 6, 2), (0, 0, -1)), ((1, 3, 7, 5), (0, 0, 1)))


def perspective(boxes, path: Path, eye, target, width=960, height=540, fov=70, fog=(0.12, 0.15, 0.22), fog_end=420):
    canvas = Canvas(width, height, fog)
    fx, fy, fz = (target[0] - eye[0], target[1] - eye[1], target[2] - eye[2])
    n = math.sqrt(fx * fx + fy * fy + fz * fz)
    forward = (fx / n, fy / n, fz / n)
    # right = forward x worldUp, up = right x forward (Y up, right-handed).
    right = (-forward[2], 0, forward[0])
    rn = math.sqrt(right[0] ** 2 + right[2] ** 2)
    right = (right[0] / rn, 0, right[2] / rn)
    up = (right[1] * forward[2] - right[2] * forward[1], right[2] * forward[0] - right[0] * forward[2], right[0] * forward[1] - right[1] * forward[0])
    focal = (width / 2) / math.tan(math.radians(fov / 2))
    light = (0.35, 0.85, 0.4)
    ln = math.sqrt(sum(c * c for c in light))
    light = tuple(c / ln for c in light)

    def project(p):
        d = (p[0] - eye[0], p[1] - eye[1], p[2] - eye[2])
        z = d[0] * forward[0] + d[1] * forward[1] + d[2] * forward[2]
        x = d[0] * right[0] + d[1] * right[1] + d[2] * right[2]
        y = d[0] * up[0] + d[1] * up[1] + d[2] * up[2]
        if z < 0.5:
            return None
        return (width / 2 + x * focal / z, height / 2 - y * focal / z, z)

    for box in boxes:
        corners = box.corners()
        projected = [project(p) for p in corners]
        for indices, normal_local in FACES:
            ax = box.axes
            normal = tuple(ax[0][k] * normal_local[0] + ax[1][k] * normal_local[1] + ax[2][k] * normal_local[2] for k in range(3))
            center = tuple(sum(corners[i][k] for i in indices) / 4 for k in range(3))
            view = tuple(center[k] - eye[k] for k in range(3))
            if normal[0] * view[0] + normal[1] * view[1] + normal[2] * view[2] >= 0:
                continue
            quad = [projected[i] for i in indices]
            if any(q is None for q in quad):
                continue
            emissive = box.material == "Neon"
            diffuse = max(0.0, normal[0] * light[0] + normal[1] * light[1] + normal[2] * light[2])
            shade = 1.25 if emissive else 0.45 + 0.65 * diffuse
            base = tuple(min(1.0, c * shade) for c in box.color)
            for tri in ((quad[0], quad[1], quad[2]), (quad[0], quad[2], quad[3])):
                raster_triangle(canvas, tri, base, box.alpha, fog, fog_end, emissive)
    canvas.save(path)


def raster_triangle(canvas, tri, color, alpha, fog, fog_end, emissive):
    (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = tri
    minx, maxx = max(0, int(min(x0, x1, x2))), min(canvas.w - 1, int(max(x0, x1, x2)) + 1)
    miny, maxy = max(0, int(min(y0, y1, y2))), min(canvas.h - 1, int(max(y0, y1, y2)) + 1)
    area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
    if abs(area) < 1e-9 or minx > maxx or miny > maxy:
        return
    for y in range(miny, maxy + 1):
        py = y + 0.5
        for x in range(minx, maxx + 1):
            px = x + 0.5
            w0 = ((x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)) / area
            w1 = ((x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)) / area
            w2 = 1 - w0 - w1
            if w0 < 0 or w1 < 0 or w2 < 0:
                continue
            depth = w0 * z0 + w1 * z1 + w2 * z2
            haze = 0 if emissive else min(0.85, max(0.0, (depth - 40) / fog_end))
            shaded = tuple(color[k] * (1 - haze) + fog[k] * haze for k in range(3))
            canvas.put(x, y, shaded, depth, alpha)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", action="append", help="Map id or \"lobby\" (repeatable); defaults to every map")
    parser.add_argument("--out", type=Path, default=ROOT / "previews")
    parser.add_argument("--no-perspective", action="store_true")
    args = parser.parse_args()
    maps = args.map or ["manhattan", "gamma", "hydra", "wakanda", "latveria"]
    args.out.mkdir(parents=True, exist_ok=True)
    for map_id in maps:
        boxes = parse(run_dump(map_id))
        if map_id == "lobby":
            perspective(boxes, args.out / "lobby-spawn.png", eye=(0, 7, 352), target=(0, 5, 300))
            perspective(boxes, args.out / "lobby-overview.png", eye=(0, 70, 420), target=(0, 0, 310))
            print(f"lobby: {len(boxes)} boxes -> {args.out}")
            continue
        plan(boxes, args.out / f"{map_id}-plan.png")
        if not args.no_perspective:
            perspective(boxes, args.out / f"{map_id}-street.png", eye=(-30, 9, 70), target=(10, 4, 20))
            perspective(boxes, args.out / f"{map_id}-overview.png", eye=(0, 105, 105), target=(0, 0, -25))
        print(f"{map_id}: {len(boxes)} boxes -> {args.out}")


if __name__ == "__main__":
    main()
