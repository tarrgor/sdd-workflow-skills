---
name: project-status
description: This skill should be used to report where the project stands and recommend the single next workflow action. Trigger phrases include "project status", "where do we stand", "what's next", "what should I do next", or whenever the user wants an overview of milestone progress, open PRs, and pending findings. Read-only — reports and recommends, changes nothing.
---

# Project Status

Reports where the project stands and recommends exactly one next action. Read-only: no file writes, no `gh` mutations.

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
