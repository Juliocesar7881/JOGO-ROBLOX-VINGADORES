"""No third-party brand reaches a player.

Every string literal in src/**/*.luau is what a player can end up reading:
Catalog names and descriptions, HUD text, signs and billboards built in the
world, codes. Lowercase internal ids ("ironman", "wakanda") stay: they are
never shown and the saves depend on them. tests/ip_blocklist.json lists the
forbidden names; this fails with every hit and where it is.

Run: python tests/test_ip_safety.py [--report]   (--report never fails)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
STRING = re.compile(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|\[(=*)\[.*?\]\1\]', re.S)
COMMENT = re.compile(r"--\[(=*)\[.*?\]\1\]|--[^\n]*", re.S)


def literals(source: str):
    """(line, text) for every string literal outside comments."""
    position = 0
    out = []
    while position < len(source):
        comment = COMMENT.search(source, position)
        string = STRING.search(source, position)
        if not string:
            break
        if comment and comment.start() < string.start():
            position = comment.end()
            continue
        line = source.count("\n", 0, string.start()) + 1
        out.append((line, string.group(0)))
        position = string.end()
    return out


def hits() -> list[str]:
    terms = json.loads((ROOT / "tests" / "ip_blocklist.json").read_text(encoding="utf-8"))["terms"]
    patterns = [(term, re.compile(r"(?<![\w])" + re.escape(term) + r"(?![\w])")) for term in sorted(set(terms), key=len, reverse=True)]
    found = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        source = path.read_text(encoding="utf-8-sig")
        for line, text in literals(source):
            for term, pattern in patterns:
                if pattern.search(text):
                    found.append(f"{path.relative_to(ROOT).as_posix()}:{line}: {term!r} in {text[:90]}")
                    break
    return found


def main() -> None:
    found = hits()
    if "--report" in sys.argv:
        for entry in found:
            print(entry)
        print(f"{len(found)} hit(s)")
        return
    if found:
        print("\n".join(found[:60]))
        raise SystemExit(f"FAIL ip safety: {len(found)} third-party name(s) a player could read (tests/ip_blocklist.json)")
    print("PASS ip safety: no third-party name in any player-facing string")


if __name__ == "__main__":
    main()
