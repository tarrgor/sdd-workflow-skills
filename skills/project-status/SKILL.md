---
name: project-status
description: This skill should be used to report where the project stands and recommend the single next workflow action. Trigger phrases include "project status", "where do we stand", "what's next", "what should I do next", or whenever the user wants an overview of milestone progress, open PRs, and pending findings. Reports and recommends; its only write is `STATUS.html` at the project root.
---

# Project Status

Reports where the project stands and recommends exactly one next action. Read-only except for `STATUS.html` at the project root (§4) and its `.gitignore` line: no other file writes, no `gh` mutations.

Milestone naming, the `Status:` lifecycle, and the `Depends on #N` format are defined in `../_shared/conventions.md` (relative to this skill's directory).

## 1. Gather

- **Active milestone**: read the `Status:` headers of `.project/SPEC-milestone-*.md` and pick the `Active` one (legacy fallback per conventions). Note any spec still `Planned`.
- **Milestone progress**: `gh issue list --milestone "<title>" --state all --json number,title,state,body` — open/closed counts; parse `Depends on #<number>` lines in open issues to spot blocked ones.
- **Open PRs**: `gh pr list --json number,title,headRefName`, filtered to `issue/*` branches; check `gh pr checks <number>` and unresolved review threads for each.
- **Findings**: count `.project/Inbox/findings-*.md`; note any that look critical from a skim.
- **Last meeting**: newest `.project/Archive/MEETING-<YYYY-MM-DD>.md` by filename date.

## 2. Report

One compact summary: active milestone with x/y issues closed, open PRs and their state, Inbox findings count, last meeting date. Flag anything unusual (blocked issues, a `Planned` spec without issues, a finished milestone still open).

## 3. Recommend exactly one next action

First match wins:

1. Any critical Inbox finding, or three or more pending → `project-meeting`.
2. An open PR with unresolved feedback or failing checks → `check-pr-comments` for that PR.
3. An open PR that is clean → `merge-pr` for that PR.
4. An open issue whose `Depends on` blockers are all closed → `implement-issue #<n>` (lowest such number).
5. A `Planned` spec with no issues yet → `create-spec-issues`.
6. Milestone fully closed (or no active spec) → `kick-off` the next milestone; note if the GitHub milestone still needs closing (merge-pr's job).

## 4. Write `STATUS.html`

Render the report as `STATUS.html` at the project root (the git work-tree root, else the current directory) — overwritten every run, read by nothing. Never write the HTML by hand: build one JSON object and run `../_shared/scripts/status-page.py` (relative to this skill's directory), which fills `../_shared/status-template.html`:

```
python3 <script> <project-root> <report.json>
```

Write the JSON to a temp file outside the project (or pipe it on stdin with no file argument) — never inline in a command argument; titles are user-written. Python per `runtime-adapters.md`. Values are the report's own readings; omit keys with nothing to show.

| Key | Holds |
|---|---|
| `generated` | today, `YYYY-MM-DD` |
| `project` | `name`, `repo` (`owner/name`), `base` (base branch) |
| `milestone` | active milestone `title`, `closed`, `total`; `null` if none |
| `planned` | titles of `Planned` specs |
| `next` | `action` (one line), `skill`, `command` (e.g. `/implement-issue 12`); `null` if nothing is outstanding |
| `issues` | per milestone issue, by number: `number`, `title`, `state` — `closed`, `in-review` (open PR), `blocked` (open `Depends on` blocker), else `ready` — and `blocked_by` (open blocker numbers) |
| `prs` | `number`, `title`, `branch`, `checks` (`passing`/`failing`/`pending`/`none`), `unresolved` (thread count) |
| `findings` | `count`, `critical` (one line each) |
| `last_meeting` | date of the newest meeting archive |
| `flags` | the unusual things §2 flagged, one line each |

Ensure the root `.gitignore` contains `STATUS.html` (append only if missing; create the file if absent) so the page never dirties the work tree. A failed write never blocks the recommendation: report the script's error in one line and continue. End with the page's path.
