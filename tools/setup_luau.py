"""Download the pinned official Luau release and verify GitHub's SHA256 digest."""
from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import platform
from urllib.request import Request, urlopen
import zipfile

VERSION = "0.739"
ROOT = Path(__file__).resolve().parents[1]


def download(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "Doomsday-build-tools/1.0"})
    with urlopen(request, timeout=90) as response:
        return response.read()


def main() -> None:
    operating_system = platform.system()
    filename = {"Windows": "luau-windows.zip", "Linux": "luau-ubuntu.zip", "Darwin": "luau-macos.zip"}.get(operating_system)
    if filename is None:
        raise SystemExit(f"Unsupported operating system: {operating_system}")
    release = json.loads(download(f"https://api.github.com/repos/luau-lang/luau/releases/tags/{VERSION}"))
    asset = next(item for item in release["assets"] if item["name"] == filename)
    url = asset["browser_download_url"]
    if not url.startswith(f"https://github.com/luau-lang/luau/releases/download/{VERSION}/"):
        raise SystemExit("Unexpected asset origin")
    archive = download(url)
    digest = "sha256:" + hashlib.sha256(archive).hexdigest()
    if digest != asset.get("digest"):
        raise SystemExit("Official release SHA256 verification failed")
    destination = ROOT / ".tools" / "luau"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(archive)) as package:
        for entry in package.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise SystemExit("Unsafe archive path")
        package.extractall(destination)
    if operating_system != "Windows":
        for path in destination.iterdir():
            if path.is_file():
                path.chmod(path.stat().st_mode | 0o111)
    (destination / "provenance.json").write_text(json.dumps({"version": VERSION, "source": url, "digest": digest}, indent=2) + "\n", encoding="utf-8")
    print(f"Installed official Luau {VERSION}; verified {digest}")


if __name__ == "__main__":
    main()
