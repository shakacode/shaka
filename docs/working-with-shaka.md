# Working with Shaka

Give Shaka the outcome you want, enough context to recognize success, and any
limits. You can start with a description, an issue number, or a task link.

```text
$shaka Fix search when the query contains an apostrophe.
Add a regression test. Keep the existing search syntax.
Bring the finished PR back for me to merge.
```

Use `/shaka` in Claude Code, Cursor, or OpenCode. Open the task in the repository
where the work belongs. If a task link points elsewhere, provide that checkout
when the agent asks.

## Choose who merges

| Preference | What happens |
| --- | --- |
| **Ask** | The agent finishes the PR and tells you which reviewed commit is ready. You merge it on GitHub. This is the default. |
| **Auto** | The agent merges after required checks and approvals pass. A consequential risk or unclear authority still needs your decision. |

To choose Auto, say: “Merge when checks and required approvals pass.” Shaka reuses
an existing choice for its agreed scope. You can also ask for **planning only**,
**review only**, or a **PR without merging**.

## What happens during a task

The agent reads the repository's instructions, checks for work already covering
the task, and recommends a model and reasoning effort. It may pause so you can
select those settings in your host. If you already specified matching settings
and asked it to start, it can proceed once they are active.

For a behavior change, the agent tries to reproduce the failure before fixing it.
It runs the repository's checks, obtains an independent review, and addresses
findings. Routine implementation choices stay with the agent. Questions come
back to you when the answer changes the product, scope, or risk.

For example, an import fix might uncover invalid dates. The useful question is
whether to reject the whole file or import the valid rows. You should receive
that question before the agent builds one of those behaviors.

## Read the finished PR

The **description** tells you what changed, whether the checks passed, and what
still needs attention. The **code walkthrough** explains the implementation and
links to the reviewed code. Review and usage details are available on the same PR.

A green CI job alone does not establish that a review completed. Shaka looks for
the report and checks which commit it reviewed. See the [review reference](agents/review.md)
for waiting rules, and [usage reporting](agents/usage-reporting.md) for partial or
unknown cost figures.

## Give feedback in chat or in your editor

Continue in the same task while it owns the work. Describe what feels wrong,
supply an example, or edit the files directly and tell the agent to read the diff.
Rough notes are useful: “Explain why this helps,” “Too much detail,” or a rewritten
sentence can give the agent enough direction to finish the edit.

When editing locally, use the task's checkout and ask the agent to pause file
edits while you work. When you are done, tell it which changes are finished prose
and which are comments to resolve. The agent should preserve your edits, turn
notes into finished text, and rerun the affected checks.

## Resume interrupted work

An unfinished PR includes **WIP Details** with its owning task, last known state,
and next action. Return to that task when possible. Before a new task takes over,
confirm that the previous one has stopped or is handing over; an old timestamp
alone does not establish that.

For a larger task, ask for a useful PR split. Each PR needs its own validation and
review, and the original task stays open until the whole requested outcome is
complete. [Control towers](control-towers.md) can help when you are organizing
work across several repositories.
