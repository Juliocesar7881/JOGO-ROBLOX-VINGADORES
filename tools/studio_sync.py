"""Push source files into the place open in Roblox Studio (including a live
Team Create session), through the Studio command bar.

    python tools/studio_sync.py                       # every file under src/
    python tools/studio_sync.py src/server/WorldBuilder.luau src/shared/Catalog.luau
    python tools/studio_sync.py --preview-lobby       # also rebuild the lobby in edit mode

The files in this repository stay the source of truth: this only copies them
into the open place, the same instances tools/build.py would create. Each
file is sent in chunks (the command bar is a single text field), assembled in
_G, then written with ScriptEditorService so collaborative editing sees it.
Studio's output is read back from its log to confirm the write.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRATCH = ROOT / "test-results" / "studio-sync"
CHUNK = 40_000
# Each area's container, created if a collaborator removed it.
CONTAINERS = {
    "shared": '(function() local p=game:GetService("ReplicatedStorage"); local c=p:FindFirstChild("DoomShared"); if not c then c=Instance.new("Folder"); c.Name="DoomShared"; c.Parent=p end; return c end)()',
    "server": '(function() local p=game:GetService("ServerScriptService"); local c=p:FindFirstChild("DoomServer"); if not c then c=Instance.new("Script"); c.Name="DoomServer"; c.Parent=p end; return c end)()',
    "client": '(function() local p=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"); local c=p:FindFirstChild("DoomClient"); if not c then c=Instance.new("LocalScript"); c.Name="DoomClient"; c.Parent=p end; return c end)()',
}


def long_string(text: str) -> str:
    level = 1
    while f"]{'=' * level}]" in text:
        level += 1
    # Lua drops a newline right after the opening bracket. A chunk that starts
    # with one would lose it and glue two lines together ("return 2.4" + "end"
    # became "2.4end"), so always lead with a newline for Lua to drop instead.
    return f"[{'=' * level}[\n{text}]{'=' * level}]"


def target(path: Path) -> tuple[str, str | None, str]:
    """(container expression, child name or None for the container, class)."""
    relative = path.resolve().relative_to(ROOT / "src")
    area = relative.parts[0]
    if area not in CONTAINERS or len(relative.parts) != 2:
        raise SystemExit(f"Not a syncable source file: {path}")
    name = relative.parts[1]
    if name in ("init.server.luau", "init.client.luau"):
        return CONTAINERS[area], None, "Script"
    return CONTAINERS[area], name.removesuffix(".luau"), "ModuleScript"


def studio_log() -> Path | None:
    logs = Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "logs"
    candidates = sorted(logs.glob("*_Studio_*_last.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0] if candidates else None


def run_command(code: str, index: int) -> None:
    SCRATCH.mkdir(parents=True, exist_ok=True)
    script = SCRATCH / f"command-{index:03d}.lua"
    # A key pressed in Studio while the command bar has focus lands in front
    # of the text ("qprint(...)"); a stray letter then only renames this line.
    script.write_text("_ = nil" + chr(10) + code, encoding="utf-8")
    result = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "tools" / "studio_action.ps1"),
         "-Action", "command", "-ScriptPath", str(script)],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("Studio command bar unavailable: " + (result.stderr or result.stdout).strip())
    time.sleep(0.6)


def wait_for(marker: str, since: float, timeout: float = 90) -> str:
    deadline = time.time() + timeout
    while time.time() < deadline:
        log = studio_log()
        # Windows updates an open log's modified time lazily, so the time is
        # not checked; every marker carries its own nonce instead.
        if log:
            for line in reversed(log.read_text(encoding="utf-8", errors="replace").splitlines()[-4000:]):
                if marker in line and "CreatorOutput" in line and "> " not in line.split("CreatorOutput]", 1)[-1][:3]:
                    return line.split("CreatorOutput]", 1)[-1].strip()
        time.sleep(1)
    raise SystemExit(f"Studio never printed {marker}; check the Output window.")


PREVIEW = r'''
-- Edit-mode preview of the lobby: the running server rebuilds DoomLobby at
-- boot (and deletes the editor baseplate), so this is only for looking.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("DoomShared")
local server = game:GetService("ServerScriptService"):WaitForChild("DoomServer")
local function fresh(module) local copy = module:Clone(); return require(copy) end
local catalog = fresh(shared.Catalog)
local world = fresh(server.WorldBuilder).new(catalog, function() end)
local base = workspace:FindFirstChild("EditorBaseplate")
if base then base.Transparency, base.CanCollide = 1, false end
local camera = workspace.CurrentCamera
camera.CFrame = CFrame.lookAt(Vector3.new(0, 230, 150), Vector3.new(0, 0, 350))
local parts = 0
for _, item in ipairs(workspace.DoomLobby:GetDescendants()) do if item:IsA("BasePart") then parts += 1 end end
print("DOOM_PREVIEW_OK", parts)
'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="*")
    parser.add_argument("--preview-lobby", action="store_true")
    args = parser.parse_args()
    files = [Path(f) for f in args.files] or sorted((ROOT / "src").glob("*/*.luau"))
    started = time.time()
    nonce = str(int(started))
    count = 0
    # During a playtest the command bar runs inside the test's client or
    # server copy, which is thrown away on Stop: refuse instead of writing there.
    run_command(f'print("DOOM_SYNC_MODE_{nonce}", game:GetService("RunService"):IsEdit())', count)
    if not wait_for(f"DOOM_SYNC_MODE_{nonce}", started, 30).endswith("true"):
        raise SystemExit("Studio is in a playtest: press Stop, then sync again (nothing was written).")
    run_command("_G.__doomSync = {}", count)
    for path in files:
        container, child, class_name = target(path)
        source = path.read_text(encoding="utf-8-sig")
        key = path.resolve().relative_to(ROOT).as_posix()
        pieces = [source[i:i + CHUNK] for i in range(0, len(source), CHUNK)] or [""]
        for piece in pieces:
            count += 1
            run_command(f'local s=_G.__doomSync; s["{key}"]=s["{key}"] or {{}}; table.insert(s["{key}"], {long_string(piece)})', count)
        count += 1
        run_command(f'''
local key, container, child, className = "{key}", {container}, {(chr(34) + child + chr(34)) if child else "nil"}, "{class_name}"
local source = table.concat(_G.__doomSync[key])
local instance = container
if child then instance = container:FindFirstChild(child) end
if not instance then instance = Instance.new(className); instance.Name = child; instance.Parent = container end
-- Keep the role header tools/build.py prepends to the server script.
local header = string.match(instance.Source, "^(%-%- Place role embedded by tools/build.py\\n[^\\n]*\\n)")
if not header and instance:IsA("Script") and not instance:IsA("LocalScript") then
	header = "-- Place role embedded by tools/build.py\\nworkspace:SetAttribute(\\"DoomRole\\", \\"" .. tostring(workspace:GetAttribute("DoomRole") or "Standalone") .. "\\")\\n"
end
if header then source = header .. source end
local ok = pcall(function()
	game:GetService("ScriptEditorService"):UpdateSourceAsync(instance, function() return source end)
end)
if not ok or instance.Source ~= source then instance.Source = source end
print("DOOM_SYNC_FILE", key, #source, instance.Source == source)
''', count)
        print(f"sent {key} ({len(source):,} chars, {len(pieces)} chunk(s))")
    count += 1
    run_command(f'_G.__doomSync = nil; print("DOOM_SYNC_OK_{nonce}", {len(files)})', count)
    print(wait_for(f"DOOM_SYNC_OK_{nonce}", started))
    # Every file reports whether Studio now holds exactly the repository text.
    lines = studio_log().read_text(encoding="utf-8", errors="replace").splitlines()[-6000:]
    marker = next(i for i in range(len(lines) - 1, -1, -1) if f"DOOM_SYNC_OK_{nonce}" in lines[i] and "] > " not in lines[i])
    reports = [line.split("DOOM_SYNC_FILE", 1)[1].strip() for line in lines[:marker] if "DOOM_SYNC_FILE" in line and "] > " not in line and "print(" not in line]
    written = [r for r in reports[-len(files):] if r.endswith("true")]
    for report in reports[-len(files):]:
        print("  studio:", report)
    if len(written) != len(files):
        raise SystemExit(f"Only {len(written)}/{len(files)} files confirmed in Studio; see its Output window.")
    # Studio's #source counts UTF-8 bytes: a module must arrive byte for byte
    # (scripts carry the role header on top, so they may only be longer).
    expected = {path.resolve().relative_to(ROOT).as_posix(): (len(path.read_text(encoding="utf-8-sig").encode("utf-8")), target(path)[1] is None) for path in files}
    for report in reports[-len(files):]:
        key, size, _ = report.rsplit(" ", 2)
        want, is_script = expected.get(key, (None, False))
        if want is not None and (int(size) < want if is_script else int(size) != want):
            raise SystemExit(f"{key} arrived with {size} bytes, expected {want}: the chunks were not joined intact.")
    if args.preview_lobby:
        count += 1
        run_command(PREVIEW.replace("DOOM_PREVIEW_OK", f"DOOM_PREVIEW_OK_{nonce}"), count)
        print(wait_for(f"DOOM_PREVIEW_OK_{nonce}", started, 120))


if __name__ == "__main__":
    sys.exit(main())
