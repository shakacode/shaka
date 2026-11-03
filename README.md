# Shaka

Shaka is a free, open-source skill for AI coding agents, including Claude Code,
Codex, Cursor, OpenCode, and Pi.

You give a task. The agent builds, verifies, and reviews. You get a pull request
(PR) you can judge quickly.

[Watch the 52-second demo](https://www.youtube.com/watch?v=T6Fstx2fGJI) ·
[See a Shaka PR](https://github.com/shakacode/shaka/pull/667)

## Why use Shaka?

Writing code is only part of the work. You still need to know whether it works,
what a reviewer found, and what needs your attention before merging.

Shaka gives your agent a repeatable way to finish that work:

- A second AI reviews the change in a fresh session. The agent addresses findings
  before pushing.
- Each PR explains the change, shows check results, and identifies anything still
  unverified. For UI changes, you get before-and-after screenshots.
- You can see where to focus your review, plus available token usage, estimated
  costs, and time spent working or waiting.
- You describe the outcome without having to keep reminding the agent to test,
  review, and explain its work.

By default, you merge the PR. You can also approve the agent's merge or choose
[Auto](docs/working-with-shaka.md#choose-a-merge-policy).
Even with Auto, large or risky changes need your merge decision.

<a id="example-prompts"></a>
<a id="get-started"></a>
<a id="requirements"></a>

## Try it

You don't need to study the docs first. Ask your coding agent to install Shaka:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Then give it a small task:

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode.
For Pi, load the installed skill. Your agent checks setup and tells you if
anything is missing.

Read the PR, ask for revisions if needed, and decide whether to merge.

Prefer to install it manually? Follow [manual installation](docs/manual-installation.md).
New to pull requests? Try [Shaka in pictures](docs/shaka-in-pictures.md).

## For open-source repositories

To reduce prompt-injection risk, Shaka ignores comments from untrusted authors.
Maintainers can choose whose comments the agent reads.
See [review safety](docs/workflow.md#trust-model).

## Make it work for your team

Shaka uses your coding agent and your repository's checks. You can choose
reviewers and merge preferences for each project. Shaka itself is free;
you pay for the agents and services you use.

[ShakaCode](https://www.shakacode.com) can help customize the Shaka skill to
improve your development team's efficiency.

## When you want more detail

Ask your agent how to use Shaka, or open the [documentation](docs/README.md).
[Start here](docs/getting-started.md) walks through your first task.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Names and logos

The MIT license covers the code and documentation. It does not grant rights to
use the Shaka or ShakaCode names or logos. ShakaCode is a registered trademark of
ShakaCode LLC in the United States. You may say that your work uses or is based on
Shaka. Give a fork or product its own name, so it does not appear to come from
ShakaCode.
