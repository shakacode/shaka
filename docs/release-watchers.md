# Releases after merge

Shaka's work on a change ends when its PR merges. Promoting a release, watching
it in production, and deciding whether to roll back belong to your project.
This page shows where the PR record stops and how to pass what your release
process needs through it.

## Keep three decisions separate

| Decision | Owner | Evidence |
| --- | --- | --- |
| Merge the change | Shaka prepares it; you or your merge setting decide. | Current-commit tests, review, walkthrough, and unresolved concerns. |
| Promote the release | Your project | The exact release range, current staging results, migration and dependency checks, and approval. |
| Close the observation window | Your project | Fresh post-deployment observations, responder handoff, and any recovery verification. |

A passing PR check does not show that a deployment is healthy. A successful
deployment does not show that its observation window completed.

## What Shaka records for your release

- **Steps besides merging.** Each PR description lists work outside the code,
  with when it happens, who does it, where, and how to verify it. Put a staging
  check, backfill, or feature-flag change in an `after merge` row, so whoever
  promotes the release finds it on the PR. After a merge, the agent lists the
  rows still open. See [what you need to do](pr-verification.md#answers-for-your-next-decision).
- **Deployment link.** The description links the newest successful deployment
  or preview of the PR's current commit, or says none was found. It tells you
  which build the evidence came from, not whether production is healthy.
- **Your PR evidence guide.** Set [`project_guidance.pr_evidence`](settings.md#project_guidance)
  to ask every PR for what your release needs, such as the staging steps to
  exercise, their expected results, and cleanup. The agent reports each item in
  the description and names any gap.

## What your project owns

Shaka does not deploy, watch a release, notify a responder, or grant permission
to promote or roll back. Keep observation windows, alert thresholds, on-call
handoff, and recovery runbooks with your project, in infrastructure that keeps
running after the agent's session ends.
