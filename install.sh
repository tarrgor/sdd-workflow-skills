#!/usr/bin/env bash
#
# Symlink every skill in ./skills and every agent in ./agents into the
# user's agent directories.
#
# Usage: ./install.sh [-f|--force] [-n|--dry-run]
#
#   -f, --force     replace existing symlinks that point elsewhere
#   -n, --dry-run   show what would happen, change nothing
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
AGENTS_DIR="$REPO_DIR/agents"
SKILL_TARGET_DIRS=("$HOME/.claude/skills" "$HOME/.agents/skills")
# Subagents are a Claude Code concept; ~/.agents is a cross-tool skills convention.
AGENT_TARGET_DIRS=("$HOME/.claude/agents")

force=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)   force=1 ;;
    -n|--dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "error: no skills directory at $SKILLS_DIR" >&2
  exit 1
fi

run() {
  if [[ $dry_run -eq 1 ]]; then
    echo "  would run: $*"
  else
    "$@"
  fi
}

linked=0
skipped=0

# link_item <source> <link>
link_item() {
  local src="$1" link="$2"

  # Already pointing where we want it.
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    echo "ok       $link"
    return
  fi

  if [[ -e "$link" || -L "$link" ]]; then
    if [[ -L "$link" && $force -eq 1 ]]; then
      echo "replace  $link (was -> $(readlink "$link"))"
      run rm "$link"
    elif [[ -L "$link" ]]; then
      echo "skip     $link exists -> $(readlink "$link") (use --force to replace)" >&2
      skipped=$((skipped + 1))
      return
    else
      # A real file or directory -- never clobber it, even with --force.
      echo "skip     $link exists and is not a symlink; remove it yourself" >&2
      skipped=$((skipped + 1))
      return
    fi
  fi

  echo "link     $link -> $src"
  run ln -s "$src" "$link"
  linked=$((linked + 1))
}

ensure_dir() {
  if [[ ! -d "$1" ]]; then
    echo "creating $1"
    run mkdir -p "$1"
  fi
}

# Skills: skills/<name>/ -> <target>/<name>
# The glob intentionally includes skills/_shared/ (no SKILL.md) — skills
# reference it as a sibling directory (../_shared/conventions.md).
for target_dir in "${SKILL_TARGET_DIRS[@]}"; do
  ensure_dir "$target_dir"

  for skill_path in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_path" ]] || continue
    skill_src="${skill_path%/}"
    link_item "$skill_src" "$target_dir/$(basename "$skill_src")"
  done
done

# Agents: agents/<name>.md -> <target>/<name>.md
if [[ -d "$AGENTS_DIR" ]]; then
  for target_dir in "${AGENT_TARGET_DIRS[@]}"; do
    ensure_dir "$target_dir"

    for agent_src in "$AGENTS_DIR"/*.md; do
      [[ -f "$agent_src" ]] || continue
      link_item "$agent_src" "$target_dir/$(basename "$agent_src")"
    done
  done
fi

echo
echo "linked: $linked  skipped: $skipped$([[ $dry_run -eq 1 ]] && echo "  (dry run)")"
