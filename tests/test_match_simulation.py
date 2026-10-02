"""Play a full match against the real MatchService, outside Roblox.

Run: python tests/test_match_simulation.py
The runner writes only an ephemeral file and uses the official Luau CLI.
Rendering, input and published-place behaviour remain separate acceptance gates.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

# Rules and Waves resolve their siblings through `script`, which does not exist
# outside Roblox. Rewriting the require to the bare name turns the statement into
# `local Catalog = Catalog`, whose right-hand side binds to the module the spec
# already declared above it. The Luau CLI freezes _G, so upvalues are the way in.
REWRITES = {
    "Rules.luau": [
        ('require(if script then script.Parent.Catalog else "./Catalog")', "Catalog"),
    ],
    "Waves.luau": [
        ('require(if script then script.Parent.Catalog else "./Catalog")', "Catalog"),
        ('require(if script then script.Parent.Rules else "./Rules")', "Rules"),
    ],
}

TOKENS = {
    "__CONFIG__": Path("src/shared/Config.luau"),
    "__CATALOG__": Path("src/shared/Catalog.luau"),
    "__RULES__": Path("src/shared/Rules.luau"),
    "__WAVES__": Path("src/shared/Waves.luau"),
    "__MATCH__": Path("src/server/MatchService.luau"),
}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--sweep", nargs="?", const="rosters", choices=["rosters", "heroes", "duel"],
                        help="Print a balance table (three rosters across every map and mode, or every hero on its own) instead of running the checks")
    parser.add_argument("--roster", help="With --sweep rosters: run only the roster with this name (e.g. lenda)")
    parser.add_argument("--hero", help="With --sweep heroes: run only these heroes (comma separated ids, e.g. panther,capmen,ironman)")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")

    source = (root / "tests" / "match_simulation.spec.luau").read_text(encoding="utf-8")
    for token, relative in TOKENS.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        for old, new in REWRITES.get(relative.name, []):
            if old not in body:
                raise SystemExit(f"{relative.name}: expected require pattern not found: {old}")
            body = body.replace(old, new)
        source = source.replace(token, "(function()\n" + body + "\nend)()")

    if args.sweep:
        # Everything above the playthroughs is the harness: stubs, the bot and
        # simulate(). The sweep reuses it and swaps the checks for a table.
        name = {"heroes": "hero_sweep.luau", "duel": "duel_sweep.luau"}.get(args.sweep, "balance_sweep.luau")
        only = ('ONLY_ROSTER = "' + args.roster + '"' if args.roster else 'ONLY_ROSTER = nil') + chr(10)
        only += ('ONLY_HEROES = {' + ', '.join('"' + h + '"' for h in args.hero.split(',')) + '}' if args.hero else 'ONLY_HEROES = nil') + chr(10)
        source = source[:source.index('print("--- tutorial ---")')] + only + (root / "tests" / name).read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="doomsday-match-sim-") as temporary:
        script = Path(temporary) / "simulation.luau"
        script.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
