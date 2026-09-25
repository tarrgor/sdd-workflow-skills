#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

legacy_output="$(HOME="$test_root/legacy" "$repo_dir/install.sh" --dry-run)"
[[ "$legacy_output" == *".claude/skills"* ]]
[[ "$legacy_output" == *".agents/skills"* ]]
[[ "$legacy_output" == *".claude/agents"* ]]

codex_output="$(HOME="$test_root/codex" "$repo_dir/install-codex.sh" --dry-run)"
[[ "$codex_output" == *".agents/skills"* ]]
[[ "$codex_output" == *".codex/agents"* ]]

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "POSIX dry-run contracts passed; symlink behavior is tested on Linux CI."
    exit 0
    ;;
esac

HOME="$test_root/codex" "$repo_dir/install-codex.sh" >/dev/null
[[ -L "$test_root/codex/.agents/skills/kick-off" ]]
agent="$test_root/codex/.codex/agents/verify-implementation.toml"
# Codex rejects symlinked agent role files, so they must be real copies.
[[ -f "$agent" && ! -L "$agent" ]]
cmp -s "$repo_dir/agents/codex/verify-implementation.toml" "$agent"

# An earlier install's symlink is migrated to a copy.
rm "$agent" && ln -s "$repo_dir/agents/codex/verify-implementation.toml" "$agent"
HOME="$test_root/codex" "$repo_dir/install-codex.sh" >/dev/null
[[ -f "$agent" && ! -L "$agent" ]]

# A user-owned agent file is never overwritten or removed.
user_agent="$test_root/codex/.codex/agents/research-topic.toml"
echo '# user-owned agent' > "$user_agent"
HOME="$test_root/codex" "$repo_dir/install-codex.sh" --force >/dev/null 2>&1
grep -q 'user-owned' "$user_agent"

HOME="$test_root/codex" "$repo_dir/install-codex.sh" --uninstall >/dev/null 2>&1
[[ ! -e "$test_root/codex/.agents/skills/kick-off" ]]
[[ ! -e "$agent" ]]
grep -q 'user-owned' "$user_agent"

echo "POSIX installer tests passed."
