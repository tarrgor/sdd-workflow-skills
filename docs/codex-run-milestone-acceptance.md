# Codex milestone acceptance

Status: live desktop trial pending. Static compatibility checks do not prove chat creation, permissions, completion delivery or recovery. Use a disposable GitHub project and explicitly authorize its chats, worktrees, comments, pushes and merges before the trial. Do not run these scenarios against production as a side effect of validating the skill.

Record app/host version, OS, permission mode, Git/gh versions, repository, base branch, milestone, model policy and coordinator chat ID. Start with `parallel: 1`; confirm `.project/RUN-POLICY.md` and the required independent review agent.

| Scenario | Expected observation |
|---|---|
| No chat tools / CLI / IDE | Unsupported before any label, file, chat or GitHub mutation; no implementation-subagent fallback. |
| Missing versus existing mandate | Ask only for missing chat/worktree/message/model or merge authorization; a confirmed mandate is reused. |
| Default versus tier models | Default omits model/effort overrides; approved exact IDs are used; unavailable IDs pause without downgrade. |
| Successful implementation | Separate chat/worktree, issue branch, tests, independent review, receipt and final RESULT; merge targets the receipt SHA; base tests pass. |
| Code-free issue | Explicit review skip and final-head code-free receipt; no such exemption for executable/configuration changes. |
| Decision / high finding | Park question or publish high-severity finding; no merge; critical finding stops dispatch immediately. |
| Review fixes | Final published head, including reports, matches the independent review; at most three reviews/two fix rounds; exhausted review allowance parks. |
| Failure and retry | Exactly one follow-up to the same chat; attempt-2 intent persisted before sending; second completed failure parks. |
| Approval or unavailable host | Pause without spending a retry or releasing the reserved issue; report actual unfinished chat IDs; no pretend stop. |
| Pending creation | clientThreadId reserves a slot and is never used as threadId; real identity is resolved from matching project, unit token and prompt. |
| Lost start/retry response | Restart finds the dispatched work; uncertain delivery pauses instead of creating or messaging twice. |
| Coordinator interrupted | Resume consumes completed results once, recovers running file reservations, and preserves unrecoverable in-progress labels. |
| Receipt missing or head advanced | Remove verified, persist revalidation-needed, dispatch feedback/review even with no review threads, then require a fresh matching receipt. |
| Push between check and merge | --match-head-commit rejects stale head; no unguarded retry. |
| Merge command queues only | PR remains open: do not clean up or unblock dependants; pause/report; on confirmed merge run base tests. |
| Meeting / broken base build | No more starts or merges; drain workers or report an attention-needed pause; write run report and name the next decision. |
| Parallel implementation + feedback | Both consume slots; pending setup and retry count too; same-issue/overlapping work queues; feedback excludes only its own PR from overlap comparison. |
| Other milestone / worker worktree | No work dispatched or merged for another milestone; coordinator checkout stays on base; worker local branches/worktrees remain intact. |

After sequential cases pass, repeat the concurrency and interruption cases with `parallel: 2`. Record pass/fail, chat and issue/PR links, observed tool responses, review SHA/receipt and remaining blockers. Do not mark the adapter live-validated until these observations exist.
