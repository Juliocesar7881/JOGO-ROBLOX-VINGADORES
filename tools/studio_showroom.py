"""Line up heroes, enemies or bosses in the open Studio place and photograph them.

    python tools/studio_showroom.py heroes                # all heroes, rows of 6
    python tools/studio_showroom.py heroes ironman hulk   # just these
    python tools/studio_showroom.py enemies               # every enemy and variant
    python tools/studio_showroom.py enemies zombie#2 zombie#3   # a plain family's outfits
    python tools/studio_showroom.py bosses
    python tools/studio_showroom.py clean                 # remove the showroom

Builds with the modules *currently in Studio* (sync first with
tools/studio_sync.py), in a showroom far from the lobby and the maps
(workspace.DoomShowroom, z = -900), points the editor camera at it and saves a
capture of the Studio window only (PrintWindow) under test-results/showroom.
The showroom is removed again at the end unless --keep is given, so a Team
Create collaborator never inherits it. Nothing here is part of the game.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import studio_sync  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "test-results" / "showroom"

SETUP = r'''
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("DoomClient")
-- Fresh copies of the modules in Studio, so a sync shows up immediately.
local function fresh(module)
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	if not ok then error(result) end
	return result
end
local catalog = fresh(RS.DoomShared.Catalog)
local old = workspace:FindFirstChild("DoomShowroom")
if old then old:Destroy() end
local room = Instance.new("Model")
room.Name = "DoomShowroom"
room.Parent = workspace
local ORIGIN_Z = -900
local floor = Instance.new("Part")
floor.Name, floor.Anchored, floor.Size = "ShowroomFloor", true, Vector3.new(260, 1, 140)
floor.CFrame = CFrame.new(0, -0.5, ORIGIN_Z + 30)
floor.Color, floor.Material = Color3.fromRGB(58, 64, 74), Enum.Material.Concrete
floor.Parent = room
'''

HEROES = r'''
local World = fresh(SSS.DoomServer.WorldBuilder)
-- The armour's own block and finish, as the game's World.new hands them over.
local config = fresh(RS.DoomShared.Config)
if config.Art and World.Figure and World.Figure.ArmourArt then
	local art = World.Figure.ArmourArt
	art.mesh, art.texture = config.Art.armorMesh or 0, config.Art.armorTexture or 0
	art.galaxy, art.flames, art.runes = config.Art.galaxy or 0, config.Art.flames or 0, config.Art.runes or 0
	for _, key in ipairs({ "web", "scales", "circuit", "tiger" }) do art[key] = config.Art[key] or 0 end
end
local towers = Instance.new("Folder")
towers.Name, towers.Parent = "Towers", room
local fake = { catalog = catalog, Towers = towers, ClearClutter = function() end }
local ids = __IDS__
if #ids == 0 then ids = catalog.HeroOrder end
local perRow, spacing, rowGap = __PERROW__, __SPACING__, 16
for index, id in ipairs(ids) do
	local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
	local x = (column - (math.min(#ids, perRow) - 1) / 2) * spacing
	World.MakeTower(fake, "show" .. index, id, Vector3.new(x, 0, ORIGIN_Z + row * rowGap), 0)
end
local rows = math.ceil(#ids / perRow)
local width = math.min(#ids, perRow) * spacing
-- Frame the whole group: the wider of its width and a tall hero's height.
local distance = (math.max(width, 14) * 0.95 + (rows - 1) * 10) * __ZOOM__
local look = Vector3.new(0, 3.2 + rows, ORIGIN_Z + (rows - 1) * rowGap * 0.5)
local eye = look + Vector3.new(distance * math.sin(math.rad(35)), 4 + distance * 0.12, __SIDE__ * distance * math.cos(math.rad(35)))
-- Studio's editor camera re-aims at its Focus; set both.
workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, look)
workspace.CurrentCamera.Focus = CFrame.new(look)
print("__MARKER__", #ids)
'''

ENEMIES = r'''
-- The clients clone the figures the server published at boot; republish them
-- from the modules currently in Studio so a new enemy shows its real figure,
-- not the plain block of an id the stale folder does not know.
fresh(SSS.DoomServer.WorldBuilder).Figure.PublishEnemies(catalog)
local effects
do
	local copy = client.Effects:Clone()
	copy.Parent = client
	local ok, result = pcall(require, copy)
	copy:Destroy()
	if not ok then error(result) end
	effects = result
end
local ids = __IDS__
if #ids == 0 then
	for id, def in pairs(catalog.Enemies) do
		if (__BOSSES__ and def.boss) or (not __BOSSES__ and not def.boss) then table.insert(ids, id) end
	end
	table.sort(ids)
end
local perRow, spacing, rowGap = __PERROW__, __SPACING__, __ROWGAP__
for index, id in ipairs(ids) do
	-- "zombie#3" is a plain family's third look (its outfits, Effects.enemyLook).
	local base, look = string.match(id, "^(.-)#(%d+)$")
	local def = catalog.Enemies[base or id]
	local record = effects.BuildEnemy(def, look and tonumber(look) - 1 or nil)
	local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
	local x = (column - (math.min(#ids, perRow) - 1) / 2) * spacing
	local lift = record.art and 0 or 2 * record.scale
	record.model:PivotTo(CFrame.new(x, lift + (def.air and 6 or 0), ORIGIN_Z + row * rowGap))
	if record.billboard then record.billboard.Enabled = false end
	record.model.Parent = room
end
local rows = math.ceil(#ids / perRow)
local width = math.min(#ids, perRow) * spacing
local distance = (math.max(width, 12) * 0.95 + (rows - 1) * 8) * __ZOOM__
local look = Vector3.new(0, 2.5 + rows, ORIGIN_Z + (rows - 1) * rowGap * 0.5)
local eye = look + Vector3.new(distance * math.sin(math.rad(35)), 5 + distance * 0.12, -distance * math.cos(math.rad(35)))
workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, look)
workspace.CurrentCamera.Focus = CFrame.new(look)
print("__MARKER__", #ids)
'''

CLEAN = r'''
local old = workspace:FindFirstChild("DoomShowroom")
if old then old:Destroy() end
print("__MARKER__", 0)
'''


def lua_list(ids: list[str]) -> str:
    return "{" + ", ".join(f'"{i}"' for i in ids) + "}"


def capture(name: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    full = OUT / f"{name}-full.png"
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "tools" / "capture_studio.ps1"),
                    "-OutputPath", str(full.relative_to(ROOT)), "-WindowHandle", str(studio_sync.STUDIO_WINDOW)], cwd=ROOT, check=True, capture_output=True, text=True)
    # Keep only the 3D viewport: Studio's panels are noise for an art review.
    cropped = OUT / f"{name}.png"
    script = f'''
Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Bitmap]::FromFile("{full}")
$left = [int]($image.Width * 0.1435); $top = [int]($image.Height * 0.158)
$width = [int]($image.Width * 0.6070); $height = [int]($image.Height * 0.655)
$rect = New-Object System.Drawing.Rectangle($left, $top, $width, $height)
$part = $image.Clone($rect, $image.PixelFormat)
$image.Dispose()
$part.Save("{cropped}", [System.Drawing.Imaging.ImageFormat]::Png)
$part.Dispose()
'''
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True, capture_output=True, text=True)
    return cropped


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["heroes", "enemies", "bosses", "clean"])
    parser.add_argument("ids", nargs="*")
    parser.add_argument("--per-row", type=int, default=6)
    parser.add_argument("--spacing", type=float, default=9)
    parser.add_argument("--name", default=None)
    parser.add_argument("--keep", action="store_true", help="Leave the showroom in the place after the capture")
    parser.add_argument("--behind", action="store_true", help="look at the figures from behind (capes, packs, wings)")
    parser.add_argument("--zoom", type=float, default=1.0, help="Camera distance factor; smaller is closer")
    parser.add_argument("--window-handle", type=int, default=0, help="Target a specific Studio window")
    args = parser.parse_args()
    studio_sync.STUDIO_WINDOW = args.window_handle
    started = time.time()
    marker = f"DOOM_SHOWROOM_{int(started)}"
    if args.kind == "clean":
        code = CLEAN
    elif args.kind == "heroes":
        code = SETUP + HEROES
    else:
        code = SETUP + ENEMIES.replace("__BOSSES__", "true" if args.kind == "bosses" else "false").replace(
            "__ROWGAP__", "22" if args.kind == "bosses" else "12")
    code = (code.replace("__IDS__", lua_list(args.ids)).replace("__PERROW__", str(args.per_row))
            .replace("__SPACING__", str(args.spacing)).replace("__ZOOM__", str(args.zoom)).replace("__MARKER__", marker)
            .replace("__SIDE__", "1" if args.behind else "-1"))
    studio_sync.run_command(f'print("{marker}_MODE", game:GetService("RunService"):IsEdit())', 900)
    if not studio_sync.wait_for(f"{marker}_MODE", started, 30).endswith("true"):
        raise SystemExit("Studio is in a playtest: press Stop first.")
    studio_sync.run_command(code, 901)
    # Do not accept the earlier <marker>_MODE line as a successful build.
    print(studio_sync.wait_for(marker + " ", started, 120))
    if args.kind == "clean":
        return
    # A one-line command collapses the command bar over the viewport again.
    studio_sync.run_command("--", 903)
    time.sleep(2.5)  # let Studio render the new models
    shot = capture(args.name or (args.kind + ("-" + "-".join(args.ids) if args.ids and len(args.ids) <= 4 else "")))
    print(shot)
    if not args.keep:
        studio_sync.run_command(CLEAN.replace("__MARKER__", marker + "_CLEAN"), 902)
        studio_sync.wait_for(marker + "_CLEAN", started, 60)


if __name__ == "__main__":
    main()
