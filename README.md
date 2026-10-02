# Shaka

**Make agent-written PRs easier to understand and evaluate.**

Shaka guides your coding agent from task to pull request, with explanations,
verification evidence, and review decisions you can inspect before merging and
revisit afterward. It supplies the workflow for implementation, testing,
independent review, and delivery on GitHub.

[Read the Shaka documentation](https://shaka.shakacode.com/).

Shaka brings back a PR ready to merge, asks for a decision when needed, or merges
automatically when authorized and required checks and approvals pass.

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
  adversarial reviews and before-and-after screenshots for UI changes. Fix problems
  before pushing.
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
The installation prompt lets your agent check these for you. Optional ImageMagick 7
can draw [screenshot annotations and pixel diagnostics](docs/pr-verification.md#show-what-changed-between-captures).
Agents can also annotate with an existing editor or browser overlay.

See [what to expect from Shaka](docs/expected-experience.md) for setup choices,
verification gaps, and help resuming work when checks or access fail.

## Documentation

- [Start here](docs/getting-started.md) — install, configure, and run a first task.
- [Working with Shaka](docs/working-with-shaka.md) — results, decisions, and useful tips.
- [FAQ](docs/faq.md) — answers to common questions.
- [Documentation index](docs/README.md) — setup, verification, settings, and advanced guides.

[Skill references](skills/shaka/references/README.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
