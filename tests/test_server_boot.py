"""Boot the real server bootstrap and play sessions through its router.

Run: python tests/test_server_boot.py
init.server wires every service together and wraps each request in pcall, so
a runtime bug there turns requests into silent "internal error" answers. This
runs it as a Standalone Studio server on a simulated clock, plays a tutorial,
a duo with a reconnect, probes the router's limits and shuts it down.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

IMMEDIATE = {"__STUBS__": "tests/roblox_stubs.luau"}
LOADERS = {
    "__CATALOG__": "src/shared/Catalog.luau",
    "__CONFIG__": "src/shared/Config.luau",
    "__RULES__": "src/shared/Rules.luau",
    "__WAVES__": "src/shared/Waves.luau",
    "__PLAYERS__": "src/server/PlayerService.luau",
    "__WORLD__": "src/server/WorldBuilder.luau",
    "__MATCH__": "src/server/MatchService.luau",
    "__PARTY__": "src/server/PartyService.luau",
    "__PRESENCE__": "src/server/PresenceService.luau",
    "__ANALYTICS__": "src/server/AnalyticsService.luau",
    "__REJOIN__": "src/server/RejoinService.luau",
    "__ELEVATOR__": "src/server/ElevatorService.luau",
    "__CODES__": "src/server/Codes.luau",
    "__SERVER__": "src/server/init.server.luau",
}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--keep", type=Path, help="Write the assembled script here for debugging")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")

    source = (root / "tests" / "server_boot.spec.luau").read_text(encoding="utf-8")
    for token, relative in IMMEDIATE.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function()\n" + body + "\nend)()")
    # Every module becomes a loader taking its own `script`, exactly the way
    # Roblox gives each ModuleScript a script global pointing at itself.
    for token, relative in LOADERS.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        # Each module also receives a test-controlled `os`, so throttles built
        # on os.clock() see simulated frames advance simulated time.
        source = source.replace(token, "(function(script, os)\n" + body + "\nend)")

    if args.keep:
        args.keep.write_text(source, encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="doomsday-server-boot-") as temporary:
        script = Path(temporary) / "server.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
