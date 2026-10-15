"""Open one of Studio's menus with a real click and pick an item from it.

Studio's menu popups are not exposed to UI Automation (only the menu bar is),
so a publish through File > Publicar needs two real clicks:

    python tools/studio_menu.py open --window-handle H 43 50
        brings the Doomsday Studio window to the front, clicks the menu title
        at (43, 50) (pixels of a tools/capture_studio.ps1 capture) and prints
        the popup window's handle and rectangle. The menu stays open; capture
        the popup with tools/capture_studio.ps1 -WindowHandle <popup> to read it.
    python tools/studio_menu.py pick --window-handle H --popup P 60 400
        clicks (60, 400) inside the popup, then puts the cursor back.

Only the Doomsday Studio window can be targeted. The owner gave the director
full use of the PC for this project (2026-10-02); this is still a last resort
after scripts and UI Automation.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import time

user32 = ctypes.windll.user32
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:  # noqa: BLE001
    user32.SetProcessDPIAware()

MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP = 0x0002, 0x0004
EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)


def title(handle: int) -> str:
    buffer = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(wintypes.HWND(handle), buffer, 256)
    return buffer.value


def rect_of(handle: int) -> wintypes.RECT:
    rect = wintypes.RECT()
    user32.GetWindowRect(wintypes.HWND(handle), ctypes.byref(rect))
    return rect


def bring_to_front(handle: int) -> None:
    if user32.IsIconic(wintypes.HWND(handle)):
        user32.ShowWindow(wintypes.HWND(handle), 9)
    current = user32.GetForegroundWindow() or 0
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
        if user32.GetForegroundWindow() == handle:
            return
        time.sleep(0.05)


def press(x: int, y: int) -> None:
    user32.SetCursorPos(x, y)
    time.sleep(0.12)
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)


def popups_of(main: int) -> list[int]:
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(wintypes.HWND(main), ctypes.byref(pid))
    found: list[int] = []

    def visit(handle, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
        if owner.value == pid.value and handle != main and user32.IsWindowVisible(handle):
            rect = rect_of(handle)
            if rect.right - rect.left > 40 and rect.bottom - rect.top > 40:
                found.append(handle)
        return True

    user32.EnumWindows(EnumWindowsProc(visit), 0)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("open", "pick"))
    parser.add_argument("x", type=int)
    parser.add_argument("y", type=int)
    parser.add_argument("--window-handle", type=int, required=True)
    parser.add_argument("--popup", type=int, default=0)
    args = parser.parse_args()
    name = title(args.window_handle)
    if "doomsday" not in name.lower() or "studio" not in name.lower():
        print(f"Refusing: window {args.window_handle} is '{name}', not the Doomsday Studio window.")
        return 2
    before = wintypes.POINT()
    user32.GetCursorPos(ctypes.byref(before))
    if args.action == "open":
        already = set(popups_of(args.window_handle))
        bring_to_front(args.window_handle)
        rect = rect_of(args.window_handle)
        press(rect.left + args.x, rect.top + args.y)
        time.sleep(0.6)
        new = [h for h in popups_of(args.window_handle) if h not in already]
        for handle in new:
            r = rect_of(handle)
            print(f"popup {handle} at ({r.left},{r.top}) size {r.right - r.left}x{r.bottom - r.top} class={title(handle)!r}")
        if not new:
            print("no popup appeared")
            return 1
        return 0
    rect = rect_of(args.popup) if args.popup else rect_of(args.window_handle)
    press(rect.left + args.x, rect.top + args.y)
    time.sleep(0.3)
    user32.SetCursorPos(before.x, before.y)
    print(f"picked ({args.x}, {args.y}) in {args.popup or args.window_handle}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
