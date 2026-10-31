# run-milestone design

Status: Draft — all decisions settled.

## Goal

A coordinator skill, `run-milestone`, that keeps working through a milestone's ready issues without the user at the keyboard, and stops as soon as the next interactive `project-meeting` is due. The user's role moves from triggering every step to granting a bounded mandate up front and making decisions in meetings.

## Non-goals

- No direction decisions. The coordinator never creates or edits issues, never edits specs, never closes milestones, never resolves Inbox findings. Those stay with `project-meeting`, `create-spec-issues` and `kick-off`.
- No code. The coordinator does not implement, review or fix anything itself; every unit of work runs in a session that uses the existing skills.
- No CI babysitting. Where the host already watches a PR's CI and fixes failures (Claude Code desktop's Auto-fix), the coordinator relies on it instead of building a second loop.

## How a run works

```
run-milestone
  │ read run policy (D1, D2, D4, D6)
  ▼
┌─► decide next action (shared rule, Prerequisite B)
│     ├─ meeting due / nothing ready / milestone done ──► stop: summary + notify
│     ├─ clean PR ──► gate check (D1) ──► merge-pr ──► full test suite on base
│     ├─ PR with unresolved feedback ──► session: check-pr-comments, non-interactive
│     └─ ready issues ──► estimate each (D6) ──► pick up to N without file overlap (D2)
│                          └─► one session per issue, own worktree, chosen model:
│                               implement-issue in non-interactive mode (Prerequisite A)
│
└── session finishes ──► verify the result yourself (PR exists, Closes #N, review outcome)
                          ├─ ok ──────────────► back to decide
                          ├─ needs-decision ──► issue parked, finding in Inbox
                          └─ failed ──────────► retry once, then park (D8)
```

Stop conditions, checked before every new start:

1. A meeting is due (D4).
2. No issue is ready (all remaining ones blocked or parked).
3. All milestone issues are closed — the meeting decides on closing it.
4. The host stops continuing the loop (see Host constraints).

On stop, the coordinator writes a run report (`.project/Reports/run-<YYYY-MM-DD>-<n>.md`: issues merged, parked, failed, findings raised, why it stopped), sends a notification where the host supports one, and names `project-meeting` as the next step when a meeting is the reason.

## Decisions

Each decision records what was decided and, where it matters, what was rejected and why.

### D1 — Merge authority

**Decided: merge autonomously, behind gates.** The coordinator runs `merge-pr` only when the PR targets the base branch, the independent review left no unresolved finding of high severity (read from the session's result line — the review's findings are not stored anywhere else), and no Inbox finding names this issue as blocking. CI is not part of the gate: the project may have none. The implementing session's own build/test run is the check, and the coordinator re-runs the full test suite on the base branch after each merge. If the base branch is the repository's default branch (no `develop`), autonomous merge additionally requires an explicit opt-in in the run policy.

Rejected: stopping at "PR ready" (dependent issues stay blocked until the user merges, so a run rarely gets past the first layer of the dependency graph); merging without gates.

### D2 — Parallelism

**Decided: default 2, maximum 3 concurrent sessions,** with a file-overlap gate: two issues run in parallel only if the files `estimate-issue` names for them don't intersect. Overlapping issues queue.

Rejected: strictly sequential (slowest); unbounded (merge conflicts and token cost grow faster than throughput).

### D3 — Run budget

**Decided: no budget.** No cap on issues per run or merges between meetings; the run continues until a meeting is due (D4) or another stop condition applies. The Inbox threshold is the only brake on drift.

### D4 — When is a meeting due

**Decided: any critical finding, or three or more pending — counting findings on open PR branches as well as on the base branch.** `implement-issue` writes `.project/Inbox/findings-*` on the issue branch, so a count over the base branch alone misses everything not yet merged. A critical finding stops the run at once, even mid-batch (running sessions finish; nothing new starts).

### D5 — Hosts

**Decided: Claude Code desktop only for now.** It is the host where the coordinator can start a session per issue, each in its own worktree with its own model, that the user can open and steer. On any other host — Claude Code CLI, Codex — the skill says it is unsupported there and stops. Codex support is assessed separately later.

