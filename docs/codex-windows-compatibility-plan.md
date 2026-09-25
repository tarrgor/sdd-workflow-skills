# Codex App and Windows compatibility plan

## Goal

Make the skillz-lattice workflow usable from the Codex experience in the ChatGPT desktop app on native Windows, while retaining Claude Code and Unix support. The workflow must remain spec-driven, GitHub-backed, worktree-safe, and explicit about destructive or externally visible actions.

The recommended approach is one canonical set of runtime-neutral skills plus thin host adapters. Forking every skill into Claude and Codex editions would make the workflow drift almost immediately.

## Current-state assessment

| Area | Current state | Gap |
|---|---|---|
| Skills | The `skills/<name>/SKILL.md` layout and required `name`/`description` frontmatter already match Codex's skill format. | Several instructions name Claude-specific invocation and agent APIs. Codex App metadata is absent. |
| Skill discovery | `install.sh` links skills to `~/.agents/skills`, which Codex scans. | Installation requires Bash and POSIX symlinks; there is no native Windows installer or verification command. |
| Project guidance | Root `AGENTS.md` exists. | It only says `Read CLAUDE.md.`. Codex should receive its essential repository rules directly and not depend on a second, Claude-named file being loaded correctly. |
| Subagents | Two Claude Markdown manifests exist under `agents/`. | Codex custom agents are TOML files under `.codex/agents/` or `~/.codex/agents/`, and the skills call Claude's `Agent` tool and `subagent_type` syntax directly. |
| Research isolation | The Claude research agent has an explicit web-only tool allowlist. | Codex documents per-agent sandbox and MCP configuration, but not an equivalent per-agent tool allowlist. `read-only` prevents writes but does not itself prevent local reads. |
| Shell portability | Git and `gh` are broadly cross-platform. | `install.sh`, `ls -R`, `date +%F`, `mkdir -p`, Bash blocks, POSIX path examples, and shell quoting assumptions are present. |
| Codex worktrees | `merge-pr` partially detects linked worktrees. | `implement-issue` says to never use a worktree and switches through the base branch, which conflicts with Codex App worktree sessions and branches checked out elsewhere. |
| Distribution | Manual symlink installation is documented. | There is no Windows onboarding, Codex App smoke test, release validation, or optional plugin package. |
| Tests | None. | Installer idempotency, manifest validity, relative references, platform-neutral instructions, and basic workflow behavior can regress unnoticed. |

## Target architecture

Keep these sources canonical:

```text
skills/                         shared workflow skills
  _shared/
    conventions.md
    runtime-adapters.md         host and OS capability mapping
  <skill>/
    SKILL.md
    agents/openai.yaml          only where Codex App metadata/policy is useful
agents/*.md                     unchanged Claude Code manifests
agents/codex/                   additive Codex custom-agent TOML sources
install.sh                      macOS/Linux/WSL installer
install.ps1                     native Windows installer
tests/                          static and installer checks
```

Do not check generated links or copied installations into source control. Both installers should consume the same canonical `skills/` tree and host-specific agent sources.

Codex targets:

- Skills: user installation in `$HOME/.agents/skills` (on Windows, `%USERPROFILE%\.agents\skills`). This is already the cross-tool location and is documented as a Codex user skill scope.
- Personal custom agents: `%USERPROFILE%\.codex\agents\*.toml`.
- Optional repository-scoped mode: links under `<target-repo>/.agents/skills` and Codex agent files under `<target-repo>/.codex/agents`. This mode should be opt-in because it modifies another repository.
- Project instructions: `AGENTS.md`, which Codex discovers from the repository root down to the working directory.

## Implementation phases

### 1. Define the compatibility contract

1. Add `skills/_shared/runtime-adapters.md` with capability-level terminology:
   - "spawn the named review subagent and wait for its final result" instead of hard-coding one tool-call schema;
   - "list files recursively" and "obtain the local ISO date" with PowerShell and POSIX examples where exact commands help;
   - normal-checkout versus existing-worktree Git procedures;
   - host-specific invocation labels (Claude Code, Codex App, Codex CLI).
2. Keep workflow semantics in the existing skills. Host adapters may translate invocation, paths, and sandbox controls only; they must not change issue, spec, review, or approval policy.
3. Preserve the existing `AGENTS.md` -> `CLAUDE.md` indirection because Codex follows that instruction and changing the bootstrap would alter the established Claude contract. Pin both files in the Claude compatibility regression test.
4. Record supported environments explicitly:
   - Claude Code on macOS/Linux as the regression baseline;
   - Codex App on Windows 11 with the native PowerShell agent as the primary new target;
   - Codex under WSL2 as a supported POSIX path;
   - recent Windows 10 as best effort, matching Codex's published support position.

Exit criteria: the compatibility contract names every supported host, install scope, shell, and known security difference.

### 2. Make the shared skills runtime-neutral

