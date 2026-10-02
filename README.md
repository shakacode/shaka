# Shaka

**Make agent-written PRs easier to understand and evaluate.**

Shaka guides your coding agent through implementation, testing, independent
review, and PR delivery. Get clear explanations and evidence to support your
merge decision—and revisit the reasoning afterward.

[Read the Shaka documentation](https://shaka.shakacode.com/).

<a id="example-prompts"></a>
<a id="get-started"></a>

## Start with a small task

[Install Shaka and ask it to configure your repository](docs/getting-started.md).
The agent prepares shared settings using your existing checks. You review the
choices and merge the first setup PR, then give it a task:

```text
$shaka Fix search when the query contains an apostrophe.
Keep merge policy ask. Go.
```

Examples use Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode; in Pi,
load the installed skill. You can describe an outcome or provide an issue link.
`Go` starts with your agent's current model and effort settings.
[Working with Shaka](docs/working-with-shaka.md) covers practical prompts,
merge choices, feedback, and resuming work.

## Why use it?

- **Catch problems before hitting CI.** Test and review locally, including
  adversarial review, then fix problems before pushing. Fewer repeat CI runs can
  lower costs and shorten CI queues.
- **Make review easier.** Get a clear PR description, screenshots showing visible
  changes, and a code walkthrough explaining implementation choices and alternatives.
- **Revisit decisions after merging.** Use the recorded rationale and review
  responses to assess the approach and how concerns were handled.
- **See what was checked and what it cost.** Find the tested revision, review
  findings, verification gaps, and available model, usage, and cost information.
- **Control merging.** Choose **Ask** to merge yourself or approve the agent's merge,
  or **Auto** to let it merge after required checks and approvals.
  Consequential changes need human review.
- **Spend less time directing the process.** Describe the outcome. Shaka supplies
  the steps using your coding agent, repository scripts, and GitHub. WIP Details
  identify unfinished work and the next action when you need to resume.

[See what a Shaka PR gives you](docs/pr-verification.md#read-a-pr-for-your-decision).

<a id="requirements"></a>

## What you need

Ruby 3.4 or later, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
[a coding agent](docs/coding-agents.md) that can load skills and run commands.
The installation prompt lets your agent check these for you.

See [what to expect from Shaka](docs/expected-experience.md) for setup choices,
verification gaps, and help resuming work when checks or access fail.

## Documentation

- [Start here](docs/getting-started.md) — install, configure, and run a first task.
- [Working with Shaka](docs/working-with-shaka.md) — results, decisions, and useful tips.
- [Workflow and review safety](docs/workflow.md) — the process, trusted feedback, and what checks enforce.
- [FAQ](docs/faq.md) — answers to common questions.
- [Documentation index](docs/README.md) — setup, verification, settings, and advanced guides.

[Skill references](skills/shaka/references/README.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
