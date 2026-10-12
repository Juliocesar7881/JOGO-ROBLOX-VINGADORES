"""Exercise the real analytics module against strict Roblox API signatures."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    module = (ROOT / "src/server/AnalyticsService.luau").read_text(encoding="utf-8")
    spec = (ROOT / "tests/analytics.spec.luau").read_text(encoding="utf-8")
    source = spec.replace("__MODULE__", "(function()\n" + module + "\nend)()")
    with tempfile.TemporaryDirectory(prefix="doomsday-analytics-") as directory:
        path = Path(directory) / "analytics.luau"
        path.write_text(source, encoding="utf-8")
        subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(path)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
