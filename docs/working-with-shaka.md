# Working with Shaka

## Give it an outcome

Describe the result you want, or provide a GitHub issue or a task link from a
tracker such as Linear. Include constraints the agent could not infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
```

Shaka checks for existing work and recommends a model and effort level. Supply
an available model, effort, and “Go” to skip that question once the settings are
active. The [workflow](workflow.md) explains the remaining steps.

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | The agent brings back a reviewed PR and identifies the commit you can merge on GitHub. |
| **Auto** | The agent merges after required checks, review, and approvals. |

Say `Use merge policy ask` or `Use merge policy auto` in your prompt to set the
choice for that task. A prompt can change the ordinary preference; it cannot
bypass repository restrictions, GitHub protection, or required human approval.
Trust, authentication, release, and other consequential changes still require
explicit human review. Shaka has no built-in file-count threshold for switching
to Ask; put additional project restrictions in `AGENTS.md`.

You can also request planning only, review only, or a PR without merging.

## What you get

For a bug fix, the agent reproduces the failure before fixing it. For a new
behavior, it tests the expected result. It runs your checks, obtains an
independent review, and handles findings before pushing.

The PR description leads with the result and validation. Screenshots show UI
changes; the code walkthrough explains implementation choices. Expandable
sections hold usage estimates, detailed checks, and **WIP Details** for unfinished
work. See [PR verification](pr-verification.md).

Routine choices stay with the agent. It asks you when an answer changes the
product, scope, or risk.

## Give feedback

### On GitHub or in chat

Leave PR comments, then paste the review link into the agent chat and ask it to
address them. You can also give feedback directly in that chat. Describe what
feels wrong or show the result you want.

### In your editor

Rough edits and voice-dictated notes work well. Put comments next to the passage
that needs attention; an optional `Agent:` prefix distinguishes notes from final
wording.

1. Tell the agent you are editing and ask it to keep the checkout read-only.
2. Make your notes and leave them unstaged. Local edits and local commits do not
   trigger GitHub CI; pushing to an open PR normally does.
3. Tell the agent you have stopped and hand over the files.
4. The agent saves a patch and copies outside the repository, works through the
   feedback, and validates the finished changes before pushing.
5. Resume editing when the agent hands the checkout back.

Take turns writing to the same checkout. A separate clone or worktree also keeps
your drafts apart, but the agent still needs a clear handoff and a final diff to
reconcile. Raw feedback belongs in the local backup, not the published commit.

## Resume unfinished work

Open the PR's **WIP Details** to find the owning agent chat, last known state, and
next action. Return to that chat when possible. Before another agent takes over,
confirm the previous one has stopped or handed off; an old timestamp alone does
not prove that.

## Split a large change

Ask the agent to extract independently useful changes into smaller PRs. For
example, a React on Rails upgrade may need React 19: the React update can become
a prerequisite PR, merge first, and leave the main PR focused on the integration.

Shaka uses ordinary sequential PRs. Each needs its own tests and review, and the
agent updates the remaining branch after the prerequisite merges. This does not
require a stacked-PR service. The original chat owns the overall outcome.

## Suggest improvements to Shaka

When Shaka confirms a worthwhile product gap outside your task, it offers an issue
and keeps working. You can ask it to skip these offers.

The agent shows you a draft based on public sources, asks before searching for
duplicates, and asks again before filing. You inspect possible matches; the agent
rechecks them before filing and returns to you if they change. A failed or limited
search, unresolved candidates, or a repository mismatch stops filing. No search
results do not prove there are no duplicates.

The agent checks consent and sources; the issue command verifies the destination.
See the [issue-offer procedure](../skills/shaka/references/shaka-issue-offer.md).