1. Replace Claude-specific orchestration text in `implement-issue`, `verify-implementation`, and `research-topic` with the capability contract from Phase 1.
2. Preserve host-specific notes only in clearly labelled adapter blocks. For Codex, instruct the parent to spawn the named custom agent, pass a bounded brief, wait for completion, and consume the returned final result. For Claude, retain the equivalent `subagent_type` behavior.
3. Replace portable-shell hazards:
   - avoid `ls -R`; ask the agent to use its native file-search capability, with `Get-ChildItem -Recurse` and `find`/`rg --files` as fallbacks;
   - avoid `date +%F`; derive the current local date from the runtime, with `Get-Date -Format yyyy-MM-dd` as the PowerShell example;
   - describe directory creation as an outcome rather than requiring `mkdir -p`;
   - use body files or native argument arrays for multiline `gh` content instead of fragile shell quoting.
4. Audit every code block for PowerShell parsing, path separators, executable suffixes, and quoting. Git refs and repository-relative paths should continue to use `/` where Git expects it.
5. Update invocation language. Do not present Claude slash commands as universal; document how to select/invoke a skill in the Codex App and how `$skill-name` works in Codex CLI/IDE.
6. Add `agents/openai.yaml` to skills that need Codex App presentation or invocation policy. In particular, map Claude's `disable-model-invocation: true` intent on `create-obsidian-vault` to Codex's `policy.allow_implicit_invocation: false`. Review whether `research-topic` should receive the same policy because its own text says it is user-invoked only.

Exit criteria: a static scan finds no unlabelled Claude API call or POSIX-only operational command in shared instructions.

### 3. Add native Codex custom agents

1. Add `agents/codex/verify-implementation.toml` with:
   - the same narrow review-only mission and complete-result contract as the Claude agent;
   - `sandbox_mode = "read-only"`;
   - no pinned model by default, so the user's selected model/reasoning settings remain compatible and inheritable.
2. Add `agents/codex/research-topic.toml` with:
   - research-only instructions, source discipline, prompt-injection handling, and an explicit ban on reading local project/user files;
   - `sandbox_mode = "read-only"` to prevent mutation;
   - only documented MCP configuration that is truly required and broadly available. Do not bake in optional services such as Context7.
3. Preserve the Claude manifests byte-for-byte under `agents/*.md`; add Codex manifests under `agents/codex/`. Do not require an existing Claude installation to migrate paths.
4. Change the shared skills to degrade honestly when the named agent is not installed: run locally only where the workflow already allows it, and state when independent context or isolation is unavailable.

Security decision required during implementation: Codex's documented custom-agent schema does not currently establish the Claude research agent's web-only tool boundary. The recommended first release is functional parity with a read-only sandbox plus explicit no-local-read instructions, accompanied by a prominent limitation. If a hard technical no-local-read guarantee is mandatory, build the research step as a separate MCP/API service or another externally sandboxed process and do not call the policy-only agent equivalent.

Exit criteria: Codex can discover both custom agents, the review agent cannot write, and documentation does not claim stronger research isolation than the implementation provides.

### 4. Add a native Windows installer

1. Implement `install.ps1` with `-Target Claude|Codex|All`, `-Force`, `-DryRun`, and an optional explicit destination root for tests.
2. For Codex, install skills into `%USERPROFILE%\.agents\skills` and TOML agents into `%USERPROFILE%\.codex\agents`. For Claude, retain its current user directories.
3. Prefer directory junctions for skill directories on native Windows because they usually avoid the developer-mode/admin requirement of symbolic links. Detect unsupported cross-volume cases and offer an explicit copy mode; never silently copy when the user expects live synchronization.
4. Treat existing destinations conservatively:
   - matching link/junction: report `ok`;
   - different link/junction: skip unless `-Force`;
   - real file/directory: never overwrite, even with `-Force`;
   - dry run: perform no filesystem mutation.
5. Make replacement recoverable and narrow. Resolve and validate every destination beneath the selected install root before removing an old link.
6. Preserve `install.sh` byte-for-byte as the Claude regression baseline. Add a separate `install-codex.sh` for macOS/Linux/WSL so new behavior cannot change the existing installer contract.
7. Add a `verify-install` mode or companion script that reports discovered skills, agent manifests, broken links, and the expected restart/reload action without changing anything.

Exit criteria: repeated install and dry-run tests pass in temporary directories on Windows and Linux; real user-owned directories are never clobbered.

### 5. Make Git operations Codex-worktree-safe

1. Centralize worktree detection in the shared conventions using `git rev-parse --git-common-dir`, `git rev-parse --git-dir`, and `git worktree list --porcelain`.
2. Update `implement-issue`:
   - in a normal checkout, keep the existing fetch, fast-forward base, and feature-branch flow;
   - inside an existing Codex worktree, never create a nested worktree and do not require checking out a base branch that may be locked elsewhere;
   - after fetching, create the issue branch directly from the verified remote/base ref when appropriate, while preserving unrelated changes and refusing ambiguous dirty states;
   - account for Codex App worktrees beginning at detached `HEAD`.
