"""Build the real lobby and every map against Roblox stand-ins.

Run: python tests/test_world_boot.py
The runner writes only an ephemeral file and uses the official Luau CLI.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

TOKENS = {
    "__STUBS__": Path("tests/roblox_stubs.luau"),
    "__CATALOG__": Path("src/shared/Catalog.luau"),
    "__WORLD__": Path("src/server/WorldBuilder.luau"),
    "__MOTION__": Path("src/client/Motion.luau"),
}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--keep", type=Path, help="Write the assembled script here for debugging")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")

    source = (root / "tests" / "world_boot.spec.luau").read_text(encoding="utf-8")
    for token, relative in TOKENS.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function()\n" + body + "\nend)()")

    if args.keep:
        args.keep.write_text(source, encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="doomsday-world-boot-") as temporary:
        script = Path(temporary) / "world.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
