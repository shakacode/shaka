# Shaka

**Review the intent and the evidence, not every line.**

[Read the guides and see example PRs at shaka.shakacode.com](https://shaka.shakacode.com/).

Give your coding agent a task. Shaka guides it through implementation,
verification, independent review, and PR delivery. Each PR shows:

- **Intent:** why the change exists, what it leaves out, and why it is safe.
- **Verification:** the checks that prove the change and any claim left unproven.
  Each check links to its result or names the command that ran.
- **UI evidence:** for a UI change, annotated before-and-after screenshots, plus
  a video when timing matters.
- **Review effort:** how carefully to read the code, from the description alone
  to every line. When a few lines need a closer look, walkthrough notes can
  point them out.

Then you approve the change, request revisions, or resolve an open question.

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](docs/img/task-to-pr.svg)

The agent builds, verifies, and reviews, fixing what it can. Then you review one clear
PR: what changed, how it was checked, and what is still open. At the
[checkpoint](https://shaka.shakacode.com/docs/pr-verification#checkpoint), decide what happens next.

[Watch the 52-second demo](https://www.youtube.com/watch?v=T6Fstx2fGJI):
a homepage cleanup from a Claude prompt to a PR with intent, screenshots, and a checkpoint.

<a id="example-prompts"></a>
<a id="get-started"></a>

## Start with a small task

[Install Shaka](https://shaka.shakacode.com/docs/getting-started), then give it a task:

```text
$shaka <task or issue link>
```

Examples use Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode; in Pi,
load the installed skill. You can describe an outcome or provide an issue link.
If setup is missing, Shaka asks whether you want individual or team settings,
finds your existing checks, and defaults to Ask.
`Go` starts with your agent's current model and effort settings.
[Working with Shaka](https://shaka.shakacode.com/docs/working-with-shaka) covers practical prompts,
merge choices, feedback, and resuming work.

New to branches and pull requests? [Shaka in pictures](https://shaka.shakacode.com/docs/shaka-in-pictures)
explains them and walks you through a practice task.

## Why use it?

- **Catch problems before hitting CI.** Test and review locally, including
  adversarial review, then fix problems before pushing. Fewer repeat CI runs can
  lower costs and shorten CI queues.
- **Make review easier.** Get a clear PR description, screenshots showing visible
  changes, and a code walkthrough explaining implementation choices and alternatives.
- **See what was checked and what it cost.** Find the tested revision, review
  findings, verification gaps, and available model, usage, and cost information.
- **Reduce prompt-injection exposure in open source.** Shaka’s comment reader
  withholds untrusted authors’ comments from the agent for maintainer triage.
  [Review safety](https://shaka.shakacode.com/docs/workflow#trust-model) explains the boundary.
- **Use one workflow across projects.** Each repository configures its own checks,
  reviewers, and merge policy. [Repository setup](https://shaka.shakacode.com/docs/configure-repository#use-shaka-across-projects)
  connects Shaka to your existing tools.
- **Control merging.** Choose **Ask** to merge yourself or approve the agent's merge,
  or **Auto** to let it merge after required checks and approvals.
  Consequential changes need human review.
- **Spend less time directing the process.** Describe the outcome. Shaka supplies
  the steps using your coding agent, repository scripts, and GitHub. WIP Details
  identify unfinished work and the next action when you need to resume.

[See what a Shaka PR gives you](https://shaka.shakacode.com/docs/pr-verification#read-a-pr-for-your-decision).

<a id="requirements"></a>

## What you need

Ruby 3.4 or later, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
[a coding agent](https://shaka.shakacode.com/docs/coding-agents) that can load skills and run commands.
The installation prompt lets your agent check these for you.

See [what to expect from Shaka](https://shaka.shakacode.com/docs/expected-experience) for setup choices,
verification gaps, and help resuming work when checks or access fail.

## Documentation

- [Start here](https://shaka.shakacode.com/docs/getting-started) — install, configure, and run a first task.
- [Working with Shaka](https://shaka.shakacode.com/docs/working-with-shaka) — results, decisions, and useful tips.
- [Workflow and review safety](https://shaka.shakacode.com/docs/workflow) — the process, trusted feedback, and what checks enforce.
- [FAQ](https://shaka.shakacode.com/docs/faq) — answers to common questions.
- [Documentation index](https://shaka.shakacode.com/docs/) — setup, verification, settings, and advanced guides.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Names and logos

The MIT license covers the code and documentation. It does not grant rights to
use the Shaka or ShakaCode names or logos. ShakaCode is a registered trademark of
ShakaCode LLC in the United States. You may say that your work uses or is based on
Shaka. Give a fork or product its own name, so it does not appear to come from
ShakaCode.
