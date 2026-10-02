"""Upload the original WAVs in assets/audio through Studio's Asset Manager.

    python tools/studio_upload_audio.py --window-handle 4785928 click place upgrade wave

Drives the open Doomsday Studio window (Asset Manager and its import queue
must be open; Window > Asset Manager): clicks the queue's folder button, answers
the file dialog with tools/studio_file_dialog.ps1, presses "Iniciar importação"
and confirms Studio's "Importação de arquivo" window, the per-upload statement
that the files are yours. The owner asked for these files to be uploaded
(docs/director/BACKLOG.md M7.1) and they are the project's own synthesis
(assets/audio/manifest.json). Positions are those of the 2582x1388 window.
Uses tools/studio_realclick.py, which moves the pointer for a moment.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOLDER_BUTTON = (1315, 1101)
START_BUTTON = (2483, 1101)
CONFIRM_BUTTON = (445, 488)


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(list(args), cwd=ROOT, capture_output=True, text=True)


def realclick(handle: int, x: int, y: int) -> None:
    result = run(sys.executable, "tools/studio_realclick.py", "--window-handle", str(handle), str(x), str(y))
    if result.returncode != 0:
        raise SystemExit(result.stdout + result.stderr)


def find_window(title: str) -> int:
    ps = r'''
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class WF { public delegate bool EP(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EP p, IntPtr l);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 public static long Find(string wanted) { long found = 0; EnumWindows((h,l)=>{ var t=new StringBuilder(256); GetWindowText(h,t,256); if(IsWindowVisible(h) && t.ToString()==wanted){ found=h.ToInt64(); return false;} return true;}, IntPtr.Zero); return found; } }
"@
[WF]::Find("%s")
''' % title
    result = run("powershell", "-NoProfile", "-Command", ps)
    try:
        return int(result.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="+", help="file names in assets/audio, without .wav")
    parser.add_argument("--window-handle", type=int, required=True)
    args = parser.parse_args()
    directory = ROOT / "assets" / "audio"
    files = []
    for name in args.names:
        path = directory / f"{name}.wav"
        if not path.is_file():
            raise SystemExit(f"missing {path}")
        files.append(str(path))
    quoted = " ".join(f'"{f}"' for f in files)
    realclick(args.window_handle, *FOLDER_BUTTON)
    time.sleep(2.5)
    answer = run("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "tools/studio_file_dialog.ps1", "-Path", quoted, "-WindowHandle", str(args.window_handle))
    print(answer.stdout.strip()[:200], answer.stderr.strip()[:200])
    if answer.returncode != 0:
        return 1
    time.sleep(4)
    realclick(args.window_handle, *START_BUTTON)
    confirm = 0
    for _ in range(30):
        time.sleep(1)
        confirm = find_window("Importação de arquivo")
        if confirm:
            break
    if not confirm:
        print("No confirmation window appeared.")
        return 1
    time.sleep(1.5)
    realclick(confirm, *CONFIRM_BUTTON)
    print(f"confirmed {len(files)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
