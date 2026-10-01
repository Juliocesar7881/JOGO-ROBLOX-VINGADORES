"""tools/director.py: one session at a time, stale locks are taken over, and a
STOP file pauses every run."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DIRECTOR = ROOT / "tools" / "director.py"


def run(home: Path, *args: str, at: str = "2026-10-01T01:00:00-03:00") -> subprocess.CompletedProcess:
    env = dict(os.environ, DIRECTOR_ROOT=str(home), DIRECTOR_NOW=at)
    return subprocess.run([sys.executable, str(DIRECTOR), *args], env=env, capture_output=True, text=True, encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("FAIL " + message)


def main() -> None:
    with tempfile.TemporaryDirectory() as raw:
        home = Path(raw)
        first = run(home, "lock", "acquire", "--owner", "a")
        check(first.returncode == 0 and "ACQUIRED" in first.stdout, f"a free lock is taken: {first.stdout}{first.stderr}")
        busy = run(home, "lock", "acquire", "--owner", "b", at="2026-10-01T01:20:00-03:00")
        check(busy.returncode == 3, "a fresh lock refuses a second session")
        again = run(home, "lock", "acquire", "--owner", "a", at="2026-10-01T01:10:00-03:00")
        check(again.returncode == 0, "the holder can re-acquire its own lock")
        beat = run(home, "lock", "heartbeat", "--owner", "a", at="2026-10-01T01:25:00-03:00")
        check(beat.returncode == 0, "the holder's heartbeat renews the lock")
        still = run(home, "lock", "acquire", "--owner", "b", at="2026-10-01T01:50:00-03:00")
        check(still.returncode == 3, "a heartbeat 25 minutes ago keeps the lock busy")
        stale = run(home, "lock", "acquire", "--owner", "b", at="2026-10-01T02:00:00-03:00")
        check(stale.returncode == 0 and "took over" in stale.stdout, "a lock silent for 35 minutes is taken over")
        lost = run(home, "lock", "heartbeat", "--owner", "a", at="2026-10-01T02:01:00-03:00")
        check(lost.returncode == 3, "the old holder learns it lost the lock")
        run(home, "lock", "release", "--owner", "a", at="2026-10-01T02:02:00-03:00")
        check((home / "test-results" / "director" / "lock.json").exists(), "a non-holder cannot release the lock")
        run(home, "lock", "release", "--owner", "b", at="2026-10-01T02:03:00-03:00")
        check(not (home / "test-results" / "director" / "lock.json").exists(), "the holder releases the lock")
        (home / "docs" / "director").mkdir(parents=True)
        (home / "docs" / "director" / "STOP").write_text("dormindo", encoding="utf-8")
        halted = run(home, "lock", "acquire", "--owner", "c")
        check(halted.returncode == 4, "docs/director/STOP pauses the director")
        logged = run(home, "log", "testou a trava")
        check(logged.returncode == 0, "log appends")
        text = (home / "docs" / "director" / "LOG.md").read_text(encoding="utf-8")
        check("2026-10-01 01:00 — testou a trava" in text, "log lines carry the local time")
    # Old review scripts edit scripts or the world in place: each must refuse
    # the team's Team Create place, which tools/studio_review.py reviews safely.
    for path in sorted((ROOT / "tools").glob("studio_*.luau")):
        check(path.read_text(encoding="utf-8").startswith("assert(game.PlaceId ~= 97132875544830"), f"{path.name} refuses the team place")
    print("PASS director lock: single holder, stale takeover, heartbeat, release, STOP, log; review scripts refuse the team place")


if __name__ == "__main__":
    main()
