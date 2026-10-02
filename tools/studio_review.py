"""Look at the game in Studio without editing any script in the place.

    python tools/studio_review.py lobby squad chests wave results
    python tools/studio_review.py --phone hero tower
    python tools/studio_review.py "server:start manhattan normal" live "server:spawn lizard" live
    python tools/studio_review.py --keep-playing reveal

Presses Play on the open Doomsday window, waits for src/client/Review.luau
(Studio-only), shows each scene through attributes set from the command bar,
captures the window with PrintWindow and presses Stop. Scenes:

    <stage>            a fixture screen (see Review.STAGES); nothing reaches the server
    live               the real game as the server sends it
    server:<command>   a Studio-only server scene: start <map> [mode] | give a,b,c (field these heroes) | spawn a,b |
                       crowd <n> | endwave [wave] | finish true|false | panel <name>
    wait:<seconds>     let the real game run before the next capture
    focus:tower        camera on the first tower (focus: alone resets it)
    focus:cam:x,y,z,tx,ty,tz   camera at (x,y,z) looking at (tx,ty,tz), e.g. in the lobby
    hideui:on|off      hide (or show) the game's own interface, for clean marketing shots
    hidechrome:on|off  hide only Roblox's own buttons and chat

Captures land in test-results/review/<index>-<scene>.png (and -phone.png with
--phone, drawn in a 667x375 area). A capture that is almost all one colour
means the window was not drawable; it is retried once and then reported.
The window is restored without activation and kept behind other windows, so
the owner's mouse and focus are never touched.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import studio_sync  # noqa: E402

TEAM_PLACE = 97132875544830
OUT = ROOT / "test-results" / "review"
PHONE = "667x375"

PREPARE = r'''
param([long]$Handle)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ReviewWindow {
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
$h = [IntPtr]$Handle
if ([ReviewWindow]::IsIconic($h)) {
  # SW_SHOWNOACTIVATE, then to the bottom of the z-order without activation.
  [ReviewWindow]::ShowWindow($h, 4) | Out-Null
  [ReviewWindow]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x13) | Out-Null
  Start-Sleep -Milliseconds 800
}
'''


def powershell(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", *args], cwd=ROOT, capture_output=True, text=True, check=check)


def find_window() -> int:
    result = powershell("-Command", "Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*Doomsday*' } | "
                        "ForEach-Object { $_.MainWindowHandle }")
    handles = [int(line) for line in result.stdout.split() if line.strip().isdigit() and int(line) != 0]
    if not handles:
        raise SystemExit("The Doomsday place is not open in Studio (see the skill's STUDIO.md to open it).")
    return handles[0]


def prepare(handle: int) -> None:
    script = ROOT / "test-results" / "studio-sync" / "prepare-window.ps1"
    script.parent.mkdir(parents=True, exist_ok=True)
    script.write_text(PREPARE, encoding="utf-8")
    powershell("-File", str(script), "-Handle", str(handle), check=False)


def command(code: str, marker: str, timeout: float = 40) -> str:
    for attempt in range(3):
        started = time.time()
        tag = f"{marker}_{attempt}"
        studio_sync.run_command(f'{code}\nprint("{tag}")', 900)
        try:
            return studio_sync.wait_for(tag, started, timeout if attempt == 2 else 20)
        except SystemExit:
            time.sleep(2)
    raise SystemExit(f"Studio did not run {marker}")


def query(expression: str, timeout: float = 30) -> str:
    # A command typed while Studio switches between Play and edit can be
    # dropped; ask again once before giving up.
    for attempt in range(3):
        marker = f"DOOM_Q_{int(time.time() * 1000)}"
        started = time.time()
        studio_sync.run_command(f'print("{marker}", {expression})', 901)
        try:
            return studio_sync.wait_for(marker, started, timeout if attempt == 2 else 12).split(marker, 1)[-1].strip()
        except SystemExit:
            time.sleep(3)
    raise SystemExit(f"Studio did not answer {expression}")


def log_offset() -> dict[Path, int]:
    return {log: log.stat().st_size for log in studio_sync.studio_logs()}


def wait_in_log(origin: dict[Path, int], needle: str, timeout: float) -> bool:
    """True once needle is printed in any Studio log after origin (sizes then)."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        for log in studio_sync.studio_logs():
            with open(log, "rb") as handle:
                handle.seek(origin.get(log, 0))
                fresh = handle.read().decode("utf-8", errors="replace")
            if any(needle in line and "print(" not in line for line in fresh.splitlines()):
                return True
        time.sleep(1.5)
    return False


