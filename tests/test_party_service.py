"""Execute the real PartyService against Roblox stand-ins.

Run: python tests/test_party_service.py
Party codes are read aloud and retyped by players, and a code that outlives
its party could pull a stranger into someone else's reserved match. None of
that is reachable from the other suites, which never form a group.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--keep", type=Path, help="Write the assembled script here for debugging")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")

    source = (root / "tests" / "party_service.spec.luau").read_text(encoding="utf-8")
    service = (root / "src" / "server" / "PartyService.luau").read_text(encoding="utf-8-sig")
    source = source.replace("__SERVICE__", "(function()\n" + service + "\nend)()")

    if args.keep:
        args.keep.write_text(source, encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="doomsday-party-tests-") as temporary:
        script = Path(temporary) / "party.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
