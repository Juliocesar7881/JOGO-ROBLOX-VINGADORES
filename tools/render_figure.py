"""Render hero figures to PNG without Roblox Studio.

    python tools/render_figure.py ironman captain            # front and 3/4 views
    python tools/render_figure.py captain --out test-results/figures --size 480

Builds each hero with the real WorldBuilder (Figure.Hero) against the test
stand-ins, dumps every visible part (CFrame, size, colour, material, shape and
its SpecialMesh), and ray casts them with numpy: blocks, balls, cylinders,
wedges, and the rounded Head/Torso/Sphere meshes approximated as convex
intersections. Lambert light plus ambient, Neon unlit. It judges silhouette,
proportion, colour blocking and floating or buried pieces; Studio stays the
final acceptance gate for materials and lighting.
"""
from __future__ import annotations

import argparse
import math
import os
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

DUMP = r'''
local Stubs = __STUBS__
local Catalog = __CATALOG__
local WorldBuilder = __WORLD__
local world = WorldBuilder.new(Catalog, function() end)
local function num(value) return string.format("%.4f", value or 0) end
local ids = string.split("__IDS__", ",")
for index, id in ipairs(ids) do
	local holder = Instance.new("Model")
	holder.Parent = workspace
	-- "enemy:<id>" draws an enemy or boss (Figure.Enemy) instead of a hero.
	local enemyId = string.match(id, "^enemy:(.+)$")
	local figure = enemyId and WorldBuilder.Figure.Enemy(holder, Catalog.Enemies[enemyId]) or WorldBuilder.Figure.Hero(holder, id, Catalog.Heroes[id], 1)
	if __STATUE__ and not enemyId then WorldBuilder.Figure.PoseStatic(figure.model, WorldBuilder.StatuePose[id]) end
	figure.model:PivotTo(CFrame.new((index - 1) * 24, 0, 0))
	print("H|" .. id .. "|" .. num((index - 1) * 24))
	for _, item in ipairs(figure.model:GetDescendants()) do
		if item:IsA("BasePart") and (item.Transparency or 0) < 0.99 then
			local cf, size, color = item.CFrame, item.Size, item.Color or Color3.new(0.5, 0.5, 0.5)
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local mesh = item:FindFirstChildOfClass("SpecialMesh")
			local meshType = mesh and mesh.MeshType and mesh.MeshType.Name or ""
			local scale = mesh and mesh.Scale or Vector3.new(1, 1, 1)
			print(table.concat({ "P", item.Name, num(cf.X), num(cf.Y), num(cf.Z), num(r.X), num(r.Y), num(r.Z),
				num(u.X), num(u.Y), num(u.Z), num(-l.X), num(-l.Y), num(-l.Z), num(size.X), num(size.Y), num(size.Z),
				num(color.R), num(color.G), num(color.B), num(item.Transparency or 0),
				item.Material and item.Material.Name or "Plastic", item.Shape and item.Shape.Name or "Block",
				item.ClassName or "Part", meshType, num(scale.X), num(scale.Y), num(scale.Z), id }, "|"))
		end
	end
end
'''


def swap_costume(world: str, hero: str, look: Path | None, extras: Path | None) -> str:
    """Replace one hero's HERO_LOOK line and/or HERO_EXTRAS function in the
    WorldBuilder source, in memory only: a designer can try a costume from a
    scratch file without touching the repository."""
    lines = world.replace("\r\n", "\n").split("\n")
    if look is not None:
        key = "\t" + hero + " = {"
        hits = [i for i, line in enumerate(lines) if line.startswith(key)]
        if not hits:
            raise SystemExit(f"No HERO_LOOK entry starts with {key!r}")
        lines[hits[0]] = "\t" + look.read_text(encoding="utf-8").strip().rstrip(",") + ","
    if extras is not None:
        start = [i for i, line in enumerate(lines) if line.startswith(f"HERO_EXTRAS.{hero} = function")]
        if not start:
            raise SystemExit(f"No HERO_EXTRAS.{hero} function")
        end = start[0] + 1
        while end < len(lines) and not lines[end].startswith(("HERO_EXTRAS.", "local ", "function ")):
            end += 1
        lines[start[0]:end] = extras.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip("\n").split("\n")
    return "\n".join(lines)


