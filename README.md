# Shaka

**Give your coding agent a task. Get a tested, reviewed PR that's easy to understand.**

Shaka guides the work from the first question through implementation, local tests,
independent review, and delivery on GitHub. You spend less time directing the
process and checking whether the agent finished the job.

```text
$shaka Fix search when the query contains an apostrophe.
```

Shaka checks for existing work, considers whether the change is worth doing, and
recommends a model and effort level. You can also give it an issue or task link:

```text
$shaka https://linear.app/your-team/issue/APP-123/fix-search
Use Sol, medium effort. Go.
```

Replace the example link and choose a model available in your coding agent.
When those settings are active, Shaka starts without another model-selection
question. It still brings you decisions that need your input.

## Why use it?

- **Spend less time directing the process.** Describe the outcome. Shaka supplies
  the steps through testing, review, and PR delivery.
- **Avoid unnecessary CI runs.** Run tests and adversarial reviews locally, and
  inspect before-and-after screenshots for UI changes. Fix problems before
  pushing to reduce CI runs and review rounds.
- **Make review easier.** The PR leads with the result and evidence. Screenshots
  show visible changes; a code walkthrough explains implementation choices.
- **See what a PR cost.** Find available token usage and estimated dollar cost,
  including local review, in the PR. Missing usage is marked unknown.
- **Control merging.** Choose **Ask** to merge on GitHub yourself, or **Auto** to
  let the agent merge after checks and required approvals. Consequential changes
  still need explicit human review.
- **Resume unfinished work.** WIP Details on the PR identify the owning agent chat,
  where it stopped, and what comes next.
- **Use your existing tools.** Shaka uses your coding agent and repository scripts.
  It currently delivers PRs through GitHub.

## Get started

[Install Shaka and configure your repository](docs/getting-started.md).
The guide gives you prompts for both steps, including an optional personal fork.

### Requirements

Ruby 3.4 or later, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
[a coding agent](docs/coding-agents.md) that can load skills and run commands.
Your repository's default branch must require at least one CI check on GitHub; see
[before you start](docs/configure-repository.md#before-you-start).

## How it works

- **A shared workflow.** The skill guides each task through planning,
  implementation, verification, review, and delivery. Repository settings supply
  your commands and merge preferences.
- **Evidence before delivery.** Tests, independent review, and visual comparisons
  help you judge the result. See [PR verification](docs/pr-verification.md).
- **Explicit enforcement.** Ruby helpers check configuration, filter public
  comments, and enforce merge conditions alongside GitHub. Some steps still rely
  on the agent; the [enforcement reference](docs/workflow.md#what-is-enforced)
  shows the distinction.

## Documentation

- [Getting started](docs/getting-started.md) — install, configure, and run a task.
- [Working with Shaka](docs/working-with-shaka.md) — merge policy, feedback, and resuming work.
- [Repository setup](docs/configure-repository.md) and [settings](docs/settings.md).
- [Documentation index](docs/README.md) — all product guides.

[Skill references](skills/shaka/references/README.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
