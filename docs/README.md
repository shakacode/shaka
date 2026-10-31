# Documentation

**Review the intent and the evidence, not every line.**

Give your coding agent a task. It builds, tests, and gets an independent review.
You get one PR that says what changed, how it was checked, and what is left for
you to decide. See [what a PR answers](pr-verification.md#answers-for-your-next-decision).

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](img/task-to-pr.svg)

<a id="start-here"></a>
<a id="why-use-shaka"></a>

## What to do first

1. Ask your coding agent: `Install Shaka from https://github.com/shakacode/shaka.`
2. In your project, give it a small fix you can check:

   ```text
   /shaka Fix search when the query contains an apostrophe. Go.
   ```

3. Read the PR and decide whether to merge.

[Start here](getting-started.md) covers setup. New to pull requests? Try
[Shaka in pictures](shaka-in-pictures.md).

## All you need to know

| Say | What happens |
| --- | --- |
| `/shaka <task or issue link>` | Delivers the task as a PR. |
| `/shaka doctor` | Checks your setup. If it reports a problem, tell your agent to fix it. |
| `/shaka settings` | Explains this repository's settings and changes them. |
| Anything else | Ask your agent how to get Shaka to do it. |

Use `$shaka` in Codex ([other agents](coding-agents.md)).

You don't need to read the rest of these pages. They are a reference for your
agent. Open one when you want the detail.

<a id="configure-and-understand"></a>

## Reference

### Use Shaka

- [Working with Shaka](working-with-shaka.md) — merge policy, feedback, waiting PRs, and other kinds of tasks.
- [FAQ](faq.md) — pauses, merging, review, and where settings live.
- [PR verification](pr-verification.md) — evaluate a change and revisit its decisions after merging.
- [What to expect from Shaka](expected-experience.md) — setup choices, verification gaps, and recovery.
- [Releases after merge](releases-after-merge.md) — where the PR record stops and your release process starts.
- [Usage and cost](reference/usage-and-cost.md) — read a PR's reported model work and estimated cost.
- [Timings](reference/timings.md) — see where a PR's time went.

### Set up and configure

- [Repository setup](configure-repository.md) — reuse your checks and review the setup PR.
- [Choose your settings](settings-guide.md) — common choices and prompts for your agent.
- [Settings reference](settings.md) — exact options, defaults, and advanced behavior.
- [Writing preferences](writing-preferences.md) — choose how the agent writes for your project.
- [Coding agents](coding-agents.md) — invocation and installation for your environment.
- [Start from Linear](linear.md) — open a Linear issue in Codex with its details filled in.
- [Install Shaka manually](manual-installation.md) — review and run the installer yourself.
- [Fork Shaka and make it yours](fork-and-hack.md) — install your fork and send a change back.
- [Update Shaka](migration.md) — update your installation, or upgrade a repository's configuration layout.

### Understand and extend

- [Workflow and enforcement](workflow.md) — what code checks and what relies on the agent.
- [Architecture](architecture.md) — why Shaka keeps one owner and little state.
- [Repository catalog](repository-catalog.md) — organize repositories across projects.
- [Control towers](control-towers.md) — coordinate a batch across chats and decide which PRs to merge first.
- [Try a Shaka PR](trying-pr-versions.md) — evaluate an unmerged change on real work.
- [Canary runs](canary.md) — read the sandbox pull request opened after a merge to `main`.

Development guidance lives in [Contributing](../CONTRIBUTING.md).
