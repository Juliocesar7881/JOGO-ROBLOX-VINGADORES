"""The overnight director's lock: only one Claude session works on the game at
a time, and the owner can stop them all with a single file.

    python tools/director.py lock acquire --owner NAME   exit 0 = yours, 3 = busy, 4 = STOP
    python tools/director.py lock heartbeat --owner NAME exit 0 = still yours, 3 = lost
    python tools/director.py lock release --owner NAME
    python tools/director.py status
    python tools/director.py log "what changed"          appends to docs/director/LOG.md

The lock lives in test-results/director/lock.json (never committed). A lock
whose heartbeat is older than --stale-minutes (default 30) is abandoned: its
session crashed or hit its usage limit, so the next one takes over.

STOP: any of test-results/director/STOP or docs/director/STOP (the second can
be created from a phone on GitHub; every run pulls before it starts) makes
acquire refuse with exit 4.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import sys

ROOT = Path(os.environ.get("DIRECTOR_ROOT") or Path(__file__).resolve().parents[1])
STATE = ROOT / "test-results" / "director"
LOCK = STATE / "lock.json"
STOPS = (STATE / "STOP", ROOT / "docs" / "director" / "STOP")
LOG = ROOT / "docs" / "director" / "LOG.md"

BUSY, STOPPED = 3, 4


def now() -> dt.datetime:
    override = os.environ.get("DIRECTOR_NOW")
    if override:
        return dt.datetime.fromisoformat(override)
    return dt.datetime.now().astimezone()


def read_lock() -> dict | None:
    try:
        return json.loads(LOCK.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def age_minutes(lock: dict) -> float:
    try:
        beat = dt.datetime.fromisoformat(lock["heartbeat"])
    except (KeyError, TypeError, ValueError):
        return float("inf")
    return (now() - beat).total_seconds() / 60


def write_lock(owner: str, started: str | None = None, note: str = "") -> None:
    stamp = now().isoformat(timespec="seconds")
    LOCK.write_text(json.dumps({"owner": owner, "started": started or stamp, "heartbeat": stamp, "note": note}, indent=2), encoding="utf-8")


def stopped() -> Path | None:
    for path in STOPS:
        if path.exists():
            return path
    return None


def acquire(owner: str, stale: float, note: str) -> int:
    STATE.mkdir(parents=True, exist_ok=True)
    stop = stopped()
    if stop:
        print(f"STOP {stop.relative_to(ROOT)} exists: the owner paused the director.")
        return STOPPED
    current = read_lock()
    if current and current.get("owner") != owner and age_minutes(current) < stale:
        print(f"BUSY held by {current.get('owner')} (heartbeat {age_minutes(current):.1f} min ago)")
        return BUSY
    if current is None and not LOCK.exists():
        # Atomic create: two sessions starting together cannot both win.
        try:
            with open(LOCK, "x", encoding="utf-8"):
                pass
        except FileExistsError:
            print("BUSY another session created the lock first")
            return BUSY
    write_lock(owner, current.get("started") if current and current.get("owner") == owner else None, note)
    taken = current and current.get("owner") not in (None, owner)
    print(f"ACQUIRED by {owner}" + (f" (took over a stale lock from {current.get('owner')})" if taken else ""))
    return 0


def heartbeat(owner: str, note: str) -> int:
    current = read_lock()
    if not current or current.get("owner") != owner:
        print(f"LOST the lock is held by {current and current.get('owner')}")
        return BUSY
    write_lock(owner, current.get("started"), note or current.get("note", ""))
    print(f"HEARTBEAT {owner}")
    return 0


def release(owner: str) -> int:
    current = read_lock()
    if current and current.get("owner") == owner:
        LOCK.unlink()
        print(f"RELEASED by {owner}")
        return 0
    print(f"NOT HELD by {owner} (holder: {current and current.get('owner')})")
    return 0


def status() -> int:
    stop = stopped()
    current = read_lock()
    if stop:
        print(f"STOP present: {stop.relative_to(ROOT)}")
    if current:
        print(f"LOCK {current.get('owner')} started {current.get('started')} heartbeat {age_minutes(current):.1f} min ago — {current.get('note', '')}")
    else:
        print("LOCK free")
    return 0


def log(text: str) -> int:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    if not LOG.exists():
        LOG.write_text("# Diário do diretor\n\nUma linha por passo, a mais nova embaixo.\n\n", encoding="utf-8")
    with open(LOG, "a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"- {now().strftime('%Y-%m-%d %H:%M')} — {text.strip()}\n")
    print("LOGGED")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    lock = sub.add_parser("lock")
    lock.add_argument("action", choices=("acquire", "heartbeat", "release"))
    lock.add_argument("--owner", required=True)
    lock.add_argument("--stale-minutes", type=float, default=30)
    lock.add_argument("--note", default="")
    sub.add_parser("status")
    entry = sub.add_parser("log")
    entry.add_argument("text")
    options = parser.parse_args(argv)
    if options.command == "status":
        return status()
    if options.command == "log":
        return log(options.text)
    if options.action == "acquire":
        return acquire(options.owner, options.stale_minutes, options.note)
    if options.action == "heartbeat":
        return heartbeat(options.owner, options.note)
    return release(options.owner)


if __name__ == "__main__":
    sys.exit(main())
