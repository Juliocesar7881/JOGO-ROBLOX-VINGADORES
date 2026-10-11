"""Check the shipped raster originals/delivery files and Roblox atlas contract."""
import hashlib
import json
from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/ui/illustrated"


def main():
    manifest = json.loads((ART / "manifest.json").read_text(encoding="utf-8"))
    config = (ROOT / "src/shared/Config.luau").read_text(encoding="utf-8")
    ids = dict(re.findall(r"(\w+)=(\d+)", config.split("UiArt = {", 1)[1].split("}", 1)[0]))
    assert set(ids) == set(manifest["assets"])
    for name, asset in manifest["assets"].items():
        assert int(ids[name]) == asset["roblox_id"] > 0, name
        for key in ("source", "delivery"):
            file = ART / asset[key]["file"]
            assert hashlib.sha256(file.read_bytes()).hexdigest() == asset[key]["sha256"], file
            with Image.open(file) as image:
                assert list(image.size) == asset[key]["size"], file
        with Image.open(ART / asset["delivery"]["file"]) as image:
            assert max(image.size) <= 1024, name
            if name in ("icons", "chests", "button"):
                assert image.mode == "RGBA", name
                alpha = image.getchannel("A")
                assert alpha.getextrema() == (0, 255), name
            if "grid" in asset:
                columns, rows = asset["grid"]
                assert image.width % columns == image.height % rows == 0
                w, h = image.width // columns, image.height // rows
                for row in range(rows):
                    for column in range(columns):
                        tile = image.crop((column*w, row*h, (column+1)*w, (row+1)*h))
                        assert tile.getchannel("A").getextrema() == (0, 255), (name, row, column)
    print("PASS illustrated HUD: six shipped textures, original hashes, alpha, IDs and 22 atlas cells")


if __name__ == "__main__":
    main()