def capture(handle: int, name: str) -> Path:
    path = OUT / f"{name}.png"
    for attempt in range(2):
        prepare(handle)
        powershell("-File", str(ROOT / "tools" / "capture_studio.ps1"), "-OutputPath", str(path.relative_to(ROOT)), "-WindowHandle", str(handle))
        if drawable(path):
            glare_report(path)
            return path
        time.sleep(2)
    print(f"  WARNING {path.name} looks blank: the Studio window was not drawable")
    return path


def glare_report(path: Path, limit: float = 0.06) -> float | None:
    """Print a warning when too much of the game view is blown out to white.

    The owner's standing complaint is "brilho estourado": neon and bloom that
    turn flat white. Pixels that are near-white (every channel above 215, one above 240) inside the game view
    (no Studio chrome) count; above `limit` of the view the capture is flagged.
    Interface panels count too, but a modal's text and borders stay far below.
    """
    try:
        from PIL import Image
    except ImportError:
        return None
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        width, height = rgb.size
        view = rgb.crop((16, 223, max(17, width - 241), max(224, height - 146))).resize((320, 180))
        pixels = list(view.getdata())
    blown = sum(1 for r, g, b in pixels if min(r, g, b) > 215 and max(r, g, b) > 240) / len(pixels)
    if blown > limit:
        print(f"  GLARE {path.name}: {blown:.0%} of the view is blown out to white (limit {limit:.0%})")
    return blown


