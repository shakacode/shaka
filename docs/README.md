# Documentation

**Review the intent and the evidence, not every line.**

Give your coding agent a task. Shaka has it build, test, and get an independent
review. You get one pull request (PR) you can judge quickly.

## Why use Shaka

Each PR shows:

- **Intent:** why the change exists, what it leaves out, and why it is safe.
- **Verification:** the checks that prove the change and any claim left unproven.
  Each check links to its result or names the command that ran.
- **UI evidence:** for a UI change, annotated before-and-after screenshots, plus
  a video when timing matters.
- **Review effort:** how carefully to read the code, from the description alone
  to every line. When a few lines need a closer look, walkthrough notes can
  point them out.
- **Less to read:** detail you can skip is collapsed.
- **Your merge decision:** by default, the agent hands the ready PR back to you.

See [what a PR answers](pr-verification.md#answers-for-your-next-decision).

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](img/task-to-pr.svg)

<a id="start-here"></a>

## What to do first

1. Ask your coding agent: `Install Shaka from https://github.com/shakacode/shaka.`
2. In your project, give it a small fix you can check:

   ```text
   $shaka Fix search when the query contains an apostrophe. Go.
   ```

   Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode
   ([other agents](coding-agents.md)).
3. Read the PR and decide whether to merge.

[Start here](getting-started.md) covers setup. New to pull requests? Try
[Shaka in pictures](shaka-in-pictures.md).

## Learn as you go

1. [Working with Shaka](working-with-shaka.md): merge policy, feedback, waiting
   PRs, and other kinds of tasks.
2. [FAQ](faq.md): planning first, picking settings, or understanding a pause.

<a id="configure-and-understand"></a>

## Set up when you need to

The agent handles setup. These guides explain the choices:

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
- [Canary runs](canary.md) — read the sandbox pull request opened after a merge to `main`.

Development guidance lives in [Contributing](../CONTRIBUTING.md).
