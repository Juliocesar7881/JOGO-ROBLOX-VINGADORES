"""One real mouse click inside the Doomsday Studio window, for the few controls
Studio does not expose to UI Automation or window messages (its ribbon and the
Asset Manager are custom-drawn).

    python tools/studio_realclick.py --window-handle 4785928 2518 1100 [--double] [--right]

Coordinates are pixels of a tools/capture_studio.ps1 capture. The window is
brought to the front for the instant of the click; afterwards the previous
foreground window and the cursor position are put back, so the owner is
disturbed for a fraction of a second. The owner gave the director full use of
the PC for this project (2026-10-02), but this stays a last resort: scripts
(tools/studio_*.py) and UI Automation come first. Only the Doomsday Studio
window can be targeted.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import sys
import time

user32 = ctypes.windll.user32
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:  # noqa: BLE001
    user32.SetProcessDPIAware()

MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP = 0x0002, 0x0004, 0x0008, 0x0010


def title(handle: int) -> str:
    buffer = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(wintypes.HWND(handle), buffer, 256)
    return buffer.value


def foreground() -> int:
    return user32.GetForegroundWindow() or 0


def bring_to_front(handle: int) -> None:
    if user32.IsIconic(wintypes.HWND(handle)):
        user32.ShowWindow(wintypes.HWND(handle), 9)  # SW_RESTORE
    current = foreground()
    this = ctypes.windll.kernel32.GetCurrentThreadId()
    pid = wintypes.DWORD()
    other = user32.GetWindowThreadProcessId(wintypes.HWND(current), ctypes.byref(pid)) if current else 0
    if other and other != this:
        user32.AttachThreadInput(this, other, True)
    user32.BringWindowToTop(wintypes.HWND(handle))
    user32.SetForegroundWindow(wintypes.HWND(handle))
    if other and other != this:
        user32.AttachThreadInput(this, other, False)
    for _ in range(20):
        if foreground() == handle:
            return
        time.sleep(0.05)


def click(handle: int, px: int, py: int, right: bool, double: bool) -> None:
    rect = wintypes.RECT()
    user32.GetWindowRect(wintypes.HWND(handle), ctypes.byref(rect))
    x, y = rect.left + px, rect.top + py
    before_cursor = wintypes.POINT()
    user32.GetCursorPos(ctypes.byref(before_cursor))
    before_window = foreground()
    bring_to_front(handle)
    user32.SetCursorPos(x, y)
    time.sleep(0.12)
    down, up = (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP) if right else (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP)
    for _ in range(2 if double else 1):
        user32.mouse_event(down, 0, 0, 0, 0)
        time.sleep(0.05)
        user32.mouse_event(up, 0, 0, 0, 0)
        time.sleep(0.08)
    time.sleep(0.25)
    user32.SetCursorPos(before_cursor.x, before_cursor.y)
    if before_window and before_window != handle:
        user32.SetForegroundWindow(wintypes.HWND(before_window))


def drag(handle: int, px: int, py: int, qx: int, qy: int) -> None:
    """Press at (px, py), move in small steps to (qx, qy), release (a splitter, a scrollbar)."""
    rect = wintypes.RECT()
    user32.GetWindowRect(wintypes.HWND(handle), ctypes.byref(rect))
    before_cursor = wintypes.POINT()
    user32.GetCursorPos(ctypes.byref(before_cursor))
    before_window = foreground()
    bring_to_front(handle)
    user32.SetCursorPos(rect.left + px, rect.top + py)
    time.sleep(0.15)
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    steps = 20
    for step in range(1, steps + 1):
        user32.SetCursorPos(rect.left + px + (qx - px) * step // steps, rect.top + py + (qy - py) * step // steps)
        time.sleep(0.03)
    time.sleep(0.1)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.25)
    user32.SetCursorPos(before_cursor.x, before_cursor.y)
    if before_window and before_window != handle:
        user32.SetForegroundWindow(wintypes.HWND(before_window))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("x", type=int)
    parser.add_argument("y", type=int)
    parser.add_argument("--window-handle", type=int, required=True)
    parser.add_argument("--right", action="store_true")
    parser.add_argument("--double", action="store_true")
    parser.add_argument("--drag-to", nargs=2, type=int, metavar=("X", "Y"), help="drag from the first point to this one")
    parser.add_argument("--wheel", type=int, help="scroll the wheel by this many notches (negative = down) over the point instead of clicking")
    args = parser.parse_args()
    name = title(args.window_handle)
    # The Studio window itself, or the "Importação de arquivo" confirmation and the
    # 3D importer's "Importar prévia" window Studio opens (separate windows) for an
    # upload the owner asked for (16/10: "faça tudo necessário... só gratuito").
    if ("doomsday" not in name.lower() or "studio" not in name.lower()) and name not in ("Importação de arquivo", "File Import", "Importar prévia", "Import Preview"):
        print(f"Refusing: window {args.window_handle} is '{name}', not the Doomsday Studio window.")
        return 2
    rect = wintypes.RECT()
    user32.GetWindowRect(wintypes.HWND(args.window_handle), ctypes.byref(rect))
    print(f"window {rect.right - rect.left}x{rect.bottom - rect.top} at ({rect.left},{rect.top})")
    if args.wheel:
        rect2 = wintypes.RECT()
        user32.GetWindowRect(wintypes.HWND(args.window_handle), ctypes.byref(rect2))
        before = wintypes.POINT()
        user32.GetCursorPos(ctypes.byref(before))
        previous = foreground()
        bring_to_front(args.window_handle)
        user32.SetCursorPos(rect2.left + args.x, rect2.top + args.y)
        time.sleep(0.15)
        for _ in range(abs(args.wheel)):
            user32.mouse_event(0x0800, 0, 0, 120 if args.wheel > 0 else -120 & 0xFFFFFFFF, 0)
            time.sleep(0.05)
        time.sleep(0.2)
        user32.SetCursorPos(before.x, before.y)
        if previous and previous != args.window_handle:
            user32.SetForegroundWindow(wintypes.HWND(previous))
        print(f"wheel {args.wheel} at ({args.x}, {args.y})")
        return 0
    if args.drag_to:
        drag(args.window_handle, args.x, args.y, args.drag_to[0], args.drag_to[1])
        print(f"dragged ({args.x}, {args.y}) -> {tuple(args.drag_to)}")
        return 0
    click(args.window_handle, args.x, args.y, args.right, args.double)
    print(f"clicked ({args.x}, {args.y})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
