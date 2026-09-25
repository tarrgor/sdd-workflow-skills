---
name: merge-pr
description: This skill should be used to merge an open, reviewed pull request back into its base branch, identified by its issue number or PR number. Trigger phrases include "merge PR #12", "merge this PR", "merge issue #12", "land this branch", or whenever an approved implementation is ready to merge.
---

# Merge PR

Merges an approved PR into its base branch and cleans up the branch — does not review or implement anything.

The base branch is whatever the PR targets: `develop` where the project has one, otherwise the default branch (typically `main`). Read it off the PR (`gh pr view <number> --json baseRefName`) rather than assuming. Milestone commands and the spec `Status:` lifecycle are defined in `../_shared/conventions.md` (relative to this skill's directory).

## 1. Identify the PR

- Accept an issue number or a PR number. If genuinely unclear, ask.
- PR number: `gh pr view <number>` directly. Issue number: find the PR whose head branch is `issue/<issue-number>-*` (`gh pr list --search "head:issue/<issue-number>-"`).

## 2. Verify it's ready

- Confirm the PR is open, targets the expected base branch, has no unresolved review threads, and has no failing required checks (`gh pr checks <number>`).
- If blocked — failing CI, unresolved comments, merge conflicts — stop and report the blocker instead of force-merging.

## 3. Merge and delete the branch

- Check whether the current directory is a linked git worktree, not the main checkout: `git rev-parse --git-common-dir --git-dir` — if the two paths differ, it's a worktree. (Also visible via `git worktree list`.)
- **Normal branch (not a worktree):** `gh pr merge <number> --squash --delete-branch`. Always use the squash merge method. Confirm the remote branch was deleted; if `--delete-branch` didn't remove it, delete it explicitly.
- If the merge is rejected by branch protection (missing approvals, required checks), stop and report what protection requires. Never bypass it with `--admin`.
- **Linked worktree:** the local branch is checked out in this worktree and bound to the session — do not delete it and do not switch it. Merge without `--delete-branch` (`gh pr merge <number> --squash`), then delete only the remote branch (`git push origin --delete <branch>`). Leave the local branch and worktree alone.

## 4. Clean up locally

Only for a normal branch (skip entirely for a linked worktree — no switch, no branch deletion, no pull there):

```bash
git switch <base>
git branch -d <head-branch>   # from gh pr view <number> --json headRefName
git pull --ff-only
```

## 5. Close the milestone if finished

- Read the closed issue's milestone (`gh issue view <issue-number> --json milestone`); skip this step if it has none.
- `gh issue list --milestone "<title>" --state open` — the just-merged issue closes via `Closes #` asynchronously, so treat it as closed even if it still shows open (re-query once if unsure).
- If no other issues remain open: close the milestone via `gh api` (number lookup + PATCH per conventions) and set the matching spec's `Status:` header to `Done`.
- Commit that `.project/` change per the base-branch rules in `../_shared/conventions.md` — the branch is usually protected, so the branch-and-PR fallback (branch `chore/close-milestone-<number>`) applies if the push is rejected.

## 6. Report

Confirm the merge and remote branch deletion. For a normal branch, also confirm the local branch was deleted and the base branch is up to date; for a linked worktree, note that the local branch was left in place. Note the issue this closed and whether the milestone closed with it.

## 7. Check the Inbox and suggest the next step

- List `.project/Inbox/findings-*.md` (skip if the folder is absent or empty).
- Recommend the user run a project meeting (`project-meeting`) if either holds: any finding is critical — needs immediate attention (e.g. security risk, data loss, broken build, blocker for other work) — or there are three or more findings pending.
- Keep it to a brief hint at the end of the report; name the critical finding(s) or the count. Do not open, triage, or act on the findings here — that is the project meeting's job.
- Otherwise, name the next open issue in the milestone whose `Depends on #<number>` blockers are all closed (lowest number) and suggest `implement-issue` for it. If the milestone just closed, suggest `project-meeting` or `kick-off` for the next milestone.
