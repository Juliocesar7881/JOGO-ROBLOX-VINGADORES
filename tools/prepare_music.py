"""Prepare the licensed music, ready to upload to Roblox: one battle track per map and the lobby's.

    python tools/prepare_music.py                               # sources in "D:/Downloads google"
    python tools/prepare_music.py --source <folder>             # any folder holding the MP3s
    python tools/prepare_music.py --source <folder> --only lobby  # just these keys; the others keep their credits

Every track is Creative Commons BY (commercial use allowed, the author must be
credited; the game credits them in Options > Credits, Catalog.MusicCredits).
For each track this trims silence at both ends, normalises to -16 LUFS with a
-1.5 dBTP ceiling (two-pass loudnorm, linear), adds a short fade in and out so
the loop is seamless, and writes assets/audio/licensed_music/<file>.ogg
(gitignored: third-party files stay out of the repository). The credits and
the hash of every prepared file go to assets/audio/music_credits.json, which
is versioned. Upload the OGGs as Audio in the Creator Hub (the owner confirms
the rights there), then put each ID in Config.Audio under its key
(battle<Map>, lobby).
Needs ffmpeg on PATH.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "licensed_music"
CREDITS = ROOT / "assets" / "audio" / "music_credits.json"
TARGET_LUFS, CEILING_DB = -16.0, -1.5

# Map -> the source file (a unique piece of its name) and its credit.
# Manhattan, Wakanda and Asgard first had Alexander Nakarada's Chase, Pirates of
# the Quarantine and Valhalla; Roblox moderation rejected those three uploads
# (seen 15/10), so they play Kevin MacLeod tracks from incompetech.com instead.
MUSIC = {
    "manhattan": {"match": "Undaunted", "title": "Undaunted", "author": "Kevin MacLeod (incompetech.com)",
                  "license": "CC BY 4.0", "source": "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1400025"},
    "gamma": {"match": "Checkpoint", "title": "Checkpoint", "author": "Hayden Folker",
              "license": "CC BY 3.0", "source": "https://www.free-stock-music.com/hayden-folker-checkpoint.html"},
    "hydra": {"match": "Pursuit", "title": "Pursuit", "author": "Hayden Folker",
              "license": "CC BY 3.0", "source": "https://www.free-stock-music.com/hayden-folker-pursuit.html"},
    "wakanda": {"match": "Firebrand", "title": "Firebrand", "author": "Kevin MacLeod (incompetech.com)",
                "license": "CC BY 4.0", "source": "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100830"},
    "latveria": {"match": "Storm - Música Dramática", "title": "Storm", "author": "Keys of Moon",
                 "license": "CC BY 4.0", "source": "https://www.free-stock-music.com/keys-of-moon-storm.html"},
    "asgard": {"match": "Five Armies", "title": "Five Armies", "author": "Kevin MacLeod (incompetech.com)",
               "license": "CC BY 4.0", "source": "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100875"},
}

# Config.Audio key -> what to prepare: every map's battle track, then the lobby's.
# The lobby plays "Marlboro Lite" by Spazz Cardigan (owner, 16/10: the track he
# picked, in place of Kevin MacLeod's "Electrodoodle" of 15/10). It is a YouTube
# Audio Library track released 18/09/2018; its listings mark it Creative Commons
# Attribution (reuse allowed, CC BY 3.0, e.g. https://audiograb.com/bm8Dl84Xf),
# so the game credits the author in Options like every other track.
TRACKS = {"battle" + mapId[0].upper() + mapId[1:]: {**info, "map": mapId, "file": f"battle_{mapId}.ogg"} for mapId, info in MUSIC.items()}
TRACKS["lobby"] = {"match": "Marlboro Lite", "title": "Marlboro Lite", "author": "Spazz Cardigan",
                   "license": "CC BY 3.0", "source": "https://www.youtube.com/audiolibrary",
                   "file": "lobby.ogg"}


def run(args: list[str]) -> str:
    done = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        raise RuntimeError(f"{args[0]} failed: {done.stderr[-800:]}")
    return done.stderr


def seconds(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


def loudness(path: Path) -> dict:
    """First loudnorm pass: what the track measures now."""
    log = run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
               f"loudnorm=I={TARGET_LUFS}:TP={CEILING_DB}:LRA=11:print_format=json", "-f", "null", "-"])
    block = log[log.rindex("{"):log.rindex("}") + 1]
    return json.loads(block)


def prepare(source: Path, target: Path) -> dict:
    with tempfile.TemporaryDirectory() as scratch:
        trimmed = Path(scratch) / "trimmed.wav"
        # Silence off both ends (below -50 dB), so the loop has no dead air.
        edge = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05"
        run(["ffmpeg", "-y", "-hide_banner", "-i", str(source), "-af", f"{edge},areverse,{edge},areverse",
             "-ar", "44100", "-ac", "2", str(trimmed)])
        length = seconds(trimmed)
        measured = loudness(trimmed)
        chain = (f"loudnorm=I={TARGET_LUFS}:TP={CEILING_DB}:LRA=11:linear=true"
                 f":measured_I={measured['input_i']}:measured_TP={measured['input_tp']}"
                 f":measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}"
                 f":offset={measured['target_offset']},"
                 f"afade=t=in:d=0.6,afade=t=out:st={max(0.0, length - 2.5):.2f}:d=2.5,aresample=44100")
        run(["ffmpeg", "-y", "-hide_banner", "-i", str(trimmed), "-af", chain, "-c:a", "libvorbis", "-q:a", "5",
             "-ar", "44100", "-ac", "2", str(target)])
    final = loudness(target)
    return {"seconds": round(seconds(target), 2), "lufs": float(final["input_i"]), "truePeak": float(final["input_tp"]),
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", default="D:/Downloads google", help="folder holding the source MP3s")
    parser.add_argument("--only", help="comma-separated Config.Audio keys to prepare (e.g. lobby); the others keep their credits")
    args = parser.parse_args()
    keys = [key.strip() for key in args.only.split(",")] if args.only else list(TRACKS)
    unknown = [key for key in keys if key not in TRACKS]
    if unknown:
        print(f"unknown keys {unknown}; known: {', '.join(TRACKS)}", file=sys.stderr)
        return 1
    folder = Path(args.source)
    files = sorted(folder.glob("*.mp3"))
    OUT.mkdir(parents=True, exist_ok=True)
    credits = json.loads(CREDITS.read_text(encoding="utf-8")) if CREDITS.exists() else {}
    for key in keys:
        info = TRACKS[key]
        found = [path for path in files if info["match"] in path.name]
        if len(found) != 1:
            print(f"{key}: expected one source matching {info['match']!r}, found {len(found)}", file=sys.stderr)
            return 1
        target = OUT / info["file"]
        facts = prepare(found[0], target)
        credits[key] = {**({"map": info["map"]} if "map" in info else {}), "title": info["title"], "author": info["author"],
                        "license": info["license"], "source": info["source"], "file": f"licensed_music/{target.name}", **facts}
        print(f"{key}: {info['title']} - {facts['seconds']} s, {facts['lufs']} LUFS, peak {facts['truePeak']} dBTP")
    ordered = {key: credits[key] for key in TRACKS if key in credits}
    CREDITS.write_text(json.dumps(ordered, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{len(keys)} track(s) prepared in {OUT}; credits in {CREDITS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