def drawable(path: Path) -> bool:
    try:
        from PIL import Image, ImageStat
    except ImportError:
        return True
    with Image.open(path) as image:
        if image.width < 400 or image.height < 300:
            return False
        stat = ImageStat.Stat(image.convert("L").resize((160, 90)))
        return stat.stddev[0] > 6


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scenes", nargs="+")
    parser.add_argument("--phone", action="store_true", help="also capture each fixture scene in a 667x375 area")
    parser.add_argument("--language", choices=("pt", "en"), default="pt")
    parser.add_argument("--window-handle", type=int, default=0)
    parser.add_argument("--keep-playing", action="store_true", help="leave the playtest running at the end")
    parser.add_argument("--place-id", type=int, default=TEAM_PLACE)
    args = parser.parse_args()
    handle = args.window_handle or find_window()
    review_origin = log_offset()
    studio_sync.STUDIO_WINDOW = handle
    prepare(handle)
    OUT.mkdir(parents=True, exist_ok=True)

    if query('game:GetService("RunService"):IsEdit()').endswith("true"):
        place = query("game.PlaceId").split()[-1]
        if place != str(args.place_id):
            raise SystemExit(f"Wrong place open: {place}, expected {args.place_id}.")
        origin = log_offset()
        powershell("-File", str(ROOT / "tools" / "studio_action.ps1"), "-Action", "play", "-WindowHandle", str(handle))
        if not wait_in_log(origin, "DOOM_REVIEW_READY", 120):
            raise SystemExit("Play started but Review.luau never reported ready (is src/client/Review.luau synced?).")
        time.sleep(4)
    player = 'game:GetService("Players").LocalPlayer'
    command(f'{player}:SetAttribute("DoomReviewLanguage", "{args.language}")', f"DOOM_LANG_{int(time.time())}")
    shots: list[Path] = []
    try:
        for index, scene in enumerate(args.scenes, 1):
            label = re.sub(r"[^a-z0-9]+", "-", scene.lower()).strip("-")
            if scene.startswith("focus:"):
                command(f'{player}:SetAttribute("DoomReviewFocus", "{scene[6:]}")', f"DOOM_FOCUS_{int(time.time())}_{index}")
                continue
            if scene.startswith("wait:"):
                time.sleep(float(scene[5:]))
                continue
            if scene.startswith("hidechrome:"):
                command(f'{player}:SetAttribute("DoomReviewHideChrome", {"true" if scene[11:] == "on" else "false"})', f"DOOM_HIDECHROME_{int(time.time())}_{index}")
                continue
            if scene.startswith("hideui:"):
                command(f'{player}:SetAttribute("DoomReviewHideUI", {"true" if scene[7:] == "on" else "false"})', f"DOOM_HIDEUI_{int(time.time())}_{index}")
                continue
            if scene.startswith("server:"):
                line = scene[7:].replace('"', "")
                command(f'{player}:SetAttribute("DoomReviewServer", "") task.wait() {player}:SetAttribute("DoomReviewServer", "{line}") task.wait(0.4)',
                        f"DOOM_SERVER_{int(time.time())}_{index}", 60)
                continue
            sizes = [""] + ([PHONE] if args.phone and scene != "live" else [])
            for size in sizes:
                command(f'{player}:SetAttribute("DoomReviewSize", "{size}") {player}:SetAttribute("DoomReview", nil) task.wait() '
                        f'{player}:SetAttribute("DoomReview", "{scene}") task.wait(1.6)', f"DOOM_SCENE_{int(time.time())}_{index}", 60)
                shot = capture(handle, f"{index:02d}-{label}" + ("-phone" if size else ""))
                shots.append(shot)
                print(shot)
        command(f'{player}:SetAttribute("DoomReviewSize", "") {player}:SetAttribute("DoomReview", "live")', f"DOOM_LIVE_{int(time.time())}")
    finally:
        if not args.keep_playing:
            powershell("-File", str(ROOT / "tools" / "studio_action.ps1"), "-Action", "stop", "-WindowHandle", str(handle), check=False)
            for _ in range(15):
                time.sleep(2)
                try:
                    if query('game:GetService("RunService"):IsEdit()', 10).endswith("true"):
                        break
                except SystemExit:
                    pass
    errors = scan_errors(review_origin)
    if errors:
        print("Script errors during the review:")
        for line in errors[-20:]:
            print("  " + line)
    overflow = scan_overflow(review_origin)
    if overflow:
        print("Text overflow reported by Review.luau:")
        for line in overflow[-20:]:
            print("  " + line)
    return 0


def scan_errors(origin: dict[Path, int]) -> list[str]:
    """Lua errors from the game's own scripts printed since the review began."""
    found = []
    for log in studio_sync.studio_logs():
        with open(log, "rb") as handle:
            handle.seek(origin.get(log, 0))
            lines = handle.read().decode("utf-8", errors="replace").splitlines()
        for line in lines:
            if "DOOM_REVIEW_ERROR" in line or ("Error" in line and ("DoomClient" in line or "DoomServer" in line or "DoomShared" in line)):
                found.append(line.split("]", 3)[-1].strip()[:240])
    return found


def scan_overflow(origin: dict[Path, int]) -> list[str]:
    found = []
    for log in studio_sync.studio_logs():
        with open(log, "rb") as handle:
            handle.seek(origin.get(log, 0))
            lines = handle.read().decode("utf-8", errors="replace").splitlines()
        found += [line.split("DOOM_REVIEW_OVERFLOW", 1)[1].strip() for line in lines if "DOOM_REVIEW_OVERFLOW" in line and "print(" not in line]
    return found


if __name__ == "__main__":
    sys.exit(main())
