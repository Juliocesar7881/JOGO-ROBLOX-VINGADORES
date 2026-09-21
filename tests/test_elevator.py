"""Execute the real ElevatorService (the mode portals) with the Luau CLI.

Run: python tests/test_elevator.py
Starting a match is walking onto a portal pad. Who may board, who is set
back outside, full cars, leavers, disconnects and failed launches are all
decided by ElevatorService, and no UI suite can see any of it.
"""
from pathlib import Path
import argparse
import subprocess


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")
    result = subprocess.run([str(args.luau), "tests/elevator.spec.luau"], cwd=root, check=False)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
