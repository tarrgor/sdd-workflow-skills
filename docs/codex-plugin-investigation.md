# Codex plugin investigation

Status: experimental packaging; live installation and workflow acceptance pending.

## Evidence (2026-11-06)

Inspected OpenAI Codex source at commit `f49ae52079859e9cfff41ed92dd935d022a2da0b`:

- [Plugin manifest parser](https://github.com/openai/codex/blob/f49ae52079859e9cfff41ed92dd935d022a2da0b/codex-rs/core-plugins/src/manifest.rs): `.codex-plugin/plugin.json` supports skill paths, MCP servers, apps, hooks, and interface metadata. No custom-agent registration field was found.
- [Marketplace parser](https://github.com/openai/codex/blob/f49ae52079859e9cfff41ed92dd935d022a2da0b/codex-rs/core-plugins/src/marketplace.rs) and [fixtures](https://github.com/openai/codex/blob/f49ae52079859e9cfff41ed92dd935d022a2da0b/codex-rs/core-plugins/src/test_support.rs): `.agents/plugins/marketplace.json` supports a local source object with a repository-relative path.
- [Plugin store](https://github.com/openai/codex/blob/f49ae52079859e9cfff41ed92dd935d022a2da0b/codex-rs/core-plugins/src/store.rs): installation stages plugin files into a cache. Do not assume source edits become live automatically.
- Installed CLI `codex-cli 0.167.0-alpha.4` exposes `plugin marketplace add`, `plugin add`, `plugin list`, and `plugin remove`. Their help confirms local marketplace paths and `PLUGIN@MARKETPLACE` selectors. This is an alpha client, not evidence of a minimum stable supported version.

The public documentation endpoint could not be fetched from this environment. Source and CLI evidence do not establish support in every released desktop, IDE, or cloud client.

## Design

Keep the existing Claude plugin and both manual installers. Add Codex manifests pointing at the same repository-root package and `skills/` tree. No duplicated skills, install hooks, home-directory writes, MCP service, or credentials are needed by this package.

Codex plugin installation does not register `agents/codex/*.toml`. Skills prefer those named agents if already present, otherwise explicitly brief a fresh generic subagent. Review must stop if no separate context is available. Research may fall back to direct execution while declaring the loss of context isolation. Generic briefs impose behavioral restrictions only; do not advertise read-only sandboxing or a technical web-only tool allowlist unless the host actually enforces it.

Cloud hosts may deliver skills through resource APIs rather than local paths. A worker must receive resolvable skill instructions and bundled references; a missing resource is a compatibility failure, not permission to invent its contents. Local installation does not prove cloud sync. GitHub authentication, Python for the optional status page, and desktop chat tools remain separate runtime requirements.

## Acceptance before replacing a manual install

1. Record client version and OS. Run `codex plugin marketplace add /absolute/path/to/checkout`, then `codex plugin add sdd-workflow@sdd-workflow-skills`. Inspect `codex plugin list --marketplace sdd-workflow-skills --json` for successful installation. Do not assume this branch is available remotely before it is pushed.
2. In a new task, verify all 15 skills are discoverable once and `_shared` resources, nested references, and the status-page script are readable. Check the plugin cache contains the complete tree. Test a harmless status request against a disposable project.
3. Remove this repository's managed manual installation using its installer uninstall option. Start another task; verify discovery again. This is the decisive check that named agents are not accidentally masking a packaging gap.
4. On a disposable PR, invoke independent review. Confirm a fresh child handles the diff, returns findings, and does not edit or post. With collaboration unavailable, confirm review reports itself blocked instead of reviewing in the implementation context.
5. Research a bounded question. Confirm one child per subtopic, text-only project knowledge in each brief, no local-data access by workers, and dated sources returned to the caller. Verify direct fallback explicitly reports missing context isolation. Behavioral compliance is not proof of enforced isolation.
6. Verify existing Claude manifest validation and manual installer tests still pass. Run local acceptance on Windows and macOS/Linux before claiming cross-platform replacement.
7. Test cloud separately: identify the actual installation/account mechanism, start a fresh cloud task, verify all skills and resources are loaded without local junctions/symlinks, and repeat review/research and GitHub-access checks. Record the host and version. Until this passes, cloud support remains unverified.
8. Check update/reinstall behavior after changing a disposable skill, and verify removal. Do not promise automatic updates or live source changes without observing them. If rolling back, remove the plugin and rerun the manual installer.

`run-milestone` retains its separate desktop chat/worktree acceptance checklist; plugin packaging does not expand its supported hosts.

## Verification in this branch

Manifest/resource validation is automated by `scripts/validate-plugin.py` in the existing compatibility workflow. CLI command help was checked. No plugin was installed into the current user's configuration, and no live skill invocation, custom-agent fallback, account sync, or cloud installation has been verified yet.
