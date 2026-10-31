# Shaka

**Review the intent and the evidence, not every line.**

Give your coding agent a task. It builds, tests, and gets an independent review.
You get one PR that says what changed, how it was checked, and what is left for
you to decide.

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](docs/img/task-to-pr.svg)

[Watch the 52-second demo](https://www.youtube.com/watch?v=T6Fstx2fGJI):
a homepage cleanup from a Claude prompt to a PR with intent, screenshots, and a checkpoint.

<a id="get-started"></a>
<a id="requirements"></a>

## Install

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

It checks [what you need](docs/getting-started.md#1-install-shaka) for you.

<a id="example-prompts"></a>

## All you need to know

| Say | What happens |
| --- | --- |
| `/shaka <task or issue link>` | Delivers the task as a PR. |
| `/shaka doctor` | Checks your setup. If it reports a problem, tell your agent to fix it. |
| `/shaka settings` | Explains this repository's settings. Ask it to change one. |
| Anything else | Ask your agent how to get Shaka to do it. |

Use `$shaka` in Codex ([other agents](docs/coding-agents.md)). By default, you
decide whether to merge ([Ask or Auto](docs/working-with-shaka.md#choose-a-merge-policy)).

You don't need to read the docs. They are a reference for your agent, and you can
[browse them](https://shaka.shakacode.com/) anytime.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Names and logos

The MIT license covers the code and documentation. It does not grant rights to
use the Shaka or ShakaCode names or logos. ShakaCode is a registered trademark of
ShakaCode LLC in the United States. You may say that your work uses or is based on
Shaka. Give a fork or product its own name, so it does not appear to come from
ShakaCode.