def dump(ids: list[str], swaps=None, statue=False) -> str:
    source = DUMP.replace("__IDS__", ",".join(ids)).replace("__STATUE__", "true" if statue else "false")
    for token, relative in (("__STUBS__", "tests/roblox_stubs.luau"), ("__CATALOG__", "src/shared/Catalog.luau"), ("__WORLD__", "src/server/WorldBuilder.luau")):
        body = (ROOT / relative).read_text(encoding="utf-8-sig")
        if token == "__WORLD__" and swaps:
            for hero, look, extras in swaps:
                body = swap_costume(body, hero, look, extras)
        source = source.replace(token, "(function()\n" + body + "\nend)()")
    with tempfile.TemporaryDirectory(prefix="doomsday-figure-") as temporary:
        script = Path(temporary) / "dump.luau"
        script.write_text(source, encoding="utf-8")
        # DOOM_LUAU: a worktree without .tools can point at the main checkout's CLI.
        luau = os.environ.get("DOOM_LUAU") or str(ROOT / ".tools" / "luau" / "luau.exe")
        result = subprocess.run([luau, str(script)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise SystemExit(result.stdout[-3000:] + result.stderr[-3000:])
    return result.stdout


class Piece:
    def __init__(self, fields):
        v = [float(x) for x in fields[2:21]]
        self.name = fields[1]
        self.c = np.array(v[0:3])
        # Rows: the part's right, up and back (+Z) axes in world space.
        self.R = np.array([v[3:6], v[6:9], v[9:12]])
        self.size = np.array(v[12:15])
        self.color = np.array(v[15:18])
        self.alpha = 1 - v[18]
        self.material = fields[21]
        self.shape = fields[22]
        self.cls = fields[23]
        self.mesh = fields[24]
        self.mscale = np.array([float(x) for x in fields[25:28]])
        self.hero = fields[28]


def parse(text: str):
    pieces, heroes = [], []
    for line in text.splitlines():
        f = line.split("|")
        if f[0] == "P" and len(f) >= 29:
            pieces.append(Piece(f))
        elif f[0] == "H":
            heroes.append((f[1], float(f[2])))
    return pieces, heroes


def _slab(o, d, half):
    """Ray vs axis-aligned box in local space. Returns t0, t1, normal axis index and sign at entry."""
    with np.errstate(divide="ignore", invalid="ignore"):
        inv = 1.0 / np.where(np.abs(d) < 1e-9, 1e-9, d)
        t1 = (-half - o) * inv
        t2 = (half - o) * inv
    tmin = np.minimum(t1, t2)
    tmax = np.maximum(t1, t2)
    enter = tmin.max(axis=1)
    leave = tmax.min(axis=1)
    axis = tmin.argmax(axis=1)
    sign = -np.sign(np.take_along_axis(d, axis[:, None], axis=1)[:, 0])
    normal = np.zeros_like(o)
    normal[np.arange(len(o)), axis] = sign
    return enter, leave, normal


def _ellipsoid(o, d, semi):
    oo, dd = o / semi, d / semi
    a = (dd * dd).sum(1)
    b = 2 * (oo * dd).sum(1)
    c = (oo * oo).sum(1) - 1
    disc = b * b - 4 * a * c
    ok = disc >= 0
    sq = np.sqrt(np.where(ok, disc, 0))
    t0 = np.where(ok, (-b - sq) / (2 * a), np.inf)
    t1 = np.where(ok, (-b + sq) / (2 * a), -np.inf)
    p = o + d * t0[:, None]
    normal = p / (semi * semi)
    return t0, t1, normal


def _cylinder(o, d, axis, semi_r, half_len):
    """Elliptic cylinder along local `axis` (0=x, 1=y), capped."""
    other = [i for i in range(3) if i != axis]
    oo = o[:, other] / semi_r
    dd = d[:, other] / semi_r
    a = (dd * dd).sum(1)
    b = 2 * (oo * dd).sum(1)
    c = (oo * oo).sum(1) - 1
    disc = b * b - 4 * a * c
    ok = (disc >= 0) & (a > 1e-12)
    sq = np.sqrt(np.where(ok, disc, 0))
    with np.errstate(divide="ignore", invalid="ignore"):
        s0 = np.where(ok, (-b - sq) / (2 * a), np.inf)
        s1 = np.where(ok, (-b + sq) / (2 * a), -np.inf)
    # Rays parallel to the axis: inside the circle -> infinite slab.
    parallel = a <= 1e-12
    inside = c <= 0
    s0 = np.where(parallel & inside, -np.inf, s0)
    s1 = np.where(parallel & inside, np.inf, s1)
    with np.errstate(divide="ignore", invalid="ignore"):
        da = np.where(np.abs(d[:, axis]) < 1e-9, 1e-9, d[:, axis])
        c0 = (-half_len - o[:, axis]) / da
        c1 = (half_len - o[:, axis]) / da
    cmin, cmax = np.minimum(c0, c1), np.maximum(c0, c1)
    enter = np.maximum(s0, cmin)
    leave = np.minimum(s1, cmax)
    p = o + d * enter[:, None]
    normal = np.zeros_like(o)
    side = s0 >= cmin
    radial = p[:, other] / (semi_r * semi_r)
    normal[:, other[0]] = np.where(side, radial[:, 0], 0)
    normal[:, other[1]] = np.where(side, radial[:, 1], 0)
    normal[:, axis] = np.where(side, 0, -np.sign(d[:, axis]))
    return enter, leave, normal


def _wedge(o, d, half):
    """Roblox WedgePart: solid under the plane from the top-back edge to the bottom-front edge."""
    enter, leave, normal = _slab(o, d, half)
    # Plane: y/hy - z/hz <= 0  (local back is +Z).
    n = np.array([0.0, 1.0 / half[1], -1.0 / half[2]])
    denom = d @ n
    num = -(o @ n)
    with np.errstate(divide="ignore", invalid="ignore"):
        tp = num / np.where(np.abs(denom) < 1e-12, 1e-12, denom)
    entering = denom < 0
    inside_now = (o @ n) <= 0
    pe = np.where(entering, tp, np.where(inside_now, -np.inf, np.inf))
    pl = np.where(entering, np.inf, np.where(inside_now | (denom > 0), np.where(denom > 0, tp, np.inf), -np.inf))
    new_enter = np.maximum(enter, pe)
    new_leave = np.minimum(leave, pl)
    plane_entry = pe > enter
    normal = np.where(plane_entry[:, None], n / np.linalg.norm(n), normal)
    return new_enter, new_leave, normal


def intersect(piece: Piece, origin, dirs):
    d = dirs @ piece.R.T
    o = np.broadcast_to((origin - piece.c) @ piece.R.T, d.shape).copy()
    size = piece.size * (piece.mscale if piece.mesh else 1)
    half = size / 2
    if piece.cls == "WedgePart":
        e, l, n = _wedge(o, d, half)
    elif piece.mesh == "Sphere" or (piece.shape == "Ball" and not piece.mesh):
        semi = half if piece.mesh == "Sphere" else np.full(3, piece.size.min() / 2)
        e, l, n = _ellipsoid(o, d, semi)
    elif piece.shape == "Cylinder" and piece.mesh in ("", "Brick"):
        r = min(size[1], size[2]) / 2
        e, l, n = _cylinder(o, d, 0, np.array([r, r]), half[0])
    elif piece.mesh == "Head":
        # Roblox's head mesh: a cylinder standing on Y with rounded rims.
        e1, l1, n1 = _cylinder(o, d, 1, np.array([half[0], half[2]]), half[1])
        e2, l2, n2 = _ellipsoid(o, d, half * np.array([1.08, 1.45, 1.08]))
        e = np.maximum(e1, e2)
        l = np.minimum(l1, l2)
        n = np.where((e2 > e1)[:, None], n2, n1)
    elif piece.mesh == "Torso":
        e1, l1, n1 = _slab(o, d, half)
        e2, l2, n2 = _ellipsoid(o, d, half * np.array([1.32, 1.5, 1.6]))
        e = np.maximum(e1, e2)
        l = np.minimum(l1, l2)
        n = np.where((e2 > e1)[:, None], n2, n1)
    else:
        e, l, n = _slab(o, d, half)
    hit = (e < l) & (l > 0)
    t = np.where(hit, np.maximum(e, 0), np.inf)
    with np.errstate(invalid="ignore", over="ignore"):
        n = n @ piece.R
    norm = np.linalg.norm(n, axis=1, keepdims=True)
    n = n / np.where(norm < 1e-9, 1, norm)
    return t, n


def render(pieces, center, eye, size=(480, 600), fov=30, transparent=False):
    w, h = size
    forward = center - eye
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, np.array([0, 1.0, 0]))
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    tan = math.tan(math.radians(fov) / 2)
    xs = (np.arange(w) + 0.5) / w * 2 - 1
    ys = 1 - (np.arange(h) + 0.5) / h * 2
    gx, gy = np.meshgrid(xs * tan * w / h, ys * tan)
    dirs = forward[None, :] + gx.reshape(-1, 1) * right[None, :] + gy.reshape(-1, 1) * up[None, :]
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    depth = np.full(w * h, np.inf)
    color = np.zeros((w * h, 3))
    color[:] = np.array([0.86, 0.9, 0.95])
    light = np.array([-0.45, 0.75, -0.55])
    light /= np.linalg.norm(light)
    for piece in pieces:
        t, n = intersect(piece, eye, dirs)
        closer = t < depth
        if not closer.any():
            continue
        lambert = np.clip(n[closer] @ light, 0, 1)
        facing = np.clip(-(n[closer] * dirs[closer]).sum(1), 0, 1)
        if piece.material == "Neon":
            shade = np.ones_like(lambert) * 1.05
        else:
            shade = 0.42 + 0.58 * lambert
            if piece.material == "Metal":
                shade = shade + 0.12 * facing ** 8
        depth[closer] = t[closer]
        color[closer] = np.clip(piece.color[None, :] * shade[:, None], 0, 1)
    img = (color.reshape(h, w, 3) * 255).astype(np.uint8)
    # Ink outline where depth jumps: reads like the in-game silhouette.
    d = depth.reshape(h, w)
    finite = np.isfinite(d)
    edge = np.zeros_like(finite)
    edge[:, 1:] |= finite[:, 1:] != finite[:, :-1]
    edge[1:, :] |= finite[1:, :] != finite[:-1, :]
    img[edge] = (30, 34, 46)
    if transparent:
        # The figure alone (outline included) on a clear background, for icons.
        grown = finite.copy()
        grown[:, 1:] |= finite[:, :-1]
        grown[:, :-1] |= finite[:, 1:]
        grown[1:, :] |= finite[:-1, :]
        grown[:-1, :] |= finite[1:, :]
        alpha = (grown * 255).astype(np.uint8)
        return Image.fromarray(np.dstack([img, alpha]), "RGBA")
    return Image.fromarray(img)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ids", nargs="+")
    parser.add_argument("--out", default="test-results/figures")
    parser.add_argument("--size", type=int, default=420, help="width of one view in pixels")
    parser.add_argument("--name", default=None)
    parser.add_argument("--statue", action="store_true", help="pose each hero like its lobby statue (World.StatuePose)")
    parser.add_argument("--look", action="append", default=[], metavar="HERO=FILE", help="replace HERO's HERO_LOOK line with FILE's one-line table (in memory only)")
    parser.add_argument("--extras", action="append", default=[], metavar="HERO=FILE", help="replace HERO_EXTRAS.HERO with the function in FILE (in memory only)")
    args = parser.parse_args()
    swaps = {}
    for kind, entries in (("look", args.look), ("extras", args.extras)):
        for entry in entries:
            hero, _, file = entry.partition("=")
            swaps.setdefault(hero, {"look": None, "extras": None})[kind] = Path(file)
    pieces, heroes = parse(dump(args.ids, [(hero, v["look"], v["extras"]) for hero, v in swaps.items()], args.statue))
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    w = args.size
    h = int(w * 1.3)
    sheet = Image.new("RGB", (w * 3 * len(heroes), h + 26), (240, 242, 246))
    draw = ImageDraw.Draw(sheet)
    for index, (hero, x) in enumerate(heroes):
        own = [p for p in pieces if p.hero == hero]
        top = max(p.c[1] + p.size.max() / 2 for p in own)
        center = np.array([x, top * 0.5, 0])
        dist = top * 2.35
        views = [
            ("frente", center + np.array([0, top * 0.08, -dist])),
            ("3/4", center + np.array([dist * 0.62, top * 0.18, -dist * 0.78])),
            ("costas", center + np.array([-dist * 0.5, top * 0.12, dist * 0.86])),
        ]
        for v, (label, eye) in enumerate(views):
            image = render(own, center, eye, (w, h))
            sheet.paste(image, ((index * 3 + v) * w, 26))
            draw.text(((index * 3 + v) * w + 8, 6), f"{hero}  {label}", fill=(20, 24, 34))
    name = args.name or "_".join(args.ids).replace(":", "-")
    path = out / f"{name}.png"
    sheet.save(path)
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
