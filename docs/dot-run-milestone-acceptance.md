# Dot-led run-milestone acceptance

Use a disposable repository without automatic deployments and a saved Codex
Cloud configuration for it. Confirm the user's mandate, base branch and run
policy first. Do not run these trials against a project with a live run.

| Scenario | Expected evidence |
| --- | --- |
| Desktop invocation | Existing Claude Code and Codex desktop adapters retain their behavior. |
| Worker invocation | Worker gives the direct Dot invocation and performs no mutations. |
| One ready issue | One isolated cloud checkout, recorded intent and task/turn IDs, verified final-head review, one authorized merge, and passing base checks before dependents are considered. |
| Two independent issues | With `parallel: 2`, two disjoint ready issues get separate chats and checkouts. A third waits. A lower host or user limit still applies. |
| Dependency or path overlap | A dependent or overlapping issue stays queued even with a free slot. Include expected paths of pending reservations and actual diffs of open issue PRs. Newly discovered overlap prevents the affected PRs from merging until resolved. |
| Pending start / stale status | Reservation survives a restart and occupies capacity. No duplicate worker starts for the same unit. Exact unit/attempt is reconciled; inconsistent or inaccessible records pause without a speculative retry. |
| Policy lowered mid-run | With two occupied slots and a new limit of one, no additional worker starts until both slots are clear. An invalid policy blocks admissions. |
| Retry | A terminal failure leads to at most one recorded follow-up to the same chat. An approval or environment wait does not count as a failure. |
| Head changes after review | No merge with the old receipt. A new independent review pins the current head; a concurrent change fails the guarded merge. |
| Concurrent completion / stop after merge | The coordinator records both outcomes once, drains admitted work, merges serially and tests the updated base after each merge. Resume recognizes an already merged PR and completes its outstanding checks without another merge. |
| Meeting / unresolved decision | No new starts or merges once due. The Dot prepares the decision and reports it; it does not decide for the user or widen the mandate. |
| Scheduled wake | With background continuation authorized, completion is reconciled once and the single watch stops at the user gate, completion or cancellation. |
| Missing permission / automatic deployment | No work starts if required access cannot be verified; no merge triggers an unapproved deployment. |

Record actual host capability, checkouts, task/turn and journal receipts,
GitHub states, and stop reasons. A tabletop pass or package test is not a
live pass. Verify one slot first, then repeat with two isolated issue chats.
