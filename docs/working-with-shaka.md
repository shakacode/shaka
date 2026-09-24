# Working with Shaka

## Give it an outcome

Describe the result or provide an issue or task link. Include constraints the
agent could not infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
```

Shaka checks for existing work and recommends a model and effort level. Supply
an available model, effort, and “Go” to skip that question once the settings are
active. See the [workflow](workflow.md).

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | Review the ready PR, then merge it on GitHub or tell the agent to merge that commit. |
| **Auto** | The agent merges after required checks, review, and approvals. |

Set the choice in your prompt: `Use merge policy ask` or `Use merge policy auto`.
Repository restrictions and required approvals still apply. Trust, authentication,
release, and other consequential changes need explicit human review. Put additional
project restrictions in `AGENTS.md`; Shaka has no built-in file-count or commit-count limits.

You can also request planning only, review only, or a PR without merging.

## What you get

The agent reproduces bugs, tests new behavior, runs your checks, and handles
independent review findings before pushing.

The PR shows the result and verification. Screenshots show UI changes; a code
walkthrough explains implementation choices. Expandable sections hold usage
estimates, detailed checks, and **WIP Details** for unfinished work.
See [PR verification](pr-verification.md).

The agent handles routine choices and asks about decisions affecting the product,
scope, or risk.

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
action. When available, the **Thread** link takes you straight back: in Codex, a
`codex://threads/...` link opens the original conversation so you can pick up where
the agent stopped. Before another agent takes over, confirm the previous one has
stopped or handed off; a timestamp cannot prove it.

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
