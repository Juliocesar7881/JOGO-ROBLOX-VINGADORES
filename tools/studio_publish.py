"""Publish the open Doomsday place from Studio and confirm it in the Studio log.

Studio 0.743 renamed the item to File > "Publicar" (Alt+P) and its menu popup
is not exposed to UI Automation, so this uses tools/studio_menu.py: one real
click on the "Arquivo" title, one on "Publicar" inside the popup, cursor put
back. The popup's size is checked against the one the offsets were measured
on (361x800, Portuguese Studio, 2026-10-14) so a different layout refuses
instead of clicking something else ("Fechar local" sits in the same menu).

    python tools/studio_publish.py --window-handle <h>

Confirmation is the log line "Go to PublishSuccessful" of PublishSessionStateController:
GetProductInfo's Updated date stays cached for the session and Team Create
saves move it too, so neither proves a publish. Never touches experience
settings, audience, prices, collaborators or terms.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MENU_TITLE = (43, 50)  # "Arquivo" in a capture of the main window
PUBLISH_ITEM = (57, 388)  # "Publicar" inside the popup
POPUP_SIZE = (361, 800)
MARKER = "Go to PublishSuccessful"


def studio_log() -> Path | None:
    logs = Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "logs"
    candidates = sorted(logs.glob("*_Studio_*_last.log"), key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0] if candidates else None


def count_marker(log: Path) -> int:
    return log.read_text(encoding="utf-8", errors="replace").count(MARKER)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--window-handle", type=int, required=True)
    parser.add_argument("--wait", type=int, default=180, help="seconds to wait for the log confirmation")
    args = parser.parse_args()
    log = studio_log()
    if not log:
        print("No Studio log found.")
        return 2
    before = count_marker(log)
    menu = subprocess.run([sys.executable, str(ROOT / "tools" / "studio_menu.py"), "open", "--window-handle", str(args.window_handle), str(MENU_TITLE[0]), str(MENU_TITLE[1])], capture_output=True, text=True)
    print(menu.stdout.strip())
    found = re.search(r"popup (\d+) at \(-?\d+,-?\d+\) size (\d+)x(\d+) class='RobloxStudio'", menu.stdout)
    if not found:
        print("The File menu did not open as a popup; nothing was clicked.")
        return 1
    popup, width, height = int(found.group(1)), int(found.group(2)), int(found.group(3))
    if (width, height) != POPUP_SIZE:
        # Close the menu again with the same title click and refuse.
        subprocess.run([sys.executable, str(ROOT / "tools" / "studio_menu.py"), "pick", "--window-handle", str(args.window_handle), str(MENU_TITLE[0]), str(MENU_TITLE[1])], capture_output=True, text=True)
        print(f"The File menu measures {width}x{height}, not {POPUP_SIZE[0]}x{POPUP_SIZE[1]}: capture it (tools/capture_studio.ps1 -WindowHandle {popup}) and re-measure PUBLISH_ITEM.")
        return 1
    pick = subprocess.run([sys.executable, str(ROOT / "tools" / "studio_menu.py"), "pick", "--window-handle", str(args.window_handle), "--popup", str(popup), str(PUBLISH_ITEM[0]), str(PUBLISH_ITEM[1])], capture_output=True, text=True)
    print(pick.stdout.strip())
    deadline = time.time() + args.wait
    while time.time() < deadline:
        time.sleep(3)
        log = studio_log() or log
        if count_marker(log) > before:
            print(f"PublishSuccessful confirmed in {log.name}")
            return 0
    print("Publish not confirmed in the Studio log within the wait.")
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
