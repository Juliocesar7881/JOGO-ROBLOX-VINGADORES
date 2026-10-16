"""Publish the open Doomsday place from Studio and confirm it in the Studio log.

Studio 0.743 renamed the item to File > "Publicar" (Alt+P) and its menu popup
is not exposed to UI Automation, so this uses tools/studio_menu.py: one real
click on the "Arquivo" title, one on "Publicar" inside the popup, cursor put
back. The popup's size is checked against the ones the offsets were measured
on (361x800 on 2026-10-14 and 380x800 on 2026-10-16, Portuguese Studio: the
menu only grew wider, every item kept its height) so a different layout
refuses instead of clicking something else ("Fechar local" sits in the same
menu).

    python tools/studio_publish.py --window-handle <h> [--place-id <id>]

Confirmation is Studio's own line "Publish succeeded for placeId <id>"
(PublishSessionStateController's "Go to PublishSuccessful" step), counted
across every recent Studio log: another Studio running at the same time (a
headless RunScript job, another place) writes a newer log of its own, so the
newest file proves nothing. GetProductInfo's Updated date stays cached for the
session and Team Create saves move it too, so neither proves a publish either.
Never touches experience settings, audience, prices, collaborators or terms.
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
POPUP_SIZES = {(361, 800), (380, 800)}
PLACE_ID = 97132875544830


def studio_logs() -> list[Path]:
    logs = Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "logs"
    recent = time.time() - 12 * 3600
    return [p for p in logs.glob("*_Studio_*_last.log") if p.stat().st_mtime >= recent]


def count_marker(place_id: int) -> int:
    """How many publishes of this place every recent Studio log records."""
    marker = f"Publish succeeded for placeId {place_id}"
    return sum(log.read_text(encoding="utf-8", errors="replace").count(marker) for log in studio_logs())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--window-handle", type=int, required=True)
    parser.add_argument("--wait", type=int, default=180, help="seconds to wait for the log confirmation")
    parser.add_argument("--place-id", type=int, default=PLACE_ID, help="the place whose publish confirms success")
    args = parser.parse_args()
    if not studio_logs():
        print("No Studio log found.")
        return 2
    before = count_marker(args.place_id)
    # The first click on a busy Studio sometimes only takes focus: try twice.
    found = None
    for _ in range(2):
        menu = subprocess.run([sys.executable, str(ROOT / "tools" / "studio_menu.py"), "open", "--window-handle", str(args.window_handle), str(MENU_TITLE[0]), str(MENU_TITLE[1])], capture_output=True, text=True)
        print(menu.stdout.strip())
        found = re.search(r"popup (\d+) at \(-?\d+,-?\d+\) size (\d+)x(\d+) class='RobloxStudio'", menu.stdout)
        if found:
            break
        time.sleep(0.8)
    if not found:
        print("The File menu did not open as a popup; nothing was clicked.")
        return 1
    popup, width, height = int(found.group(1)), int(found.group(2)), int(found.group(3))
    if (width, height) not in POPUP_SIZES:
        # Close the menu again with the same title click and refuse.
        subprocess.run([sys.executable, str(ROOT / "tools" / "studio_menu.py"), "pick", "--window-handle", str(args.window_handle), str(MENU_TITLE[0]), str(MENU_TITLE[1])], capture_output=True, text=True)
        known = ", ".join(f"{w}x{h}" for w, h in sorted(POPUP_SIZES))
        print(f"The File menu measures {width}x{height}, not one of {known}: capture it (tools/capture_studio.ps1 -WindowHandle {popup}) and re-measure PUBLISH_ITEM.")
        return 1
    pick = subprocess.run([sys.executable, str(ROOT / "tools" / "studio_menu.py"), "pick", "--window-handle", str(args.window_handle), "--popup", str(popup), str(PUBLISH_ITEM[0]), str(PUBLISH_ITEM[1])], capture_output=True, text=True)
    print(pick.stdout.strip())
    deadline = time.time() + args.wait
    while time.time() < deadline:
        time.sleep(3)
        if count_marker(args.place_id) > before:
            print(f"PublishSuccessful confirmed for place {args.place_id}")
            return 0
    print("Publish not confirmed in the Studio log within the wait.")
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
