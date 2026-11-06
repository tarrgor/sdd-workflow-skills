"""Check the Claude Code plugin and marketplace manifests stay consistent with the repo."""

import json
from pathlib import Path
import sys


def validate(root: Path) -> list[str]:
    errors = []
    try:
        plugin = json.loads((root / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))
        market = json.loads((root / ".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"Unreadable plugin manifest: {exc}"]

    entries = [p for p in market.get("plugins", []) if p.get("source") == "./"]
    if len(entries) != 1:
        errors.append("marketplace.json needs exactly one plugin entry with source \"./\"")
    elif entries[0].get("name") != plugin.get("name"):
        errors.append("marketplace entry name must equal plugin.json name")
    if "agents" in plugin:
        errors.append("plugin.json must not set \"agents\": the default agents/ scan is what loads them")
    if not list((root / "agents").glob("*.md")):
        errors.append("No Claude agent manifests in agents/")
    return errors


if __name__ == "__main__":
    errors = validate(Path(__file__).resolve().parent.parent)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("Plugin and marketplace manifests are consistent.")
