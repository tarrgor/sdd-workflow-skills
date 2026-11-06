# sdd-workflow-skills - An agentic coding workflow

A set of AI coding agent skills that implement a **spec-driven development** workflow: turn a rough idea into a confirmed spec, break it into issues, implement and review each one, and keep a running log of decisions and knowledge — all with you in the loop for every decision that matters. Supported hosts are [Claude Code](https://claude.com/claude-code) and Codex in the ChatGPT desktop app, CLI, or IDE.

## Try it yourself

1. [Install](#install-for-claude-code) the `sdd-workflow` plugin (Codex: see [Install for Codex](#install-for-codex-on-native-windows)).
2. Create an empty directory for your project and start an agent session in it.
3. Run `/sdd-workflow:kick-off` (Codex: `$kick-off`) and give it your project idea.

The skill takes it from there — interviewing you one question at a time and guiding you through the rest of the workflow.

## Requirements

- **A GitHub repo.** The workflow runs on GitHub throughout — issues, pull requests, and review comments — and has no offline fallback. Issues are grouped into a GitHub milestone per spec (created via `gh api`). If the project isn't on GitHub yet, **kick-off** and **create-spec-issues** say so and offer to create the repo for you.
- **GitHub access.** Locally: the [GitHub CLI](https://cli.github.com) (`gh`), installed and authenticated — `brew install gh` on macOS or `winget install --id GitHub.cli` on Windows, then `gh auth login`. Without a working `gh` (e.g. in Claude Code cloud sessions, where `gh pr`/`gh issue` are refused), the skills fall back to the host's GitHub integration (MCP tools) plus `gh api` REST calls; the mapping lives in `skills/_shared/github.md`.
- **Python 3** — only for **project-status**, which renders `STATUS.html` with a bundled script. Without it the status report still works; the page is just skipped.
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
run-milestone  — runs implement → verify → merge for every ready issue, unattended, until a meeting is due
```

Each skill ends by naming the next step, so you always know what to run next. For an existing project that doesn't follow this workflow yet, **migrate-project** is the entry point instead of kick-off.

1. **kick-off** — interviews you about a new project or milestone, one question at a time, and writes a confirmed spec.
2. **create-spec-issues** — reads the newest spec, checks it against the code and captured knowledge for stale claims, and breaks it into one GitHub issue per unit of work — grouped under a GitHub milestone, ordered by dependency (`Depends on #N`).
3. **implement-issue** — implements a single issue end to end: branch, code, tests, and a pull request. Refuses issues whose blockers are still open.
4. **verify-implementation** — independently reviews the resulting PR for bugs, security issues, and unmet acceptance criteria, and returns its findings to the caller (implement-issue acts on them). Ships with a matching subagent (`agents/verify-implementation.md`), so the review runs in its own context window: the diff and the file reads stay out of your main conversation, and only a summary comes back. It delegates to that subagent however it was reached — including when you invoke it directly — so the review is never done by the context that wrote the code.
5. **check-pr-comments** — triages review feedback on an already-implemented issue and fixes what's valid.
6. **merge-pr** — merges an approved PR back into the base branch and cleans up the branch.
7. **project-meeting** — a recurring status meeting: reviews open findings, reports on finished work, and plans what's next — always with your confirmation before anything is decided. It is also the only skill that closes a milestone — once all its issues are done, and only after you confirm.
8. **project-status** — run anytime: reports milestone progress, open PRs, and pending findings, recommends exactly one next action, and renders the report as `STATUS.html` in the project root (from a shared template in `skills/_shared/`, so it looks the same every run; git-ignored).
9. **migrate-project** — entry point for an existing project that doesn't follow the workflow yet: inventories its planning documents and GitHub state, migrates everything into `.project/` and a milestone, and archives the originals. Re-runnable — it migrates only what's missing.
10. **create-obsidian-vault** — makes `.project/` browsable as an Obsidian vault: vault config plus a generated `Home.md` index of specs, knowledge, findings, and reports. **You invoke this one** whenever you want the vault created or its index refreshed. Agents never run it on their own; kick-off and migrate-project only remind you it exists.
11. **research-topic** — standalone, **you invoke this one**: researches a topic in depth against external sources and captures the result as a durable `.project/Knowledge/` entry, so knowledge can be acquired deliberately rather than only as a byproduct of implementation. Scopes the question with you first, checks what the project already knows so it researches the gaps, and runs the sweep in subagents (`agents/research-topic.md`) — one per subtopic, in parallel — so the pages read stay out of your conversation. Entries are marked `type: research` with a date, sources, and a confidence level; anything contradicting existing knowledge goes to the Inbox for the next meeting rather than overwriting it. Useful before **kick-off** (inform the spec interview), before **implement-issue** (an unfamiliar library or protocol), or when a **project-meeting** finding turns out to be an open question rather than a decision.
12. **generate-branding** — standalone, on demand: produces or refreshes a brand identity guide and visual assets in `.project/Branding/`. Independent of the loop above — run it whenever you want branding created or updated.
13. **estimate-issue** — standalone, **you invoke this one** (or `run-milestone` does, per issue): scores a single issue's implementation complexity (Low/Medium/High/Exceptional) from its acceptance criteria, the code it touches, and captured knowledge, and names the model for your host that suits that tier. Read-only, and it recommends only — no skill changes the model of the session it runs in, so switching it stays your call. Useful before **implement-issue** when you'd rather not implement a hard issue on a small model, or a trivial one on a large one.
14. **send-to-inbox** — standalone, run from any directory: turns a short note into a self-contained finding — with the context it came from, phrased in the target project's terms — and, after you confirm the draft, writes it to `.project/Inbox/` of the project you name. Useful when work in one project surfaces a requirement for another. It never commits; the next **project-meeting** in the target triages it.
15. **run-milestone** — **Claude Code desktop app; Codex desktop with chat tools**: works through the active milestone without you. It estimates each ready issue, starts one session per issue (in its own worktree, at most three at a time), runs **implement-issue** there in non-interactive mode, and merges the PRs whose final review left nothing high or critical open. Questions it can't answer park the issue with a `needs-decision` label and a finding. It stops once a meeting is due (a critical finding, or three pending), or when nothing is left to do, and writes a run report. Your standing permissions — parallelism, and whether it may merge into the default branch — live in `.project/RUN-POLICY.md`. Claude selects the estimated tier's model; Codex uses the user's default or an explicitly approved model table. It never creates issues, edits specs, closes milestones, or resolves findings.

Conventions shared by all skills (branch naming, committing to a protected base branch, milestone commands, the spec `Status:` lifecycle, Knowledge rules) live in `skills/_shared/conventions.md`; the next-action order, issue states and the meeting-due test shared by **project-status** and **merge-pr** live in `skills/_shared/next-action.md`; host-specific mappings, including the model recommended per complexity tier, live in `skills/_shared/runtime-adapters.md`.

## The `.project/` directory

Skills read and write project state here (created automatically on first use):

| Folder | Purpose |
|---|---|
| `SPEC.md` | The original, confirmed project spec |
| `SPEC-milestone-<###>-<slug>.md` | One confirmed spec per milestone, with a `Status: Planned/Active/Done` header |
| `Reports/` | Short completion reports, one per finished issue, plus one per `run-milestone` run |
| `RUN-POLICY.md` | Standing permissions for `run-milestone` |
| `Inbox/` | Findings surfaced during implementation, awaiting discussion |
| `Archive/` | Resolved findings and past meeting records |
| `Knowledge/` | Durable learnings, organized by topic — captured during implementation, or researched deliberately via `research-topic` |
| `Branding/BRAND.md` | Brand identity guide: palette, typography, voice & tone |
| `Branding/Assets/` | Generated logo, icon, and marketing assets (or creative briefs) |
| `Home.md` + `.obsidian/` | Obsidian vault: open `.project/` as a vault to browse all of the above |

## Install for Claude Code

The repository is a Claude Code plugin (`sdd-workflow`) and its own marketplace (`sdd-workflow-skills`). Install it once — either way below — and it works locally and in cloud sessions alike.

**Through your claude.ai account (recommended).** In claude.ai, open **Customize → Plugins**, add the marketplace `tarrgor/sdd-workflow-skills`, and install `sdd-workflow`. Claude Code syncs account plugins at session start: into cloud sessions (claude.ai/code), and into terminal sessions signed in with your claude.ai account (Claude Code v2.1.273 or later).

**Locally only:**

```bash
claude plugin marketplace add tarrgor/sdd-workflow-skills
claude plugin install sdd-workflow@sdd-workflow-skills
```

Don't do both: the local install then takes precedence and the synced copy is skipped. A cloud session never loads a plugin installed only locally, nor one declared under `enabledPlugins` / `extraKnownMarketplaces` in a project's `.claude/settings.json`.

Skills and agents carry the plugin prefix: `/sdd-workflow:kick-off`, `sdd-workflow:verify-implementation`. Plain-language requests ("implement issue #12") work without it. The plugin follows the repository's commits (no pinned `version`); a local install updates with `claude plugin update sdd-workflow@sdd-workflow-skills`, or automatically once auto-update is on for the marketplace in `/plugin`.

To work on the skills themselves, load your clone in place, so edits apply at the next session start: `claude plugin marketplace add /path/to/sdd-workflow-skills`, or `claude --plugin-dir /path/to/sdd-workflow-skills` for one session.

**Migrating from the former symlink install:** remove the old links from `~/.claude/skills` and `~/.claude/agents`, otherwise every skill is registered twice. Links in `~/.agents/skills` belong to the Codex install; remove them only if you don't use Codex.

**In cloud sessions** the skills use the GitHub integration instead of `gh` (see Requirements). Deleting a merged PR's remote branch may be refused there (merge-pr reports it), and `run-milestone` is unsupported.

## Install for Codex on native Windows

Use PowerShell from the repository root:

```powershell
.\install.ps1                         # Codex skills and custom agents
.\install.ps1 -DryRun                 # inspect without changing files
.\install.ps1 -Force                  # replace only links that point elsewhere
.\install.ps1 -Uninstall              # remove only this repo's managed items
```

The installer creates directory junctions from `skills/<name>/` into `%USERPROFILE%\.agents\skills`, so skill edits remain live without requiring symbolic-link privileges. Codex custom-agent TOMLs are copied into `%USERPROFILE%\.codex\agents`; only files carrying the sdd-workflow-skills managed header are updated or removed. Existing user files and real skill directories are never overwritten, including with `-Force`.

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
| Model recommendation per complexity tier | Sonnet / Opus / Fable | Terra / Sol / Astra |
| Unattended milestone runs (`run-milestone`) | Desktop app only | Desktop with chat tools; live acceptance pending; CLI/IDE unsupported |
| Technical prevention of local reads by research agent | Full through the manifest tool allowlist | Not equivalent; current Codex custom-agent configuration supplies a behavioral prohibition, not a web-only tool allowlist |
| Normal Git checkout | Full | Full |
| Existing linked worktree / detached `HEAD` | Supported | Supported, including Codex App worktrees |
| Installation | Plugin (claude.ai account or `claude plugin install`) | `install.ps1` (Windows), `install-codex.sh` (macOS/Linux/WSL2) |

When strict technical prevention of local reads is required for research under Codex, use a separately sandboxed research service instead of the bundled Codex research custom agent.

Before a release, run the native app checks in [docs/codex-windows-acceptance.md](docs/codex-windows-acceptance.md). The design and delivery rationale is recorded in [docs/codex-windows-compatibility-plan.md](docs/codex-windows-compatibility-plan.md).

## Use the workflow

Once installed, tell your agent what you want in plain language — e.g. *"kick off this project"*, *"implement issue #12"*, *"let's have a project meeting"*. Codex CLI and IDE also support `$skill-name`; the desktop app exposes installed skills in its Skills UI. In Claude Code, skills are also available as `/sdd-workflow:<skill>`.

### Run a milestone in Codex desktop

The Codex adapter requires explicit permission for user-visible chats and worktrees, not implementation subagents. For example, substituting your actual milestone and base branch:

> Run milestone 001-auth-flow. Create separate implementation and feedback chats in their own worktrees starting from develop. You may send follow-up instructions and retry a failed unit once in the same chat. Use my default model settings and the merge permissions in RUN-POLICY.md. Start with parallel: 1.

The coordinator confirms only missing policy values or authorizations and records the Codex mandate in `.project/RUN-POLICY.md`. For tier-based model selection, approve the exact model/effort table it proposes. Existing authorizations are reused; policy files do not bypass host permissions.

The [Codex adapter](skills/run-milestone/references/codex-desktop.md) journals chat identities and attempts in `codex-run:` issue comments, counts feedback chats toward the same concurrency limit, and binds merge receipts to the reviewed commit. Permission prompts or uncertain chat state pause dispatch; re-invoking the skill reconciles recorded chats before starting more work. It does not promise an unattended restart after the coordinator ends, and leaves worktrees available for inspection.

Complete the [Codex milestone acceptance scenarios](docs/codex-run-milestone-acceptance.md) with one worker before raising parallelism. The Claude session mapping and loop are unchanged; the compatibility validator checks their baseline.

## License

[MIT](LICENSE) © tarrgor.

These skills instruct an agent to act on your repository — creating branches, committing, pushing, opening and merging pull requests, and editing files under `.project/`. Read a skill before you run it, and keep your agent's permission settings tight enough that you see those actions before they happen. The software comes with no warranty of any kind; what it does to your repo is your responsibility.
