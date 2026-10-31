# Runtime adapters

Use the current host's native capabilities. These mappings change invocation and command syntax only; they do not change the workflow's approval, safety, or output requirements.

## Subagents

- **Claude Code:** use the `Agent` tool with the requested `subagent_type`. Subagents run in the background and notify the caller when they finish; wait for that result before any step that depends on it, exactly as the calling skill specifies.
- **Codex:** spawn the matching custom agent with the collaboration/subagent capability, explicitly tell it to use the corresponding `$verify-implementation` or `$research-topic` skill, pass the complete brief, and wait for its final result before continuing. The Codex custom agents are named `verify-implementation` and `research-topic` — the same names Claude Code uses; their source files live in `agents/codex/`.
- If the named agent is unavailable, follow the fallback in the calling skill. Never claim independent review or isolated context when the work ran in the caller.

## Model selection

A skill may recommend a model per complexity tier; it never changes the model of the session it runs in — that stays the user's choice (`/model`, or the host's model picker). A model can be set only on work a skill starts itself (a subagent, or a new session where the host can start one), and this workflow does not implement issues in subagents.

The table names model families, not versions: use the newest release of the named family that the host offers.

| Tier | Claude Code | Codex |
|---|---|---|
| Low | Sonnet | Terra |
| Medium | Opus | Sol |
| High | Opus | Sol |
| Exceptional | Fable | Astra |

Astra and Fable are reserved for genuinely exceptional work; Sol carries ordinary coding issues up to and including the High tier. If the host offers a reasoning-effort setting, raise it with the tier rather than reaching for a larger model.

Name the recommendation and let the user act on it.

## Shell and filesystem

- Prefer the host's file-search and file-editing tools over shell-specific pipelines.
- Recursive file listing: use `rg --files` when available. PowerShell fallback: `Get-ChildItem -Recurse -File`. POSIX fallback: `find <path> -type f`.
- Local ISO date: use runtime date context when available. PowerShell fallback: `Get-Date -Format yyyy-MM-dd`. POSIX fallback: `date +%F`.
- Python 3 (for bundled scripts): `python3` on POSIX; `python` or `py -3` on Windows.
- Create directories with the host-native operation. PowerShell: `New-Item -ItemType Directory -Force`. POSIX: `mkdir -p`.
- Treat repository-relative paths as platform-neutral. Quote native filesystem paths, especially when they contain spaces.
- For multiline GitHub issue or PR bodies, prefer a temporary body file and `gh ... --body-file <path>` over shell-dependent quoting.

## Git worktrees

Determine whether the current checkout is linked by comparing `git rev-parse --git-common-dir` with `git rev-parse --git-dir` and consulting `git worktree list --porcelain` when needed.

- **Normal checkout:** the workflow may switch to and fast-forward the base branch before creating the issue branch.
- **Existing linked worktree:** never create a nested worktree and never switch another checkout. Fetch the remote, verify the intended base ref, and create the issue branch directly from that ref if the current worktree is detached. Preserve any existing branch and stop on unrelated changes that make the operation ambiguous.
- A Codex-created worktree may start at detached `HEAD`. This is expected, not an error.

## Skill invocation labels

- Claude Code may expose skills as slash commands.
- Codex CLI and IDE support `$skill-name`; the ChatGPT desktop app exposes installed skills in its Skills UI.
- In user-facing guidance, name the skill itself unless the host-specific invocation syntax is known.
