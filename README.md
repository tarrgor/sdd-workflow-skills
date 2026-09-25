# sdd-workflow-skills - An agentic coding workflow

A set of AI coding agent skills that implement a **spec-driven development** workflow: turn a rough idea into a confirmed spec, break it into issues, implement and review each one, and keep a running log of decisions and knowledge — all with you in the loop for every decision that matters. Supported hosts are [Claude Code](https://claude.com/claude-code) and Codex in the ChatGPT desktop app, CLI, or IDE.

## Try it yourself

1. [Install](#install-for-claude-code-on-macos-or-linux) sdd-workflow-skills.
2. Create an empty directory for your project and start an agent session in it.
3. Run `/kick-off` and give it your project idea.

The skill takes it from there — interviewing you one question at a time and guiding you through the rest of the workflow.

## Requirements

- **A GitHub repo.** The workflow runs on GitHub throughout — issues, pull requests, and review comments — and has no offline fallback. Issues are grouped into a GitHub milestone per spec (created via `gh api`). If the project isn't on GitHub yet, **kick-off** and **create-spec-issues** say so and offer to create the repo for you.
- **The [GitHub CLI](https://cli.github.com) (`gh`), installed and authenticated.** Every skill drives GitHub through `gh`. Install it with `brew install gh` on macOS or `winget install --id GitHub.cli` on Windows, then run `gh auth login`; `gh auth status` should succeed before you start.
- **A base branch for feature work.** `develop` is preferred — it keeps released code on `main` separate from work in progress — but it's optional: if the repo doesn't have one, the skills use its default branch (usually `main`) instead. Either way, feature branches are cut from the base branch and PRs target it.

## The workflow

```
kick-off ──────────────► create-spec-issues ──────────────► implement-issue
(idea → SPEC.md)         (spec → milestone + issues)        (issue → PR)
                                                                   │
                                                                   ▼
project-meeting  ◄────────────  merge-pr  ◄──────────  verify-implementation
(triage findings,               (approved PR             (PR → findings)
 plan next steps)                → base branch)            │
        ▲                                                       ▼
        │                                              check-pr-comments
        └──────────── new issues, spec changes ◄────── (feedback → fixes)

project-status — run anytime: where does the project stand, what's the next action?
```

Each skill ends by naming the next step, so you always know what to run next. For an existing project that doesn't follow this workflow yet, **migrate-project** is the entry point instead of kick-off.

1. **kick-off** — interviews you about a new project or milestone, one question at a time, and writes a confirmed spec.
2. **create-spec-issues** — reads the newest spec, checks it against the code and captured knowledge for stale claims, and breaks it into one GitHub issue per unit of work — grouped under a GitHub milestone, ordered by dependency (`Depends on #N`).
3. **implement-issue** — implements a single issue end to end: branch, code, tests, and a pull request. Refuses issues whose blockers are still open.
4. **verify-implementation** — independently reviews the resulting PR for bugs, security issues, and unmet acceptance criteria, and returns its findings to the caller (implement-issue acts on them). Ships with a matching subagent (`agents/verify-implementation.md`), so the review runs in its own context window: the diff and the file reads stay out of your main conversation, and only a summary comes back. It delegates to that subagent however it was reached — including when you invoke it directly — so the review is never done by the context that wrote the code.
5. **check-pr-comments** — triages review feedback on an already-implemented issue and fixes what's valid.
6. **merge-pr** — merges an approved PR back into the base branch, cleans up the branch, and closes the milestone when its last issue lands.
7. **project-meeting** — a recurring status meeting: reviews open findings, reports on finished work, and plans what's next — always with your confirmation before anything is decided.
8. **project-status** — read-only, run anytime: reports milestone progress, open PRs, and pending findings, and recommends exactly one next action.
9. **migrate-project** — entry point for an existing project that doesn't follow the workflow yet: inventories its planning documents and GitHub state, migrates everything into `.project/` and a milestone, and archives the originals. Re-runnable — it migrates only what's missing.
10. **create-obsidian-vault** — makes `.project/` browsable as an Obsidian vault: vault config plus a generated `Home.md` index of specs, knowledge, findings, and reports. **You invoke this one** whenever you want the vault created or its index refreshed. Agents never run it on their own; kick-off and migrate-project only remind you it exists.
11. **research-topic** — standalone, **you invoke this one**: researches a topic in depth against external sources and captures the result as a durable `.project/Knowledge/` entry, so knowledge can be acquired deliberately rather than only as a byproduct of implementation. Scopes the question with you first, checks what the project already knows so it researches the gaps, and runs the sweep in subagents (`agents/research-topic.md`) — one per subtopic, in parallel — so the pages read stay out of your conversation. Entries are marked `type: research` with a date, sources, and a confidence level; anything contradicting existing knowledge goes to the Inbox for the next meeting rather than overwriting it. Useful before **kick-off** (inform the spec interview), before **implement-issue** (an unfamiliar library or protocol), or when a **project-meeting** finding turns out to be an open question rather than a decision.
12. **generate-branding** — standalone, on demand: produces or refreshes a brand identity guide and visual assets in `.project/Branding/`. Independent of the loop above — run it whenever you want branding created or updated.
13. **estimate-issue** — standalone, **you invoke this one**: scores a single issue's implementation complexity (Low/Medium/High/Exceptional) from its acceptance criteria, the code it touches, and captured knowledge, and names the model for your host that suits that tier. Read-only, and it recommends only — no skill can change the running session's model, so switching it stays your call. Useful before **implement-issue** when you'd rather not implement a hard issue on a small model, or a trivial one on a large one.

Conventions shared by all skills (branch naming, committing to a protected base branch, milestone commands, the spec `Status:` lifecycle, Knowledge rules) live in `skills/_shared/conventions.md`; host-specific mappings, including the model recommended per complexity tier, live in `skills/_shared/runtime-adapters.md`.

## The `.project/` directory

Skills read and write project state here (created automatically on first use):

| Folder | Purpose |
|---|---|
| `SPEC.md` | The original, confirmed project spec |
| `SPEC-milestone-<###>-<slug>.md` | One confirmed spec per milestone, with a `Status: Planned/Active/Done` header |
| `Reports/` | Short completion reports, one per finished issue |
| `Inbox/` | Findings surfaced during implementation, awaiting discussion |
| `Archive/` | Resolved findings and past meeting records |
| `Knowledge/` | Durable learnings, organized by topic — captured during implementation, or researched deliberately via `research-topic` |
| `Branding/BRAND.md` | Brand identity guide: palette, typography, voice & tone |
| `Branding/Assets/` | Generated logo, icon, and marketing assets (or creative briefs) |
| `Home.md` + `.obsidian/` | Obsidian vault: open `.project/` as a vault to browse all of the above |

## Install for Claude Code on macOS or Linux

The original installer and its default behavior are retained for Claude Code:

```bash
./install.sh              # create the symlinks
./install.sh --dry-run    # show what would happen, change nothing
./install.sh --force      # also replace symlinks that point elsewhere
```

| Source | Symlinked into |
|---|---|
| `skills/<name>/` | `~/.claude/skills`, `~/.agents/skills` |
| `agents/<name>.md` | `~/.claude/agents` |

`skills/_shared/` is linked alongside the skills — it's not a skill itself, but the conventions file the skills reference as a sibling directory.

Existing symlinks that point somewhere else are skipped unless you pass `--force`, and real files or directories are never overwritten. If you'd rather not symlink, copy the `skills/<name>/` folders and `agents/<name>.md` files into your agent's skills and subagent directories by hand.

The existing Claude agent manifests remain at `agents/*.md`; their frontmatter, tool restrictions, and install destinations are unchanged.

## Install for Codex on native Windows

Use PowerShell from the repository root:

```powershell
.\install.ps1                         # Codex skills and custom agents
.\install.ps1 -DryRun                 # inspect without changing files
.\install.ps1 -Force                  # replace only links that point elsewhere
.\install.ps1 -Uninstall              # remove only this repo's managed items
.\install.ps1 -Target All             # Codex and Claude Code
```

The installer creates directory junctions from `skills/<name>/` into `%USERPROFILE%\.agents\skills`, so skill edits remain live without requiring symbolic-link privileges. Codex custom-agent TOMLs are copied into `%USERPROFILE%\.codex\agents`; only files carrying the sdd-workflow-skills managed header are updated or removed. Existing user files and real skill directories are never overwritten, including with `-Force`.

`-Target Claude` additionally links skills into `%USERPROFILE%\.claude\skills` and Claude agent manifests into `%USERPROFILE%\.claude\agents`. Creating file symlinks requires Windows Developer Mode or an elevated PowerShell session. This PowerShell path is additive; the legacy `install.sh` contract remains the Claude baseline.

After installation, start a new Codex task if the skills or custom agents do not appear immediately. Keep the Windows sandbox enabled. Git and `gh` must be installed natively when the Codex agent runs in PowerShell.

If PowerShell blocks the installer, inspect the current policy with `Get-ExecutionPolicy -List` and use a policy approved for your machine or organization. Do not weaken a managed enterprise policy just to run the script.

## Install for Codex on macOS, Linux, or WSL2

```bash
./install-codex.sh
./install-codex.sh --dry-run
./install-codex.sh --force
./install-codex.sh --uninstall
```

This links skills into `~/.agents/skills` and copies Codex custom agents into `~/.codex/agents` — Codex refuses symlinked agent files, so re-run the installer after pulling agent changes. Only files carrying the sdd-workflow-skills managed header are updated or removed; symlinks left by earlier installs are replaced with copies. Under Windows, WSL2 uses its Linux home by default; it does not automatically share the native `%USERPROFILE%\.codex` configuration.

## Host compatibility

| Capability | Claude Code | Codex |
|---|---|---|
| Shared skills and `.project/` workflow | Full | Full |
| Independent implementation review | Claude subagent manifest | Codex read-only custom agent |
| Parallel topic research | Web-only Claude subagents | Read-only Codex custom agents |
| Model recommendation per complexity tier | Sonnet / Opus 5 / Fable | Terra / Sol / Astra |
| Technical prevention of local reads by research agent | Full through the manifest tool allowlist | Not equivalent; current Codex custom-agent configuration supplies a behavioral prohibition, not a web-only tool allowlist |
| Normal Git checkout | Full | Full |
| Existing linked worktree / detached `HEAD` | Supported | Supported, including Codex App worktrees |
| Native Windows installation | PowerShell `-Target Claude` | PowerShell default |

When strict technical prevention of local reads is required for research under Codex, use a separately sandboxed research service instead of the bundled Codex research custom agent.

Before a release, run the native app checks in [docs/codex-windows-acceptance.md](docs/codex-windows-acceptance.md). The design and delivery rationale is recorded in [docs/codex-windows-compatibility-plan.md](docs/codex-windows-compatibility-plan.md).

## Use the workflow

Once installed, tell your agent what you want in plain language — e.g. *"kick off this project"*, *"implement issue #12"*, *"let's have a project meeting"*. Codex CLI and IDE also support `$skill-name`; the desktop app exposes installed skills in its Skills UI. Claude Code can keep using its existing slash-command flow.

## License

[MIT](LICENSE) © tarrgor.

These skills instruct an agent to act on your repository — creating branches, committing, pushing, opening and merging pull requests, and editing files under `.project/`. Read a skill before you run it, and keep your agent's permission settings tight enough that you see those actions before they happen. The software comes with no warranty of any kind; what it does to your repo is your responsibility.
