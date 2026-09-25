from pathlib import Path
import sys
import tomllib


repo_root = Path(__file__).resolve().parent.parent
agent_files = sorted((repo_root / "agents" / "codex").glob("*.toml"))
expected_names = {"research-topic", "verify-implementation"}
errors: list[str] = []
names: set[str] = set()

for path in agent_files:
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        errors.append(f"{path.relative_to(repo_root)}: {exc}")
        continue

    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            errors.append(f"{path.relative_to(repo_root)}: missing non-empty {field}")
    if data.get("sandbox_mode") != "read-only":
        errors.append(f"{path.relative_to(repo_root)}: sandbox_mode must be read-only")
    if isinstance(data.get("name"), str):
        names.add(data["name"])

if names != expected_names:
    errors.append(f"agent names were {sorted(names)}, expected {sorted(expected_names)}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)

print(f"Parsed {len(agent_files)} Codex custom-agent TOML files.")
