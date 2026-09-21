"""Run meaningful source/logic tests and produce native Roblox place artifacts.

Requires the official Luau CLI in .tools/luau or on PATH. Roblox cloud, renderer,
touch controls and teleport behavior still require Roblox Studio/published tests.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def executable(name: str) -> str:
    for candidate in (ROOT / ".tools" / "luau" / (name + ".exe"), ROOT / ".tools" / "luau" / name):
        if candidate.is_file():
            return str(candidate)
    path = shutil.which(name)
    if not path:
        raise SystemExit(f"Missing official {name} CLI. Run python tools/setup_luau.py first.")
    return path


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-build", action="store_true", help="Only compile and run logic tests while bootstraps are being written")
    options = parser.parse_args()
    source_files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "src").rglob("*.luau"))
    run([executable("luau-compile"), "--null", *source_files])
    run([executable("luau"), "tools/test_rules.luau"])
    # Ordered cheapest-first, so a broken module reports before a full
    # campaign simulation spends a minute finding out the same thing.
    for suite in (
        "test_ui_layout.py",
        "test_player_service.py",
        "test_party_service.py",
        "test_elevator.py",
        "test_contract.py",
        "test_world_boot.py",
        "test_client_boot.py",
        "test_server_boot.py",
        "test_match_simulation.py",
    ):
        path = ROOT / "tests" / suite
        if path.is_file():
            run([sys.executable, str(path)])
    if not options.no_build:
        run([sys.executable, "tools/test_build.py"])
        run([sys.executable, "tools/build.py"])
    print("PASS automated checks. Studio, multiplayer/cloud and device playtests are separate acceptance gates.")


if __name__ == "__main__":
    main()
