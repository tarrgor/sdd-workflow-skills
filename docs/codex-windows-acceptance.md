# Codex App on Windows acceptance checklist

Record one completed run before release. Do not use a production repository for the destructive workflow checks.

## Environment

- Date:
- Windows version:
- ChatGPT desktop app / Codex version:
- Agent environment: Windows native / WSL2
- Sandbox mode: elevated / unelevated
- Permission mode:
- Git version:
- GitHub CLI version and authentication status:

## Installation

- [ ] `./install.ps1 -DryRun` reports `%USERPROFILE%\.agents\skills` and `%USERPROFILE%\.codex\agents` without writing.
- [ ] `./install.ps1` creates skill junctions and the two managed Codex agent files.
- [ ] A new Codex task lists the skillz-lattice skills.
- [ ] Codex can select `verify-implementation` and `research-topic` as custom agents.
- [ ] A repeated install reports existing junctions as `ok` and does not overwrite an unmanaged collision.

## Workflow

- [ ] `kick-off` waits for explicit confirmation before writing a spec.
- [ ] `create-spec-issues` creates or reuses a milestone and produces issues with checkable acceptance criteria.
- [ ] `implement-issue` refuses an issue with an open `Depends on` blocker.
- [ ] `implement-issue` succeeds from a normal checkout.
- [ ] `implement-issue` succeeds from a Codex-created worktree that began at detached `HEAD`.
- [ ] `verify-implementation` runs in a separate agent thread, requests its read-only default, returns complete findings, and does not edit or post. Record any parent runtime override that supersedes the agent's sandbox default.
- [ ] `check-pr-comments` changes only the existing issue branch.
- [ ] `merge-pr` does not delete or switch a worktree-bound local branch.
- [ ] `project-status`, `project-meeting`, `migrate-project`, `create-obsidian-vault`, and `generate-branding` complete their documented read/write boundaries.
- [ ] `research-topic` receives established project facts as text rather than local paths and performs no observed local reads or writes. Record that this is behavioral validation, not proof of a web-only technical boundary.

## Safety and cleanup

- [ ] Approval prompts appear for network access and writes outside the workspace as configured.
- [ ] Paths containing spaces work.
- [ ] `./install.ps1 -Uninstall` removes only junctions targeting this repository and files with the managed header.
- [ ] Existing user files, directories, skills, and custom agents survive install, force, and uninstall collision tests.

## Result

- Overall: pass / fail
- Failures and evidence:
- Follow-up issue numbers:
