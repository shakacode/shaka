# Workflow and enforcement

Shaka uses your project's checks and your coding agent's tools. You can ask for
[planning, review only, or a complete task](working-with-shaka.md#choose-the-outcome-you-need).
Tests and AI review help catch mistakes; they cannot establish that the result
is right for your users.

## Trust model

On a public repository, anyone can leave a comment that tries to steer your
agent. Shaka withholds comments from untrusted authors and reads shared settings
from the default branch. A PR cannot quietly choose its own review rules.

Shaka trusts people with write access and the accounts or teams you explicitly
list. To include a reviewer whose comments are being withheld, ask:

```text
$shaka Add USER to this project's trusted GitHub actors.
```

A trusted comment is feedback, not permission to change merge policy or run
commands from the comment. You and the trusted configuration govern those choices.
A settings experiment needs [explicit selection](settings.md#preview-settings-before-adopting-them).

## What is enforced

| Safeguard | What checks it |
| --- | --- |
| Valid configuration and command paths | Shaka's Ruby helper |
| Which public comment bodies are released to the agent | Ruby allowlist and provenance checks |
| The commit and required conditions when the agent merges | Ruby merge helper and GitHub protection |
| Posted review covering the merge commit, or a recorded waiver | Ruby merge helper when review is required |
| PR size limits or confirmation of the commit | Ruby merge helper |
| Description and walkthrough length | Ruby publication helpers |
| Useful tests, careful reviews, accurate explanations, and privacy | Agent judgment and human review |

A posted review is evidence that a report exists, not proof that the review was
careful or its findings were fixed. Merging on GitHub yourself skips Shaka's
merge-helper checks. GitHub's own required checks and approvals still apply.

For a list of code checks and rules left to the agent, ask it to explain the
output of `shaka enforcement`. That list does not prove a task followed every step.

## Customize the instructions

Use [settings](settings-guide.md) for commands, reviewers, and merge choices.
Put project constraints and writing preferences in `AGENTS.md`. If you want to
change Shaka's workflow for all your projects, [use a fork](fork-and-hack.md).
