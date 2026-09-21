"""Small stdio client for Roblox's locally installed StudioMCP (no dependencies)."""
import argparse
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import time


class StudioBridge:
    def __init__(self):
        versions = Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "Versions"
        paths = sorted(versions.glob("version-*/StudioMCP.exe"), key=lambda p: p.stat().st_mtime)
        if not paths:
            raise RuntimeError("Roblox StudioMCP is not installed")
        self.process = subprocess.Popen([str(paths[-1]), "--stdio"], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True, encoding="utf-8", creationflags=subprocess.CREATE_NO_WINDOW)
        self.messages = queue.Queue()
        self.serial = 0

        def reader():
            for line in self.process.stdout:
                try:
                    self.messages.put(json.loads(line))
                except json.JSONDecodeError:
                    pass

        threading.Thread(target=reader, daemon=True).start()
        threading.Thread(target=lambda: list(self.process.stderr), daemon=True).start()
        self.request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                    "clientInfo": {"name": "doomsday-local-validation", "version": "1.0"}})
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, value):
        self.process.stdin.write(json.dumps(value, ensure_ascii=False) + "\n")
        self.process.stdin.flush()

    def request(self, method, params=None, timeout=50):
        self.serial += 1
        serial = self.serial
        self.send({"jsonrpc": "2.0", "id": serial, "method": method, "params": params or {}})
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                value = self.messages.get(timeout=min(1, max(0.01, deadline-time.monotonic())))
            except queue.Empty:
                if self.process.poll() is not None:
                    raise RuntimeError("StudioMCP exited")
                continue
            if value.get("id") == serial:
                return value
        raise TimeoutError("StudioMCP timed out; open Studio and enable its MCP server")

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("method", nargs="?", default="tools/list")
    parser.add_argument("--params", help="JSON parameters file")
    parser.add_argument("--out", help="Write full JSON response to this file")
    args = parser.parse_args()
    client = StudioBridge()
    try:
        params = json.loads(Path(args.params).read_text(encoding="utf-8")) if args.params else {}
        result = client.request(args.method, params)
        text = json.dumps(result, ensure_ascii=False, indent=2)
        if args.out:
            Path(args.out).write_text(text, encoding="utf-8")
            print("Saved", args.out)
        else:
            print(text)
    finally:
        client.close()


if __name__ == "__main__":
    main()
