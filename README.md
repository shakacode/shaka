# Shaka

Give your coding agent a task. Get a tested pull request, a plain English walkthrough, and a clear merge decision.

```text
$shaka Fix the failing search test. Bring the PR back for me to merge.
```

Shaka is useful when a task needs more than a patch. It guides one agent through the repository's instructions, a failing test when behavior changes, validation, an independent review, and fixes to review findings. The PR records what changed, which commit was checked, and what still needs attention. If a session stops midway, its recovery note helps you resume or hand off after confirming the previous owner has stopped.

For example, if a search test fails, Shaka checks the failure, changes the code, runs the repository's validation, opens a PR with a code walkthrough, and handles review feedback. You see the result and the evidence on that PR instead of reconstructing the agent's work from chat history.

## Who merges?

**Ask** means you merge the ready PR on GitHub. **Auto** lets the agent merge after required checks and approvals pass. Risky changes still come back to you. You can request review only or a PR without a merge.

## Start here

1. [Install Shaka and run a first task](docs/people/getting-started.md).
2. [See how to steer a task](docs/people/working-with-shaka.md).
3. [Check current host support](docs/people/host-support.md).

[All user guides](docs/people/README.md).

Shaka is an early public pilot. Codex is the reference host; Claude Code has one verified consumer delivery. Cursor and OpenCode have no verified consumer delivery; [host support](docs/people/host-support.md) records the current evidence for each host, including Pi.

## For agents and maintainers

The [agent documentation](docs/agents/README.md) explains the workflow, repository settings, standard scripts, review, and evidence. The [project documents](docs/project/README.md) hold packaging, release, and pilot history. The [requirements](docs/pilot-plan.md) define the pilot's scope.

[MIT licensed](LICENSE). Copyright © 2026 ShakaCode.
