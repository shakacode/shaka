# Shaka

**Give your coding agent a task. Get a tested, reviewed PR that's easy to understand.**

Shaka guides your agent through implementation, local testing, independent review,
and delivery on GitHub. You describe the outcome; Shaka supplies the workflow.

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

- **Spend less time directing the process.** Describe the outcome. Shaka supplies
  the steps through testing, review, and PR delivery.
- **Catch problems before hitting CI.** Test and review locally, including adversarial
  reviews and before-and-after screenshots for UI changes. Fix problems before pushing.
- **Make review easier.** Get a PR that's easy to review with a clear description. Screenshots
  show visible changes; a code walkthrough explains implementation choices.
- **See what a PR cost.** See available token usage and estimated cost, including
  implementation and local review data.
- **Control merging.** Choose **Ask** to merge yourself or **Auto** to let the agent
  merge after required checks and approvals. Consequential changes need human review.
- **Resume unfinished work easily.** WIP Details on the PR identify the owning agent chat,
  where it stopped, and what comes next. Supported chat links take you back to the
  owning conversation.
- **Use your existing tools.** Shaka works with your coding agent, repository scripts,
  and GitHub.

<a id="requirements"></a>

## What you need

Ruby 3.4 or later, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
[a coding agent](docs/coding-agents.md) that can load skills and run commands.
The installation prompt lets your agent check these for you. Optional ImageMagick 7
lets it add [difference images](docs/pr-verification.md#show-what-changed-between-captures)
to UI evidence.

Shaka is a public pilot. See [status and limitations](docs/expected-experience.md)
for demonstrated behavior. In particular, private setup tools exist, but a seamless
new-user private trial remains unproven.


## How it works

- **Enforcement.** Ruby and GitHub check configuration, comment trust, and merge
  conditions. The [enforcement reference](docs/workflow.md#what-is-enforced)
  identifies which steps rely on the agent.
- **A shared workflow.** The skill guides each task through planning,
  implementation, verification, review, and delivery. Repository settings supply
  your commands and merge preferences.
- **Verification.** [Tests, independent review, and visual comparisons](docs/pr-verification.md)
  show whether the work is ready. Shaka gives your agent explicit checkpoints for
  testing, review, and delivery.

## Public review safety

Shaka reads feedback from trusted reviewers and leaves other comments for
maintainer triage.

## Documentation

- [Start here](docs/getting-started.md) — install, configure, and run a first task.
- [Working with Shaka](docs/working-with-shaka.md) — results, decisions, and useful tips.
- [FAQ](docs/faq.md) — answers to common questions.
- [Documentation index](docs/README.md) — setup, verification, settings, and advanced guides.

[Skill references](skills/shaka/references/README.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
