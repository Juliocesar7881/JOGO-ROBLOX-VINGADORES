"""Marketing screenshots of the real game for the experience's Media tab.

    python tools/store_media.py            # all shots into assets/store/
    python tools/store_media.py lobby fight

Runs tools/studio_review.py scenes in the open Doomsday Studio window, crops the
game view out of each capture (no Studio chrome), cuts it to 16:9 around the
centre and scales it to 1920x1080, which is what Roblox's thumbnails want.
Needs Studio open on the team place with src/client/Review.luau synced.
Nothing is uploaded: the owner picks and uploads the images (RELEASE_CHECKLIST).
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "test-results" / "review"
OUT = ROOT / "assets" / "store"
PLACE = "97132875544830"

# name -> (studio_review scenes, which capture of the run to keep (1-based index))
SHOTS = {
    # The hero star, the plaza and the campaign gate: the first thing a player sees.
    "lobby": (["hideui:on", "lobby"], "lobby"),
    # The reveal of a legendary hero.
    "reveal": (["hidechrome:on", "reveal"], "reveal"),
    # Your squad: heroes with stars and a shiny.
    "heroes": (["hidechrome:on", "squad"], "squad"),
    # The end of a won match, with the MVP.
    "victory": (["hidechrome:on", "results"], "results"),
    # The summon hall.
    "chests": (["hidechrome:on", "chests"], "chests"),
}


def crop_game_view(path: Path, veil: bool = False) -> Image.Image:
    """The game view of a Studio window capture, 16:9 around its centre.

    `veil` shots (modals over the lobby) drop the strip at the top that Roblox's
    own top bar keeps free of our interface."""
    image = Image.open(path).convert("RGB")
    width, height = image.size
    left, top, right, bottom = 16, 223 + (66 if veil else 0), width - 241, height - 146
    view = image.crop((left, top, right, bottom))
    view_w, view_h = view.size
    target_w = min(view_w, round(view_h * 16 / 9))
    x = (view_w - target_w) // 2
    return view.crop((x, 0, x + target_w, view_h)).resize((1920, 1080), Image.LANCZOS)


def newest(pattern_tail: str) -> Path:
    candidates = sorted(REVIEW.glob(f"*-{pattern_tail}.png"), key=lambda item: item.stat().st_mtime)
    if not candidates:
        raise SystemExit(f"No capture named *-{pattern_tail}.png in {REVIEW}")
    return candidates[-1]


def main() -> int:
    wanted = sys.argv[1:] or list(SHOTS)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in wanted:
        scenes, tail = SHOTS[name]
        command = [sys.executable, str(ROOT / "tools" / "studio_review.py"), *scenes, "hideui:off", "hidechrome:off", "--place-id", PLACE]
        subprocess.run(command, cwd=ROOT, check=True)
        crop_game_view(newest(tail), veil=name != "lobby").save(OUT / f"store-{name}.png", optimize=True)
        print("saved", OUT / f"store-{name}.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
