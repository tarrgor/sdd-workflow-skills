#!/usr/bin/env bash
#
# Install skillz-lattice for Codex on macOS, Linux, or WSL.
# Usage: ./install-codex.sh [-f|--force] [-n|--dry-run] [-u|--uninstall]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
AGENTS_DIR="$REPO_DIR/agents/codex"
SKILLS_TARGET="$HOME/.agents/skills"
AGENTS_TARGET="$HOME/.codex/agents"
force=0
dry_run=0
uninstall=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) force=1 ;;
    -n|--dry-run) dry_run=1 ;;
    -u|--uninstall) uninstall=1 ;;
    -h|--help)
      sed -n '2,4p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

run() {
  if [[ $dry_run -eq 1 ]]; then
    echo "  would run: $*"
  else
    "$@"
  fi
}

ensure_dir() {
  if [[ ! -d "$1" ]]; then
    echo "creating $1"
    run mkdir -p "$1"
  fi
}

link_item() {
  local src="$1" link="$2"
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
      echo "skip     $link exists and is not a symlink; remove it yourself" >&2
      skipped=$((skipped + 1))
      return
    fi
  fi
  echo "link     $link -> $src"
  run ln -s "$src" "$link"
  linked=$((linked + 1))
}

remove_item() {
  local src="$1" link="$2"
  if [[ ! -e "$link" && ! -L "$link" ]]; then
    return
  fi
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    echo "remove   $link"
    run rm "$link"
    removed=$((removed + 1))
    return
  fi
  echo "skip     $link is not this repository's managed symlink" >&2
  skipped=$((skipped + 1))
}

MANAGED_HEADER="# Managed by skillz-lattice; local edits to installed copies may be replaced."

# Codex refuses symlinked agent role files (ELOOP), so agents are copied.
is_managed_file() {
  [[ -f "$1" && ! -L "$1" && "$(head -n 1 "$1")" == "$MANAGED_HEADER" ]]
}

copy_item() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    echo "replace  $dest (symlink from an earlier install)"
    run rm "$dest"
  elif [[ -e "$dest" || -L "$dest" ]]; then
    if [[ ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
      echo "ok       $dest"
      return
    fi
    if ! is_managed_file "$dest"; then
      echo "skip     $dest is not managed by skillz-lattice; remove it yourself" >&2
      skipped=$((skipped + 1))
      return
    fi
    echo "update   $dest"
  else
    echo "copy     $dest"
  fi
  run cp "$src" "$dest"
  copied=$((copied + 1))
}

remove_copy() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]] || is_managed_file "$dest"; then
    echo "remove   $dest"
    run rm "$dest"
    removed=$((removed + 1))
  elif [[ -e "$dest" || -L "$dest" ]]; then
    echo "skip     $dest is not managed by skillz-lattice" >&2
    skipped=$((skipped + 1))
  fi
}

linked=0
copied=0
skipped=0
removed=0
if [[ $uninstall -eq 0 ]]; then
  ensure_dir "$SKILLS_TARGET"
  ensure_dir "$AGENTS_TARGET"
fi

for skill_path in "$SKILLS_DIR"/*/; do
  [[ -d "$skill_path" ]] || continue
  skill_src="${skill_path%/}"
  if [[ $uninstall -eq 1 ]]; then
    remove_item "$skill_src" "$SKILLS_TARGET/$(basename "$skill_src")"
  else
    link_item "$skill_src" "$SKILLS_TARGET/$(basename "$skill_src")"
  fi
done

for agent_src in "$AGENTS_DIR"/*.toml; do
  [[ -f "$agent_src" ]] || continue
  if [[ $uninstall -eq 1 ]]; then
    remove_copy "$agent_src" "$AGENTS_TARGET/$(basename "$agent_src")"
  else
    copy_item "$agent_src" "$AGENTS_TARGET/$(basename "$agent_src")"
  fi
done

echo
echo "linked: $linked  copied: $copied  removed: $removed  skipped: $skipped$([[ $dry_run -eq 1 ]] && echo "  (dry run)")"
