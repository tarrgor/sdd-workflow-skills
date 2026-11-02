# run-milestone design

Status: Built — `skills/run-milestone/SKILL.md`; first trial run pending.

Codex extension: the desktop-only adapter in `skills/run-milestone/references/codex-desktop.md` adds explicit chat/worktree authorization, default or approved per-tier models, durable issue-comment records, resumable waits, feedback capacity gates and commit-bound merge receipts. It overrides D5's original Codex exclusion only when the desktop chat tools are available. CLI/IDE remain unsupported. The Claude decisions and session loop below are retained unchanged; Codex live acceptance is tracked in `docs/codex-run-milestone-acceptance.md`.

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

**Decided: merge autonomously, behind gates.** The coordinator runs `merge-pr` only when the PR targets the base branch, the independent review left no unresolved finding of high severity (read from the session's result line, which reports the last review's verdict per D9 — the review's findings are not stored anywhere else), and no Inbox finding names this issue as blocking. CI is not part of the gate: the project may have none. The implementing session's own build/test run is the check, and the coordinator re-runs the full test suite on the base branch after each merge. If the base branch is the repository's default branch (no `develop`), autonomous merge additionally requires an explicit opt-in in the run policy.

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

**Decided: retry a failed unit of work once, fresh; on a second failure, park the issue** with a finding describing both attempts. A failure is `RESULT: failed`: anything that ends without a usable PR, including one whose build/tests fail after the session's own fixes. `skipped` and `parked` are not failures and are never retried.

### D9 — Review loop after fixes

**Decided: `implement-issue` re-reviews after fixing a high or critical finding, at most twice.** Today Step 10 fixes the valid findings once and moves on. Unattended, nobody checks that fix, and D1's merge gate would rest on the implementer's own judgment.

- Re-review only when a high or critical finding was fixed in the round before. Low and medium findings never trigger another round — the reviewer reports for coverage, so "until no findings" would never end.
- Each round is a fresh `verify-implementation` run over the whole PR, told which high or critical findings the previous round raised so it can confirm they are gone.
- At most two fix rounds (three reviews in total).
- The implementer may not dismiss a high or critical finding as not actionable on its own; a dismissed one counts as unresolved.
- Exit: nothing high or critical left → done. Cap reached with one still open → finding in the Inbox, PR not merge-eligible under D1. The reviewer reports the approach itself as wrong → stop at once, finding in the Inbox, issue parked (D7); fixes don't converge on a wrong approach.
- The last review's verdict is what the result line reports, not the implementer's assessment.

Applies in both modes, as one condition in Step 10, so the skill keeps a single path. Only the ending differs by mode (Prerequisite A).

### Where the run policy lives

The answers to D1, D2, D4 and D6 are durable authorisation, not per-run arguments: they go in `.project/RUN-POLICY.md`, written once with the user (by `run-milestone` on first use, after confirming each value), committed, and reviewed in meetings like any other project document. A run never widens it; the user edits it, or a meeting changes it.

## Prerequisite A — non-interactive mode

`implement-issue` and `check-pr-comments` gain a mode, set by `mode: non-interactive` in the brief the coordinator passes, in which they never wait for the user. The rules and the result line are defined once, in `conventions.md` § Non-interactive mode:

| Today | Non-interactive |
|---|---|
| Ambiguity blocks a correct implementation → comment on the issue, wait | Park (D7): `needs-decision` label; the finding goes on the issue branch, or — before a branch exists — into the final message for the coordinator to file |
| Precondition not met (open blocker, existing PR) → tell the user | Stop without changes: `RESULT: skipped` |
| Unsafe repository state → ask | Stop and report; the coordinator parks the issue |
| Review findings disputed → "user reviews, then `check-pr-comments`" | Disputed findings go to `findings-<slug>.md`; PR stays open, not merge-eligible under D1 |
| Ends by suggesting the next skill | Commits and pushes anything still uncommitted, then ends with one result line: `RESULT: pr=<n> unresolved=<critical\|high\|none>`, `RESULT: parked`, `RESULT: skipped` or `RESULT: failed`, each with a reason |

Interactive behaviour stays the default and, apart from the D9 review loop, unchanged.

## Prerequisite B — one shared next-action rule

`skills/_shared/next-action.md` holds what `project-status`, `merge-pr` and `run-milestone` decide on:

- the issue states — parked (`needs-decision`), blocked, in review, ready;
- pending findings — the base branch's Inbox plus the Inbox files each open `issue/*` PR adds or changes (D4);
- the meeting-due test;
- the "first match wins" next-action order, with one new rule: no ready issue but a parked one → `project-meeting`.

`project-status` shows parked issues as their own state on `STATUS.html`.

## Implementation notes

Details settled while building `skills/run-milestone/SKILL.md`, after an independent review of the first draft:

- **Sessions record their own outcome on GitHub labels,** so a run that is interrupted loses nothing: the session removes `in-progress` from its issue and, when the last review left nothing high or critical open, adds `verified` to its PR. The D1 gate reads `verified`. `needs-decision` parks (D7).
- **D7, refined:** a question raised before a PR exists is posted as an issue comment starting with `needs-decision:`; the coordinator files it in the Inbox, and until then it already counts as a pending finding. With a PR, the finding goes on the branch as before.
- **D8, refined:** the retry is a follow-up message to the same session, not a fresh one — a fresh session would collide with the branch the first one created. A second failure stops the session and parks the issue. `skipped` parks too, so a precondition problem can't be picked again.
- **Feedback is review threads only.** `check-pr-comments` now resolves the threads it addressed (both modes — before, `merge-pr`'s "no unresolved threads" check could never pass after it). In non-interactive mode it parks on threads it won't act on, and runs one independent review before reporting, so its fixes don't merge on its own judgment.
- **Merge blockers end the attempt:** when `merge-pr` stops (conflict, protection), the coordinator removes `verified`, records a finding and leaves the PR for the meeting.
- **Overlap gate input:** `estimate-issue` now lists the files it expects to change; the coordinator compares them against running sessions and open PRs.
- **Pending findings** count every open PR, not only `issue/*` ones — the coordinator's own findings may land via a PR when the base branch is protected; the base-branch fallback now switches back to the base afterwards.
- **Model cap:** the desktop app starts a session only on the coordinator's model or a cheaper one. Run the coordinator on the largest model the milestone needs; issues whose tier is above it run at the coordinator's level, and the run report lists them.
- **Permission mode:** sessions inherit the coordinator's. In a mode that asks before `git`/`gh`, sessions wait on prompts; the skill says so before starting.
- **Branches in other worktrees:** `merge-pr` merges without deleting the local branch when the head branch is checked out in another worktree; `check-pr-comments` works on such a branch detached (`runtime-adapters.md` § Git worktrees).
- **Refused session starts:** the coordinator stops starting, lets running sessions finish, and reports the refusal as the stop reason; re-running resumes.

## Host constraints (Claude Code desktop)

Observed behaviour of the session tooling, to be confirmed while building:

- Sessions are started by the coordinator, each in its own worktree, with its own model; the user can open and steer each one.
- When a started session ends a turn, the coordinator is continued with a short report — not proof; the coordinator re-checks GitHub state itself.
- The app limits how many automated continuations it chains without a user message, and starting new sessions is restricted on turns another session triggered. A run may therefore pause before its stop conditions are met. The coordinator must be resumable: all state lives in GitHub and `.project/`, so re-running `run-milestone` continues where it stopped. Whether a long run needs a periodic nudge from the user is the main thing to verify first.
- Sessions in worktrees commit to their own branches; parallel edits to the same Knowledge entry surface as merge conflicts at merge time — `merge-pr` stops on conflict, and the coordinator parks that PR for the meeting.

## Delivery order

1. Settle D1–D9 (this document).
2. Prerequisite A (with the D9 review loop) and Prerequisite B — independent of each other, can run in parallel.
3. `run-milestone` skill, plus the caller changes in the descriptions of `estimate-issue` (D6) and `check-pr-comments` (both say user-invoked only), and the unit-of-work adapter (D5) in `runtime-adapters.md`.
4. README (workflow diagram, host table), validator contracts for the new skill.
5. A trial run on a small real milestone with one session at a time, before raising parallelism to D2's default.
