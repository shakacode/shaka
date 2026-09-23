# Getting started

## 1. Ask your agent to install Shaka

Open your coding agent and paste:

```text
Install Shaka from https://github.com/shakacode/shaka for this coding
environment. Use the current main branch, check its installation instructions
and prerequisites, and keep the installation outside the projects I edit.
Confirm that the Shaka skill is available.
```

Shaka needs Ruby 3.4, Git, and an authenticated GitHub CLI. The agent checks these
and walks you through anything that requires your account or permission.

During the pilot, use `main` for current work. You can instead name an existing
tag or your own fork in the prompt. The currently published gem is an early
name-reservation prerelease; wait for a supported release before choosing that route.
See [development environments](development-environments.md) for support status.

## 2. Set up your repository

Open a task in the repository you want to work on:

```text
$shaka Configure this repository using our existing setup, tests, and validation
commands. Prepare a PR for the configuration. Keep merging at Ask.
```

Use `/shaka` in Claude Code, Cursor, or OpenCode. Skip this step if the repository
is already configured. Review and merge the setup PR before starting delivery.

## 3. Give Shaka a task

```text
$shaka Fix search when the query contains an apostrophe. Add a regression test
and bring the reviewed PR back for me to merge. Use Astra, medium effort. Go.
```

Choose an available model in your coding environment. Naming the model, effort,
and “Go” lets Shaka proceed once those settings are active. Otherwise it
recommends settings and waits for your choice.

Shaka implements the change, runs checks, obtains review, addresses findings,
and publishes a PR with an explanation of the code. You make the final merge click.

Next: [working with Shaka](working-with-shaka.md), [configuration](configure-repository.md),
or [upgrading an existing installation](migration.md).

Manual commands and installation details are in the [agent installation reference](agents/installation.md).
