"""Execute the real PlayerService under deterministic Roblox service doubles.

Run: python tests/test_player_service.py
The runner writes only an ephemeral file and uses the official Luau CLI.
These tests do not replace published-place integration tests.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

# Inside Roblox, Rules finds Catalog through `script`. Here it is simply the
# module declared just above it in the assembled test, so the require becomes a
# plain reference to that local.
CATALOG_REQUIRE = 'require(if script then script.Parent.Catalog else "./Catalog")'


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")
    source = (root / "tests" / "player_service.spec.luau").read_text(encoding="utf-8")
    for token, path in {
        "__CATALOG__": root / "src" / "shared" / "Catalog.luau",
        "__RULES__": root / "src" / "shared" / "Rules.luau",
        "__SERVICE__": root / "src" / "server" / "PlayerService.luau",
        "__RARITY_BASELINE__": root / "tests" / "rarity_baseline.luau",
    }.items():
        body = path.read_text(encoding="utf-8").replace(CATALOG_REQUIRE, "Catalog")
        source = source.replace(token, "(function()\n" + body + "\nend)()")
    with tempfile.TemporaryDirectory(prefix="doomsday-profile-tests-") as temporary:
        script = Path(temporary) / "test.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
