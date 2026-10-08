"""Boot the real client against Roblox stand-ins and drive every screen.

Run: python tests/test_client_boot.py
The client used to be compiled but never executed by any test. This inlines
init.client and its modules, feeds it lobby, match and results snapshots on
several real screen sizes, presses its buttons and fires every FX event it
handles. Any Lua error fails the run.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile
import os
import time
from concurrent.futures import ThreadPoolExecutor

IMMEDIATE = {"__STUBS__": "tests/roblox_stubs.luau"}
LOADERS = {
    "__CATALOG__": "src/shared/Catalog.luau",
    "__CONFIG__": "src/shared/Config.luau",
    "__RULES__": "src/shared/Rules.luau",
    "__UI__": "src/client/UI.luau",
    "__WORLD__": "src/server/WorldBuilder.luau",
    "__CLIENT__": "src/client/init.client.luau",
}


def loader(body: str) -> str:
    return "(function(script, os)\n" + body + "\nend)"


def client_modules(root: Path) -> str:
    """Every ModuleScript under src/client, so a newly split module is booted
    without anyone remembering to list it here."""
    entries = []
    for path in sorted((root / "src" / "client").glob("*.luau")):
        if path.name.startswith("init."):
            continue
        body = path.read_text(encoding="utf-8-sig")
        entries.append(f'\t["{path.stem}"] = {loader(body)},')
    return "{\n" + "\n".join(entries) + "\n}"


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--keep", type=Path, help="Write the assembled script here for debugging")
    parser.add_argument("--workers", type=int, default=min(6, os.cpu_count() or 2), help="Independent screen processes (all six screens always run)")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")

    source = (root / "tests" / "client_boot.spec.luau").read_text(encoding="utf-8")
    for token, relative in IMMEDIATE.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function()\n" + body + "\nend)()")
    # Every module becomes a loader taking its own `script`, exactly the way
    # Roblox gives each ModuleScript a script global pointing at itself.
    # Each module also receives a test-controlled `os`, so throttles built
    # on os.clock() see simulated frames advance simulated time.
    source = source.replace("__CLIENT_MODULES__", client_modules(root))
    for token, relative in LOADERS.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, loader(body))

    if args.keep:
        args.keep.write_text(source.replace("__SCREEN_FILTER__", "0"), encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="doomsday-client-boot-") as temporary:
        scripts = []
        for index in range(1, 7):
            script = Path(temporary) / f"client-{index}.luau"
            script.write_text(source.replace("__SCREEN_FILTER__", str(index)), encoding="utf-8")
            scripts.append(script)
        started = time.monotonic()
        def run(script: Path):
            return subprocess.run([str(args.luau), str(script)], cwd=root, check=False, capture_output=True, encoding="utf-8", errors="replace")
        # Each Luau process has its own clock, services and GUI. The complete
        # gameplay and layout script still runs at EVERY original screen size.
        with ThreadPoolExecutor(max_workers=max(1, min(6, args.workers))) as pool:
            results = list(pool.map(run, scripts))
        for result in results:
            print(result.stdout, end="")
            if result.stderr:
                print(result.stderr, end="")
        print(f"Client boot: six complete screen runs in {time.monotonic() - started:.1f}s")
        raise SystemExit(next((result.returncode for result in results if result.returncode), 0))


if __name__ == "__main__":
    main()