The coordinator still describes starting work as one operation in `runtime-adapters.md` — *start an isolated unit of work in its own worktree, with a given model, and receive its result* — so another host can be added by mapping that operation, without rewriting the loop.

The conventions rule "this workflow does not implement issues in subagents" stays: the coordinator starts sessions, not subagents. `runtime-adapters.md` § Model selection gains the case of a coordinator setting the model on a session it starts.

### D6 — Model per issue

**Decided: the coordinator runs `estimate-issue` per ready issue and starts each unit of work with the tier's model** (per `runtime-adapters.md`) and a matching effort level. `estimate-issue`'s "User-invoked: no other skill runs it" changes to allow the coordinator as a caller. Its file list also feeds D2's overlap gate.

### D7 — Where a non-interactive skill puts its questions

**Decided: an Inbox finding plus a `needs-decision` label on the issue;** the issue is parked until the label is removed. The decision happens in the meeting, and the label makes parked issues visible in `project-status`. The finding counts toward D4's threshold.

### D8 — Failure handling

**Decided: retry a failed unit of work once, fresh; on a second failure, park the issue** with a finding describing both attempts. A failure is anything that ends without a PR, or with a PR whose build/tests fail after the session's own fixes.

### Where the run policy lives

The answers to D1, D2, D4 and D6 are durable authorisation, not per-run arguments: they go in `.project/RUN-POLICY.md`, written once with the user (by `run-milestone` on first use, after confirming each value), committed, and reviewed in meetings like any other project document. A run never widens it; the user edits it, or a meeting changes it.

## Prerequisite A — non-interactive mode

`implement-issue` and `check-pr-comments` gain a mode, set by the brief the coordinator passes, in which they never wait for the user:

| Today | Non-interactive |
|---|---|
| Ambiguity blocks a correct implementation → comment on the issue, wait | D7: finding + `needs-decision` label, stop without a branch |
| Unsafe repository state → ask | Stop and report; the coordinator parks the issue |
| Review findings disputed → "user reviews, then `check-pr-comments`" | Disputed findings go to `findings-<slug>.md`; PR stays open, not merge-eligible under D1 |
| Ends by suggesting the next skill | Ends with a machine-readable result line the coordinator parses: `RESULT: pr=<n> unresolved=<highest severity left open, or none> \| parked \| failed`, plus the reason |

Interactive behaviour stays the default and unchanged.

## Prerequisite B — one shared next-action rule

Move into `skills/_shared/next-action.md`:

- the "first match wins" list from `project-status` §3,
- the meeting-due test from `merge-pr` §6 (extended per D4),
- the "ready issue" definition (open, all `Depends on` blockers closed, not labelled `needs-decision`).

`project-status`, `merge-pr` and `run-milestone` all read it. Same change: `project-status` shows parked issues as their own state.

## Host constraints (Claude Code desktop)

Observed behaviour of the session tooling, to be confirmed while building:

- Sessions are started by the coordinator, each in its own worktree, with its own model; the user can open and steer each one.
- When a started session ends a turn, the coordinator is continued with a short report — not proof; the coordinator re-checks GitHub state itself.
- The app limits how many automated continuations it chains without a user message, and starting new sessions is restricted on turns another session triggered. A run may therefore pause before its stop conditions are met. The coordinator must be resumable: all state lives in GitHub and `.project/`, so re-running `run-milestone` continues where it stopped. Whether a long run needs a periodic nudge from the user is the main thing to verify first.
- Sessions in worktrees commit to their own branches; parallel edits to the same Knowledge entry surface as merge conflicts at merge time — `merge-pr` stops on conflict, and the coordinator parks that PR for the meeting.

## Delivery order

1. Settle D1–D8 (this document).
2. Prerequisite A and Prerequisite B — independent of each other, can run in parallel.
3. `run-milestone` skill, plus the `estimate-issue` caller change (D6), and the unit-of-work adapter (D5) in `runtime-adapters.md`.
4. README (workflow diagram, host table), validator contracts for the new skill.
5. A trial run on a small real milestone with one session at a time, before raising parallelism to D2's default.
