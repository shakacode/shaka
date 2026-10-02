# Working with Shaka

## What you get

The agent reproduces bugs, tests new behavior, runs your checks, and handles
independent review findings before pushing.

The PR description explains the outcome and decisions that need your attention.
A code walkthrough explains implementation choices and alternatives, with links
to the reviewed code. Tests, review findings, and screenshots help you evaluate
the result. Expandable sections hold usage estimates, detailed checks, and
**WIP Details** for unfinished work.

Use that record to decide whether to merge, then return to it when evaluating
the approach or how the work was checked. See
[how to read a PR for your decision](pr-verification.md#read-a-pr-for-your-decision).

The agent handles routine choices and asks about decisions affecting the product,
scope, or risk.

Your agent's permissions, project commands, and GitHub rules determine what it
can complete. Missing tests, unavailable reviewers, and access failures should
appear as concrete gaps, never as a claim of success. See the
[pilot status and limitations](expected-experience.md).

## Give it an outcome

Describe the result or provide an issue or task link. Include constraints the
agent could not infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
Keep merge policy ask. Go.
```

Examples use Codex's `$shaka`. Use `/shaka` in Claude Code, Cursor, or OpenCode;
in Pi, load the installed skill. [Install and configure Shaka](getting-started.md)
if this is your first task.

Shaka checks for existing work and recommends a model and effort level. `Go`
without naming either starts with your agent's current settings, even if they
differ from that recommendation or cannot be reported.

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | Review the ready PR, then merge it on GitHub or approve it so the agent merges. |
| **Auto** | The agent merges after required checks, review, and approvals. |

Set the choice in your prompt: `Use merge policy ask` or `Use merge policy auto`.
Repository restrictions and required approvals still apply. Trust, authentication,
release, and other consequential changes need explicit human review. A PR past the
[size limits](settings.md#mergelimits) goes back to you before the agent merges it.
Merging a feature PR does not by itself publish a package or deploy a release.

## Useful tips

- **Start small.** Pick a fix whose result you can recognize. Say what should happen
  and what should stay the same; let Shaka manage the checks and review.
- **Plan before committing to an approach.** Ask for a plan when scope or tradeoffs
  are unclear:

  ```text
  $shaka Plan CSV export for the orders page. Compare a simple download with
  a background export. Planning only; do not implement or open a PR yet.
  ```

- **Choose settings when you need to.** Activate a model in your coding agent, then
  name it in your prompt, for example `Use Sol, medium effort. Go.` A prompt cannot
  switch the model. Naming either setting can trigger a pause if it is unavailable,
  unverified, or differs from Shaka's recommendation.
- **Set a stopping point.** Ask for review only or a PR without merging when that
  is the outcome you want.
- **Keep public PRs public-safe.** Tell the agent before publication if local paths
  or chat links should be hidden. [WIP settings](settings.md#wipinclude_locations)
  control those fields; the agent still needs to inspect all published content.

## Give feedback

### On GitHub or in chat

Leave PR comments, then paste the review link into the agent chat and ask it to
address them. Or give feedback directly in chat: describe what feels wrong or show
what you want.

### In your editor

Put rough edits or voice-dictated notes beside the passage that needs attention.
An optional `Agent:` prefix distinguishes notes from finished wording.

1. Tell the agent you are editing and to keep the checkout read-only.
2. Leave your notes unstaged. Local edits and commits do not trigger GitHub CI;
   pushing to an open PR normally does.
3. Stop editing and hand over the files.
4. The agent backs up your notes outside the repository, applies the feedback,
   and validates the finished changes before pushing.
5. Resume editing when the agent hands the checkout back.

Take turns writing to the same checkout. With separate worktrees, hand over a
final diff for the agent to reconcile. Keep raw notes in the local backup.

## Resume unfinished work

Open the PR's **WIP Details** to find the owning chat, last known state, and next
action. The **Thread** link can reopen the conversation when the owner's machine
is reachable. In Codex, `codex://threads/...` takes you back to the original chat
to pick up where the agent stopped. Before another agent takes over, confirm the previous one has
stopped or handed off; a timestamp cannot prove it.

To recover after a crash or in a new chat, paste the **Next action** from WIP Details,
such as `$shaka https://github.com/OWNER/REPO/pull/N`. The agent checks the live PR
before continuing. If no PR exists, supply the original task and checkout.
See [recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Split a large change

Ask for independently useful changes as separate PRs. For example, a React on
Rails upgrade may need React 19: merge the React update first, then finish the
integration.

Each PR gets its own tests and review. The agent updates the remaining branch
after each prerequisite merges. The original chat owns the overall outcome;
no stacked-PR service is needed.

## Suggest improvements to Shaka

Tell your agent in chat what you would like Shaka to do better. For example:
“Shaka asks too many setup questions—can we simplify that?”

The agent helps refine the idea and asks before filing an issue.

## Find PRs waiting on you

| Search on GitHub | Your next action |
| --- | --- |
| `is:open label:awaiting-answer` | Answer the questions in the PR description. |
| `is:open label:awaiting-merge-approval` | Merge or approve the named commit under Ask. |
| `is:open label:awaiting-resume` | Paste the WIP Details next action into the agent chat. |

The agent manages these labels; a stopped agent can leave one stale.
See [approval and label details](pr-verification.md#approval-and-attention-labels)
when you need them.

## Squash with a useful commit message

For a squash merge, copy the title and body from the agent's last PR comment into
GitHub's merge boxes. See [squash merge details](pr-verification.md#squash-merge-details)
for repository defaults and automatic merges.