3. Re-test `merge-pr` for both normal checkouts and Codex worktrees. Do not delete a worktree-bound local branch. Let the app's Handoff/worktree lifecycle remain authoritative.
4. Audit base-branch documentation and `.project/` commits so a Codex worktree does not unexpectedly switch the user's local checkout.

Exit criteria: the issue-to-PR-to-merge flow succeeds from a normal checkout and from a Codex-created worktree without branch-lock errors or unintended checkout changes.

### 6. Add validation and CI

1. Add a cross-platform static validator that checks:
   - every skill has valid YAML frontmatter with `name` and `description`;
   - skill names are unique;
   - every relative `references/`, `assets/`, and `_shared` path resolves;
   - Codex agent TOML parses and contains `name`, `description`, and `developer_instructions`;
   - no shared instruction contains an unlabelled `Agent tool`, `subagent_type`, `/skill-name`, `ls -R`, `date +%F`, or `mkdir -p` dependency;
   - `AGENTS.md` and `CLAUDE.md` resolve to the intended canonical rules.
2. Add Pester tests for `install.ps1`, including dry run, idempotency, force-replacing only links, refusal to overwrite real content, paths with spaces, and junction/copy behavior.
3. Add shell tests for `install.sh` plus ShellCheck.
4. Run CI on `windows-latest` and `ubuntu-latest`. Keep GitHub mutations mocked or confined to a disposable test repository.
5. Add behavioral smoke scenarios for skill selection and output contracts:
   - kick-off does not write before confirmation;
   - implement-issue refuses open blockers;
   - verify-implementation delegates and waits;
   - research-topic does not receive a local path in its brief;
   - merge-pr respects worktree mode.
6. Perform one manual Codex App acceptance run on native Windows with the sandbox enabled. GUI discovery, approval prompts, agent visibility, and worktree Handoff cannot be fully proven by static tests.

Exit criteria: both CI jobs pass and the manual acceptance checklist records the Codex App version, Windows version, sandbox mode, and observed results.

### 7. Rewrite onboarding and release the compatibility layer

1. Split README setup into Codex App on Windows, Codex under WSL2, Claude Code, and manual installation.
2. For Windows, document Git and GitHub CLI installation/authentication, PowerShell execution-policy caveats, sandbox mode, installer commands, verification, and restart/reload expectations.
3. Add a compatibility matrix showing which features have full, functional-with-limitation, or unavailable parity. Highlight research-agent isolation and optional external research MCPs.
4. Add troubleshooting for junction permissions, paths with spaces, OneDrive/controlled-folder access, Git safe-directory errors, `gh` authentication, branch locks across worktrees, and PowerShell script policy.
5. After the direct install path is stable, optionally package the skills as a Codex/ChatGPT plugin for easier distribution. Treat this as a release enhancement, not a prerequisite for local Codex App support; custom-agent delivery and the research security boundary still need separate verification.

Exit criteria: a new Windows user can install, verify, invoke, run through one issue, and uninstall or update without consulting source code.

## Proposed delivery slices

| Slice | Scope | Depends on |
|---|---|---|
| A | Contract, self-contained `AGENTS.md`, runtime-neutral shared instructions | None |
| B | Codex TOML agents and Codex App skill metadata | A |
| C | `install.ps1`, extended `install.sh`, verification/uninstall behavior | A, B |
| D | Worktree-safe Git workflow | A |
| E | Validators, installer tests, Windows/Linux CI | B, C, D |
| F | README, compatibility matrix, manual Codex App acceptance | E |
| G | Optional plugin packaging | F |

Slices C and D can be implemented in parallel after A/B. Slice G should remain separate so plugin packaging cannot delay basic local compatibility.

## Definition of done

- Codex App on Windows discovers all intended skills and both Codex custom agents after the documented install/reload flow.
- The complete workflow works with PowerShell and `gh`: kick-off, issue creation, implementation, independent review, comment handling, merge, status, meeting, migration, Obsidian index, research, and branding.
- Normal checkout and Codex App worktree flows both preserve unrelated user changes and never delete a worktree-bound branch.
- Claude Code and POSIX installation continue to work.
- Dry-run and force behavior never overwrite real user files or directories.
- Tests pass on Windows and Linux, and one native Codex App smoke run is recorded.
- Documentation clearly distinguishes functional behavior from security guarantees, especially for research-agent local-read isolation.

## Official Codex references used for the plan

- [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Subagents and custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [ChatGPT desktop app for Windows](https://learn.chatgpt.com/docs/windows/windows-app)
- [Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox)
- [WSL](https://learn.chatgpt.com/docs/windows/wsl)
- [Git worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees)
