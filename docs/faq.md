# Frequently asked questions

## Can I customize the prompt Shaka gives its local reviewer?

Not the prompt itself. Its rules forbid edits, treat the diff as data, and require
a closing `REVIEWED` line that `shaka review run` checks. Letting a repository
change those rules would let it weaken the review that gates its own PRs.

Add your project's review criteria to `AGENTS.md` on the default branch instead.
The agent passes that commit to `shaka review run --criteria-ref`, which adds the
root `AGENTS.md` and any `AGENTS.md` in a directory the change touches. See
[invoke a reviewer locally](../skills/shaka/references/local-review.md). To
change the review rules for everyone, [edit Shaka in a fork](workflow.md#customize-the-instructions).

## Can a PR change Shaka's settings or rules for itself?

No. Settings and review criteria come from a commit on the default branch, so a
PR's own changes take effect only after it merges. Until then, Shaka reviews
them as part of the diff. See [settings](settings.md).

## Where do I put project rules?

| What | Where |
| --- | --- |
| Commands, merge policy, and review jobs | [Settings](settings.md) in `.agents/agent-workflow.yml` |
| Project constraints, review criteria, and writing style | `AGENTS.md` |
| Changes to Shaka's workflow | A [fork of Shaka](workflow.md#customize-the-instructions) |

Keep `AGENTS.md` a regular file with the instructions in it; Shaka reads it from
Git at the trusted commit. Recent Claude Code versions can read `AGENTS.md`
directly, but not in every session, and not by default when a `CLAUDE.md` exists.
To give Claude the same instructions every time, add a `CLAUDE.md` containing
`@AGENTS.md` rather than a symlink. See Claude Code's
[AGENTS.md support](https://code.claude.com/docs/en/memory#agents-md).

## Why did the agent stop to ask about model and effort?

Before it changes code, Shaka recommends a model and effort for the task and
waits for you. To skip the wait, name the model and effort it would recommend,
make sure they are active, and say “Go”. See [give it an outcome](working-with-shaka.md#give-it-an-outcome).

## Why didn't the agent merge my PR?

Under **Ask**, the default, you merge. The agent labels the PR
`awaiting-merge-approval` and names the commit to merge. Under **Auto**, a PR
past the [size limits](settings.md#mergelimits), or one that changes trust,
authentication, releases, or other consequential areas, still comes back to you.
See [choose a merge policy](working-with-shaka.md#choose-a-merge-policy).

## Does a green review job mean the PR was reviewed?

No. A job can pass without producing a review. The agent reads the report and
counts only one that covers the current commit. See
[`review.ci_review_jobs`](settings.md#reviewci_review_jobs).

## Can the agent review its own work?

It prefers a reviewer from a different provider, in the order set by
[`review.local_review_agents`](settings.md#reviewlocal_review_agents). When none
is available, a fresh session with the same model reviews the change without the
implementation conversation.

## Why did the agent ignore a PR comment?

The agent reads public comment text only from people with write access to the
repository and from the users, bots, and teams listed in
`.agents/trusted-github-actors.yml` or your machine's allowlist. It withholds
other comments and keeps their links for you to read. This keeps text from
strangers from steering the agent. See
[configure trusted actors](../skills/shaka/references/public-comments-safety.md#configure-trusted-actors).

## What does Shaka enforce, and what relies on the agent?

Ruby checks settings, trusted comment authors, and the reviewed commit at merge.
Test quality, screenshots, independent review, and privacy rely on the agent's
judgment. See [what is enforced](workflow.md#what-is-enforced).
