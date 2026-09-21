"""Check the lobby top bar's geometry at real device widths.

Run: python tests/test_ui_layout.py
This does not prove the bar looks good; it proves the rectangles do not
overlap or go negative, which is the class of bug that mixing scale-based
positions with fixed-width buttons actually produces.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

TOKENS = {
    "__STUBS__": Path("tests/roblox_stubs.luau"),
    "__UI__": Path("src/client/UI.luau"),
}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--keep", type=Path, help="Write the assembled script here for debugging")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")

    source = (root / "tests" / "ui_layout.spec.luau").read_text(encoding="utf-8")
    for token, relative in TOKENS.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function()\n" + body + "\nend)()")

    if args.keep:
        args.keep.write_text(source, encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="doomsday-ui-layout-") as temporary:
        script = Path(temporary) / "layout.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
