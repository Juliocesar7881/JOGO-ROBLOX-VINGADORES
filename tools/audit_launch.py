"""Report configured IDs without conflating local configuration with live validation.

python tools/audit_launch.py --output test-results/launch-audit.json
Does not publish, read credentials, create products or change account settings.
"""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def collect():
    result = subprocess.run([str(ROOT / ".tools/luau/luau.exe"), "tools/audit_launch.luau"],
                            cwd=ROOT, check=True, capture_output=True, text=True, encoding="utf-8")
    report = {"counts": {}, "products": [], "configuration": {}, "soundBanks": {}}
    for line in result.stdout.splitlines():
        row = line.split("|")
        if row[0] == "COUNT": report["counts"][row[1]] = int(row[2])
        elif row[0] == "PRODUCT":
            report["products"].append(dict(category=row[1], key=row[2], id=int(row[3]),
                                           catalogPrice=int(row[4]), name=row[5]))
        elif row[0] == "CONFIG": report["configuration"][row[1]] = int(row[2])
        elif row[0] == "AUDIO": report["soundBanks"][row[1]] = int(row[2])
    heroes = [p for p in report["products"] if p["category"] == "Heroes"]
    report["counts"].update(heroProducts=len(heroes), configuredHeroProducts=sum(p["id"] > 0 for p in heroes))
    report["missingProducts"] = [p for p in report["products"] if p["id"] == 0]
    report["deploymentFileExists"] = (ROOT / "deployment/local.json").is_file()
    report["mode"] = "separate-places" if report["configuration"]["LobbyPlaceId"] and report["configuration"]["MatchPlaceId"] else "Standalone"
    report["cloudValidated"] = False
    report["deviceValidated"] = False
    report["note"] = "IDs configurados não comprovam venda, moderação, direitos, recibos ou retenção real."
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = collect()
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    counts = report["counts"]
    print(f"{counts['heroes']} heroes; {counts['bases']} bases; {counts['maps']} maps; {report['mode']}")
    print(f"Hero products: {counts['configuredHeroProducts']}/{counts['heroProducts']} configured")
    for product in report["missingProducts"]:
        print(f"MISSING {product['category']}.{product['key']} ({product['catalogPrice']} Robux)")
    print("Cloud/device/purchase/retention acceptance remains separate from this configuration audit.")


if __name__ == "__main__":
    main()
