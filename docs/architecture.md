# Why Shaka stays small

Shaka uses the task and GitHub as its shared record. You do not need a separate
tracking service to resume work or understand a finished change.

## Keep facts where people look for them

Keep the goal, priority, and dependencies in the issue or other work item.
For work started from a sentence, keep that context in the PR.
GitHub holds the commits, checks, reviews, and outcome.

An agent chat can hold experiments and unpushed work. Before handing work over,
ask the agent to preserve what the next person needs. A PR's
[recovery note](working-with-shaka.md#resume-unfinished-work) can identify that
work; it cannot recover files that were never saved.

## Put repeatable checks in code

When improving Shaka, use Ruby for repeatable checks and instructions for
judgment calls. Configuration validation belongs in code; deciding whether a
test meaningfully covers a user's problem needs review.
See [Developing Shaka](../contributing/development.md).
