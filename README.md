# Shaka

**Take a coding task all the way to a reviewed pull request.**

Shaka gives your coding agent a repeatable workflow for implementing a change,
testing it, getting an independent review, and handling the findings. You get a PR
that explains what changed, why, and what was checked.

```text
$shaka Fix search when the query contains an apostrophe.
Add a regression test and bring the PR back for me to merge.
Use Astra, medium effort. Go.
```

For that task, Shaka guides the agent to reproduce the failure, fix it, run your
repository's checks, and have a fresh agent review the change. It then publishes
the PR and a code walkthrough, handles review feedback, and tells you when the
reviewed commit is ready to merge.

## Why use it?

- **Spend less time directing the process.** Give the agent an outcome; Shaka
  supplies the steps through testing, review, and PR delivery.
- **Avoid unnecessary CI runs.** Run tests and adversarial reviews locally, and
  inspect before-and-after screenshots for UI changes. Fix problems before
  pushing to reduce CI runs and review rounds.
- **Understand the result.** The PR explains the change and links to its checks
  and review. A code walkthrough explains the implementation choices.
- **See what a PR cost.** The PR reports available token usage and estimated
  dollar cost, including local review. Missing usage is marked unknown.
- **Keep control of merging.** Choose **Ask** to make the final GitHub merge
  click, or **Auto** to let the agent merge after required checks and approvals.
- **Resume unfinished work.** A note on the PR records the owning task, where
  it stopped, and what comes next.
- **Use your existing tools.** Shaka runs inside your coding agent, uses your
  repository's scripts, and publishes to GitHub.

## Get started

[Install Shaka](docs/getting-started.md), then open a task in your repository and
invoke `$shaka` in Codex or `/shaka` in Claude Code, Cursor, or OpenCode. Supply an
issue number, task link, or description.

Shaka needs Ruby 3.4, Git, an authenticated GitHub CLI, and a
[configured repository](docs/configure-repository.md). It is an early pilot: Codex and
Claude Code have recorded delivery trials; coverage for other coding environments is still
limited. See [development environments](docs/development-environments.md) before choosing an installation.

## Documentation

- [Getting started](docs/getting-started.md) — install and run your first task.
- [Working with Shaka](docs/working-with-shaka.md) — write a task, choose a stopping point, and give feedback.
- [Repository setup](docs/configure-repository.md) — repository settings and scripts.
- [Documentation index](docs/README.md) — references and advanced topics.

[Agent instructions](docs/agents/README.md) · [Contributor documentation](docs/contributing/README.md) · [MIT license](LICENSE)
