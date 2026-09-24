# Getting started

## 1. Install Shaka

Open your coding agent and ask:

```text
Install Shaka from https://github.com/shakacode/shaka for this coding agent.
Keep the installation outside the repositories I'll work on.
Follow its installation instructions and confirm the skill is available.
```

Shaka needs Ruby 3.4 or later, Git, and an authenticated GitHub CLI. The agent
checks these and installs the skill in the appropriate directory. Start a new
chat if the skill does not appear. See [coding agents](coding-agents.md).

### Use a personal fork

A fork lets you customize Shaka and contribute improvements upstream:

```text
Fork https://github.com/shakacode/shaka into my GitHub account and install
Shaka from that fork. Keep upstream configured so we can pull updates
and submit improvements back to shakacode/shaka.
```

Use the source installation for now. The published gem is a name-reservation
prerelease and does not contain the current workflow.

## 2. Configure your repository

Open a chat in the repository you want to work on:

```text
$shaka Configure this repository for Shaka. Inspect its existing checks
and suggest the settings. Keep merge policy ask.
```

This connects the repository to Shaka through a small configuration file and
standard scripts—the repository **seam**. The agent reuses existing commands and
prepares a setup PR. Review and merge it before starting delivery.
If you invoke Shaka in an unconfigured repository, its workflow guides you through
setup; you do not need to memorize the configuration first.

See [repository setup](configure-repository.md) for the files involved.

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe.
```

Describe the outcome or provide an issue or task link. Shaka recommends a model
and effort level, then waits for your choice. To supply them up front:

```text
$shaka Fix search when the query contains an apostrophe. Use Sol, medium effort. Go.
```

Choose a model available in your coding agent. The agent verifies active settings
before proceeding; naming a model does not switch the application for you.
Testing and review are part of the workflow, so you do not need to request them
in every prompt. See [working with Shaka](working-with-shaka.md) for merge choices
and feedback.
