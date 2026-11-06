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
    for agent in ("verify-implementation", "research-topic"):
        path = root / "agents" / f"{agent}.md"
        if not path.is_file():
            errors.append(f"Missing Claude agent manifest: agents/{agent}.md")
            continue
        front = path.read_text(encoding="utf-8").split("---", 2)[1]
        if f"skills:\n  - {agent}\n" not in front:
            errors.append(f"agents/{agent}.md must preload its skill: skills: [{agent}]")
        if agent == "research-topic":
            tools = next((l for l in front.splitlines() if l.startswith("tools:")), "")
            local = [t for t in ("Read", "Grep", "Glob", "Bash", "Write", "Edit") if t in tools.split(":", 1)[-1].replace(",", " ").split()]
            if local:
                errors.append(f"agents/research-topic.md must stay web-only; remove {', '.join(local)}")
    return errors


if __name__ == "__main__":
    errors = validate(Path(__file__).resolve().parent.parent)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("Plugin and marketplace manifests are consistent.")
