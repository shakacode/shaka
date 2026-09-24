# Getting started

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka for this coding agent.
Keep the installation outside the repositories I'll work on.
Follow its installation instructions and confirm the skill is available.
```

The agent checks for Ruby 3.4 or later, Git, and an authenticated GitHub CLI.
Start a new chat if the skill does not appear. See [coding agents](coding-agents.md)
for environment-specific setup.

Use a source installation: the published gem is a name-reservation prerelease
without the current workflow.

### Use a personal fork

To customize Shaka and contribute improvements upstream:

```text
Fork https://github.com/shakacode/shaka into my GitHub account and install
Shaka from that fork. Keep upstream configured so we can pull updates
and submit improvements back to shakacode/shaka.
```

## 2. Configure your repository

First confirm that GitHub requires a CI check on your default branch. A private
repository on the GitHub Free plan cannot do this. See
[before you start](configure-repository.md#before-you-start).

Open a chat in your project:

```text
$shaka Configure this repository for Shaka. Inspect its existing checks
and suggest the settings. Keep merge policy ask.
```

The agent connects your existing commands to Shaka through a configuration file
and standard scripts—the repository **seam**. Review and merge its setup PR
before starting work. Shaka also offers setup when invoked in an unconfigured
repository. See [repository setup](configure-repository.md).

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe.
```

Describe the outcome or supply a task link. Shaka recommends a model and effort
level. To choose them up front:

```text
$shaka Fix search when the query contains an apostrophe. Use Sol, medium effort. Go.
```

Choose an available model and activate it in your coding agent; the prompt does
not switch it for you. Testing and review are already part of the workflow.
See [working with Shaka](working-with-shaka.md) for merge choices and feedback.
