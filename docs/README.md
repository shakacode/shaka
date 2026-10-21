# Documentation

**PRs that are a delight to review.**

Give your coding agent a task. Shaka has it build the change, test it, and get
an independent review. Then it hands you one pull request (PR) that is quick to
judge.

## Why use Shaka

- **See the outcome first.** The PR description opens with what changed, why,
  what it leaves out, and why it is safe.
- **See the proof.** Each check says what ran and how it turned out, and a
  **Not verified** line names what went unproven.
- **Read the code with a guide.** A code walkthrough explains each choice and
  links to the exact lines.
- **Skip what you do not need.** Usage, detailed checks, and history sit in
  collapsed sections.
- **Keep the merge decision.** By default the agent hands the ready PR back to you.

[PR verification](pr-verification.md#read-a-pr-for-your-decision) shows where each
answer lives in a PR.

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](img/task-to-pr.svg)

<a id="start-here"></a>

## What to do first

1. Ask your coding agent: `Install Shaka from https://github.com/shakacode/shaka.`
2. Open a chat in your project and give it a small fix you can recognize:

   ```text
   $shaka Fix search when the query contains an apostrophe. Go.
   ```

   Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode.
3. Read the PR it returns and decide whether to merge.

[Start here](getting-started.md) covers setup choices. New to branches and pull
requests? [Shaka in pictures](shaka-in-pictures.md) explains them with a practice task.

## Learn as you go

1. [Working with Shaka](working-with-shaka.md): merge policy, feedback, waiting
   PRs, and other kinds of tasks.
2. [FAQ](faq.md): planning first, picking settings, or understanding a pause.

<a id="configure-and-understand"></a>

## Set up when you need to

Ask the agent to handle configuration. These guides explain your choices:

- [Repository setup](configure-repository.md) — reuse your checks and review the setup PR.
- [Choose your settings](settings-guide.md) — common choices and prompts for your agent.
- [Coding agents](coding-agents.md) — invocation and installation for your environment.
- [Install Shaka manually](manual-installation.md) — review and run the installer yourself.
- [Fork Shaka and make it yours](fork-and-hack.md) — install your fork and send a change back.
- [Update Shaka](migration.md) — update your installation, or upgrade a repository's configuration layout.

## Look deeper

- [PR verification](pr-verification.md) — evaluate a change and revisit its decisions after merging.
- [What to expect from Shaka](expected-experience.md) — setup choices, verification gaps, and recovery.
- [Settings reference](settings.md) — exact options, defaults, and advanced behavior.
- [Writing preferences](writing-preferences.md) — choose how the agent writes for your project.
- [Workflow and enforcement](workflow.md) — what code checks and what relies on the agent.
- [Architecture](architecture.md) — why Shaka keeps one owner and little state.
- [Repository catalog](repository-catalog.md) — organize repositories across projects.
- [Control towers](control-towers.md) — coordinate a batch across chats and decide which PRs to merge first.
- [Try a Shaka PR](trying-pr-versions.md) — evaluate an unmerged change on real work.

Development guidance lives in [Contributing](../CONTRIBUTING.md).
