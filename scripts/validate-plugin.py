"""Check the Claude Code and Codex plugin manifests stay consistent with the repo."""

import json
import re
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
    # claude.ai rejects plugin uploads whose descriptions contain anything tag-like.
    for manifest in [*root.glob("skills/*/SKILL.md"), *root.glob("agents/*.md")]:
        front = manifest.read_text(encoding="utf-8").split("---", 2)[1]
        for line in front.splitlines():
            if line.startswith("description:") and re.search(r"<[^>]*>", line):
                errors.append(f"{manifest.relative_to(root)}: description must not contain <...>")
            if line.startswith("description:") and " #" in line:
                errors.append(f"{manifest.relative_to(root)}: \" #\" starts a YAML comment and truncates the description")
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
    try:
        codex = json.loads((root / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))
        codex_market = json.loads((root / ".agents/plugins/marketplace.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"Unreadable Codex plugin manifest: {exc}")
        return errors
    version = codex.get("version")
    if not isinstance(version, str) or not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        errors.append("Codex plugin version is required and must use major.minor.patch")
    interface = codex.get("interface")
    if not isinstance(interface, dict):
        errors.append("Codex plugin interface is required")
    else:
        for field in ("displayName", "shortDescription", "longDescription", "developerName"):
            value = interface.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"Codex plugin interface.{field} must be a non-empty string")
    if codex.get("name") != plugin.get("name"):
        errors.append("Codex and Claude plugin names must match")
    if codex.get("skills") != "./skills":
        errors.append("Codex plugin must load the shared ./skills directory")
    if "agents" in codex:
        errors.append("Codex plugin must not claim custom-agent registration via an agents field")
    expected_entry = {"name": codex.get("name"), "source": {"source": "local", "path": "./"}}
    if codex_market.get("name") != market.get("name") or codex_market.get("plugins") != [expected_entry]:
        errors.append("Codex marketplace must expose the repository root under the shared plugin/marketplace names")
    skills = list(root.glob("skills/*/SKILL.md"))
    if not skills:
        errors.append("Codex plugin has no bundled skills")
    for resource in ("skills/_shared/runtime-adapters.md", "skills/_shared/scripts/status-page.py",
                     "skills/_shared/status-template.html", "skills/run-milestone/references/codex-desktop.md"):
        if not (root / resource).is_file():
            errors.append(f"Missing bundled plugin resource: {resource}")
    return errors


if __name__ == "__main__":
    errors = validate(Path(__file__).resolve().parent.parent)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("Plugin and marketplace manifests are consistent.")
