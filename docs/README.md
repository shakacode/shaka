# Documentation

You give a task. The agent builds, verifies, and reviews. You get a pull request
(PR) you can judge quickly.

You don't need to read these guides before using Shaka. Start with a small task
and ask your agent when you need help. The guides are here when you want more detail.

<a id="why-use-shaka"></a>

## Why use Shaka

Shaka helps your coding agent finish the work around the code: testing,
independent review, and a PR that explains the result. You can see what was
checked, what remains unverified, and which files need your attention.
For UI changes, the PR includes before-and-after screenshots.

PRs also report available token usage, estimated costs, and time spent working
or waiting. See [usage and cost](reference/usage-and-cost.md) and
[timings](reference/timings.md) when you want to understand those numbers.

By default, you merge the PR. You can approve the agent's merge or choose
[Auto](working-with-shaka.md#choose-a-merge-policy).
Even with Auto, large or risky changes need your merge decision.

<a id="start-here"></a>

## Start a task

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Then give it a small task:

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode.
For Pi, load the installed skill. The agent checks setup and asks when it needs you.

[Start here](getting-started.md) covers your first task.
[Shaka in pictures](shaka-in-pictures.md) introduces pull requests.

## For open-source repositories

To reduce prompt-injection risk, Shaka ignores comments from untrusted authors.
Maintainers can choose whose comments the agent reads.
See [review safety](workflow.md#trust-model).

<a id="configure-and-understand"></a>

## Reference

Open a guide when you need it, or ask your agent to read it for you.

- [Working with Shaka](working-with-shaka.md): prompts, merge choices, feedback, and resuming work.
- [FAQ](faq.md): answers to common questions.
- [Repository setup](configure-repository.md): individual and team setup.
- [Choose your settings](settings-guide.md): ask your agent to explain or change settings.
- [Coding agents](coding-agents.md): use Shaka with your agent.
- [Manual installation](manual-installation.md): run the installer yourself.
- [PR verification](pr-verification.md): inspect evidence before merging.
- [Settings reference](settings.md): look up options and defaults.
- [Workflow and review safety](workflow.md): understand checks and trusted feedback.

The sidebar lists the remaining guides, including updates, forks, and advanced use.
Development guidance lives in [Contributing](../CONTRIBUTING.md).
