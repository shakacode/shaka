# Shaka

**Give your coding agent a task. Get a tested, reviewed PR that's easy to understand.**

Shaka guides your agent through implementation, local testing, independent review,
and delivery on GitHub. You describe the outcome; Shaka supplies the workflow.

```text
$shaka Fix search when the query contains an apostrophe.
```

Shaka recommends a model and effort level. You can also supply them with a task link:

```text
$shaka https://linear.app/your-team/issue/APP-123/fix-search
Use Sol, medium effort. Go.
```

Use your own task link and an available model. With those settings active, `Go`
skips the model-selection question. Shaka still asks about consequential decisions.

## Why use it?

- **Catch problems before CI.** Test and review locally, including adversarial
  reviews and before-and-after screenshots for UI changes. Fix problems before pushing.
- **Make review easier.** Get a PR with evidence and a walkthrough of the changes.
- **See what a PR cost.** See available token usage and estimated cost, including local review.
- **Control merging.** Choose **Ask** to merge yourself or **Auto** to let the agent
  merge after required checks and approvals. Consequential changes need human review.
- **Resume unfinished work.** WIP Details identify the owning chat, where work
  stopped, and what comes next.
- **Use your existing tools.** Shaka works with your coding agent, repository
  scripts, and GitHub.

## Get started

[Install Shaka and configure your repository](docs/getting-started.md).

### Requirements

Ruby 3.4 or later, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
[a coding agent](docs/coding-agents.md) that can load skills and run commands.

## How it works

- **Workflow.** The skill supplies the steps; your repository supplies the commands
  and merge preferences.
- **Verification.** [Tests, independent review, and visual comparisons](docs/pr-verification.md)
  show whether the work is ready.
- **Enforcement.** Ruby and GitHub check configuration, comment trust, and merge
  conditions. The [enforcement reference](docs/workflow.md#what-is-enforced)
  identifies which steps rely on the agent.

## Documentation

- [Getting started](docs/getting-started.md) — install, configure, and run a task.
- [Working with Shaka](docs/working-with-shaka.md) — merge policy, feedback, and resuming work.
- [Repository setup](docs/configure-repository.md) and [settings](docs/settings.md).
- [Documentation index](docs/README.md) — all product guides.

[Skill references](skills/shaka/references/README.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
