"""Downscale authored HUD textures for Roblox; never redraw their contents.

Original imagegen PNGs remain alongside these delivery files. Atlas dimensions
are deliberately divisible by their grid so runtime crops use integer pixels.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets/ui/illustrated"
SIZES = {"window": (1024, 683), "button": (1024, 341), "icons": (1024, 1024),
         "observatory": (1024, 683), "chests": (1023, 682), "card": (1024, 1024),
         "launch_refuge_v3": (1024, 576), "afk_refuge_v3": (1024, 576)}

def main():
    destination = ROOT / "roblox"
    destination.mkdir(exist_ok=True)
    for name, size in SIZES.items():
        with Image.open(ROOT / f"{name}.png") as source:
            source.resize(size, Image.Resampling.LANCZOS).save(destination / f"md_{name}.png")
        print(f"{name}: {size[0]}x{size[1]}")

if __name__ == "__main__":
    main()
