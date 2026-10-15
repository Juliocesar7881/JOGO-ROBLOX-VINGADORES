"""Technical export only: preserve originals; resize/compress Roblox store uploads."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageOps

base = Path(__file__).resolve().parent
source_manifest = json.loads((base / "prompts.json").read_text(encoding="utf-8"))
exports = []
for item in source_manifest["assets"]:
    original = base / "originais" / (item["id"] + ".png")
    # The preserved originals make this bundle portable between teammates.
    # Generator output paths are useful provenance, but may be temporary.
    src = original if original.is_file() else Path(item["source"])
    if not src.is_file():
        raise SystemExit(f"Missing original image: {original}")
    original.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != original.resolve():
        shutil.copy2(src, original)
    target = base / ("icone.png" if item["id"] == "icone" else item["id"] + ".jpg")
    with Image.open(src) as image:
        original_size = list(image.size)
        size = (512, 512) if item["id"] == "icone" else (1920, 1080)
        final = ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)
        if item["id"] == "icone":
            final.save(target, optimize=True)
        else:
            final.save(target, quality=94, subsampling=0, optimize=True)
        assert target.stat().st_size < 3 * 1024 * 1024
        exports.append({"id": item["id"], "file": target.name, "size": list(size), "bytes": target.stat().st_size, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "original": original.relative_to(base).as_posix(), "original_size": original_size, "original_sha256": hashlib.sha256(original.read_bytes()).hexdigest(), "notes": "AI promotional illustration guided by actual project screenshots; not a gameplay screenshot."})
(base / "manifest.json").write_text(json.dumps({"date": "2026-10-15", "generator": "built-in image_gen", "exports": exports}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(exports, ensure_ascii=False, indent=2))
