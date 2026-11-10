"""Check the Claude Code and Codex plugin manifests stay consistent with the repo."""

import json
import re
from pathlib import Path
import sys


def validate(root: Path) -> list[str]:
    errors = []
    try:
        plugin = json.loads((root / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"Unreadable plugin manifest: {exc}"]

    for stale in (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"):
        if (root / stale).exists():
            errors.append(f"{stale} must not exist: the plugin is listed in the tarrgor/agent-plugins marketplace")
    if "agents" in plugin:
        errors.append("plugin.json must not set \"agents\": the default agents/ scan is what loads them")
    icon = plugin.get("icon")
    if icon is not None and (not isinstance(icon, str) or not icon.startswith("./") or ".." in Path(icon).parts or not (root / icon).is_file()):
        errors.append("plugin.json icon must reference a bundled file under ./")
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
    except (OSError, ValueError) as exc:
        errors.append(f"Unreadable Codex plugin manifest: {exc}")
        return errors
    for field in ("name", "description", "homepage", "repository", "license"):
        value = codex.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"Codex plugin {field} must be a non-empty string")
    if not isinstance(codex.get("name"), str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", codex["name"]) or len(codex["name"]) > 64:
        errors.append("Codex plugin name must use lowercase hyphen-case, at most 64 characters")
    author = codex.get("author")
    if not isinstance(author, dict) or not isinstance(author.get("name"), str) or not author["name"].strip():
        errors.append("Codex plugin author.name is required")
    for field in ("keywords",):
        value = codex.get(field)
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            errors.append(f"Codex plugin {field} must be a list of strings")
    version = codex.get("version")
    if not isinstance(version, str) or not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        errors.append("Codex plugin version is required and must use major.minor.patch")
    interface = codex.get("interface")
    if not isinstance(interface, dict):
        errors.append("Codex plugin interface is required")
    else:
        capabilities = interface.get("capabilities")
        if not isinstance(capabilities, list) or not all(isinstance(item, str) for item in capabilities):
            errors.append("Codex plugin interface.capabilities must be a list of strings")
        for field in ("displayName", "shortDescription", "longDescription", "developerName", "category"):
            value = interface.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"Codex plugin interface.{field} must be a non-empty string")
        for field in ("defaultPrompt", "screenshots"):
            value = interface.get(field)
            if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
                errors.append(f"Codex plugin interface.{field} must be a list of strings")
        prompts = interface.get("defaultPrompt", [])
        if isinstance(prompts, list) and (len(prompts) > 3 or any(isinstance(p, str) and len(p) > 128 for p in prompts)):
            errors.append("Codex defaultPrompt supports at most 3 strings of at most 128 characters")
        for field in ("composerIcon", "logo", "logoDark"):
            value = interface.get(field)
            if value is not None and (not isinstance(value, str) or not value.startswith("./") or ".." in Path(value).parts or not (root / value).is_file()):
                errors.append(f"Codex interface.{field} must reference a bundled file under ./")
        screenshots = interface.get("screenshots", [])
        if isinstance(screenshots, list):
            for value in screenshots:
                if not isinstance(value, str) or not value.startswith("./assets/") or ".." in Path(value).parts or not value.endswith(".png") or not (root / value).is_file():
                    errors.append("Codex screenshots must reference bundled PNG files under ./assets/")
    if codex.get("name") != plugin.get("name"):
        errors.append("Codex and Claude plugin names must match")
    if codex.get("skills") != "./skills":
        errors.append("Codex plugin must load the shared ./skills directory")
    if "agents" in codex:
        errors.append("Codex plugin must not claim custom-agent registration via an agents field")
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
    print("Plugin manifests are consistent.")
