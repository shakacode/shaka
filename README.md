# Shaka

**Review the intent and the evidence, not every line.**

Give your coding agent a task. It builds, tests, and gets an independent review.
You get one PR that says what changed, how it was checked, and what is left for
you to decide.

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](docs/img/task-to-pr.svg)

[Watch the 52-second demo](https://www.youtube.com/watch?v=T6Fstx2fGJI):
a homepage cleanup from a Claude prompt to a PR with intent, screenshots, and a checkpoint.

## Why use it?

- **Review faster.** Each PR says why the change exists, how it was checked, and
  how closely to read the code.
- **See the proof and the cost.** Each check links to its result, unproven claims
  stay visible, and the PR shows available usage and cost. UI changes add
  before-and-after screenshots.
- **Catch problems before CI.** Tests and an independent review run before the
  push, so you repeat fewer CI runs.
- **Spend less time directing the process.** Describe the outcome, and Shaka
  supplies the steps.
- **Keep control of merging.** You merge by default, or
  [let the agent merge](docs/working-with-shaka.md#choose-a-merge-policy) after
  required checks and approvals.
- **Reduce prompt-injection exposure.** On public repositories, Shaka keeps comments
  from untrusted authors away from the agent. [Review safety](docs/workflow.md#trust-model)
  explains the boundary.
- **Use one workflow across projects.** Each repository
  [keeps its own](docs/configure-repository.md#use-shaka-across-projects) checks,
  reviewers, and merge policy.

[See what a Shaka PR gives you](docs/pr-verification.md#answers-for-your-next-decision).

<a id="get-started"></a>
<a id="requirements"></a>

## Install

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

See [what you need](docs/getting-started.md#1-install-shaka).
New to branches and pull requests? [Shaka in pictures](docs/shaka-in-pictures.md)
explains them and walks you through a practice task.

<a id="example-prompts"></a>

## All you need to know

| Say | What happens |
| --- | --- |
| `/shaka <task or issue link>` | Delivers the task as a PR. |
| `/shaka doctor` | Checks your setup. If it reports a problem, tell your agent to fix it. |
| `/shaka settings` | Explains this repository's settings. Ask it to change one. |
| Anything else | Ask your agent how to get Shaka to do it. |

Use `$shaka` in Codex ([other agents](docs/coding-agents.md)).

You don't need to read the docs to use Shaka. They are mostly reference for your
agent, and you can [browse them](https://shaka.shakacode.com/) anytime.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Names and logos

The MIT license covers the code and documentation. It does not grant rights to
use the Shaka or ShakaCode names or logos. ShakaCode is a registered trademark of
ShakaCode LLC in the United States. You may say that your work uses or is based on
Shaka. Give a fork or product its own name, so it does not appear to come from
ShakaCode.
