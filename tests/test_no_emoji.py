"""No emoji reaches a player.

Emoji look different on every device and read as unfinished next to a drawn
interface. Icons are drawn (UI.icon, UI.illustration, Kit.emblem), and the
typographic symbols the fonts carry (stars, check marks, bullets, arrows) stay.
This scans every string literal in src/**/*.luau and fails with each emoji and
where it is.

Run: python tests/test_no_emoji.py
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from test_ip_safety import literals  # noqa: E402

# Pictographs and the dingbats that browsers and Roblox draw as colour emoji.
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u231a-\u231b\u23e9-\u23f3\u23f8-\u23fa\u2600-\u2604\u2614-\u2615\u2618-\u2625\u2628-\u2629\u262A-\u2653\u2660-\u2668"
                   "\u267B-\u267F\u2692-\u2699\u269B-\u26A0\u26A1\u26AA-\u26AB\u26B0-\u26BD\u26C4-\u26C5\u26CE-\u26CF"
                   "\u26D1-\u26D4\u26E9-\u26EA\u26F0-\u26FA\u26FD\u2702-\u2705\u2708-\u270D\u270F\u2712\u2714\u2716"
                   "\u271D\u2721\u2728\u2733-\u2734\u2744\u2747\u274C\u274E\u2753-\u2755\u2757\u2763-\u2764\u2795-\u2797"
                   "\u27A1\u27B0\u27BF\u2934-\u2935\u2B05-\u2B07\u2B1B-\u2B1C\u2B50\u2B55\u3030\u303D\u3297\u3299\uFE0F]")


def main() -> int:
    hits = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        source = path.read_text(encoding="utf-8")
        for line, text in literals(source):
            for match in EMOJI.finditer(text):
                hits.append(f"{path.relative_to(ROOT)}:{line}: U+{ord(match.group(0)):04X} in {text[:70]!r}")
    # Luau escapes (\u{1F4B0}, \xNN) can hide one from the scan above.
    for path in sorted((ROOT / "src").rglob("*.luau")):
        for number, row in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for escape in re.findall(r"\\u\{([0-9A-Fa-f]+)\}", row):
                if EMOJI.match(chr(int(escape, 16))):
                    hits.append(f"{path.relative_to(ROOT)}:{number}: escaped U+{int(escape, 16):04X}")
    # "ponto(s)" reads like a form, not a game: pick the singular or the plural.
    for path in sorted((ROOT / "src").rglob("*.luau")):
        for line, text in literals(path.read_text(encoding="utf-8")):
            if re.search(r"\w\((s|es|ns)\)", text):
                hits.append(f"{path.relative_to(ROOT)}:{line}: lazy plural in {text[:70]!r} (choose singular/plural by the number)")
    if hits:
        print("FAIL no emoji:", len(hits), "emoji in player-facing strings (draw an icon or use a typographic symbol)")
        for hit in hits[:40]:
            print("  " + hit.encode("ascii", "backslashreplace").decode())
        return 1
    print("PASS no emoji: every string literal is free of emoji")
    return 0


if __name__ == "__main__":
    sys.exit(main())
