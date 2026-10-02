"""Click inside the Studio window with window messages, never moving the real mouse.

    python tools/studio_click.py --window-handle 4785928 1645 135

The coordinates are pixels of a tools/capture_studio.ps1 capture (the whole
window as PrintWindow draws it). They are turned into client coordinates and
posted as WM_MOUSEMOVE / WM_LBUTTONDOWN / WM_LBUTTONUP to the window under that
point, so the owner's pointer and focus are left alone. Only the shared place's
Studio window can be targeted (the handle is checked against its title).
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import sys
import time

user32 = ctypes.windll.user32
WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_RBUTTONDOWN, WM_RBUTTONUP = 0x0200, 0x0201, 0x0202, 0x0204, 0x0205
MK_LBUTTON = 0x0001


def title(handle: int) -> str:
    buffer = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(wintypes.HWND(handle), buffer, 256)
    return buffer.value


def make_lparam(x: int, y: int) -> int:
    return ((y & 0xFFFF) << 16) | (x & 0xFFFF)


def to_client(handle: int, px: int, py: int) -> tuple[int, int]:
    rect = wintypes.RECT()
    user32.GetWindowRect(wintypes.HWND(handle), ctypes.byref(rect))
    origin = wintypes.POINT(0, 0)
    user32.ClientToScreen(wintypes.HWND(handle), ctypes.byref(origin))
    return px - (origin.x - rect.left), py - (origin.y - rect.top)


def click(handle: int, px: int, py: int, right: bool = False, double: bool = False) -> None:
    x, y = to_client(handle, px, py)
    lparam = make_lparam(x, y)
    down, up = (WM_RBUTTONDOWN, WM_RBUTTONUP) if right else (WM_LBUTTONDOWN, WM_LBUTTONUP)
    user32.PostMessageW(wintypes.HWND(handle), WM_MOUSEMOVE, 0, lparam)
    time.sleep(0.05)
    for _ in range(2 if double else 1):
        user32.PostMessageW(wintypes.HWND(handle), down, MK_LBUTTON, lparam)
        time.sleep(0.06)
        user32.PostMessageW(wintypes.HWND(handle), up, 0, lparam)
        time.sleep(0.06)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("x", type=int)
    parser.add_argument("y", type=int)
    parser.add_argument("--window-handle", type=int, required=True)
    parser.add_argument("--right", action="store_true")
    parser.add_argument("--double", action="store_true")
    args = parser.parse_args()
    name = title(args.window_handle)
    if "Multiverse Doomsday" not in name and "Doomsday" not in name:
        print(f"Refusing: window {args.window_handle} is '{name}', not the Doomsday Studio window.")
        return 2
    click(args.window_handle, args.x, args.y, args.right, args.double)
    print(f"clicked ({args.x}, {args.y}) in '{name}'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
