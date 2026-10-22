# Documentation

**Review the intent and the evidence, not every line.**

Each PR shows:

- **Intent:** why the change exists, what it leaves out, and why it is safe.
- **Verification:** the checks that prove the change and any claim left unproven.
  Each check links to its result or names the command that ran.
- **UI evidence:** for a UI change, annotated before-and-after screenshots, plus
  a video when timing matters.
- **Review effort:** how carefully to read the code, from the description alone
  to every line. Walkthrough notes point out lines that need a closer look.

See [what a PR answers](pr-verification.md#answers-for-your-next-decision).
You choose who merges it.

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](img/task-to-pr.svg)

The agent builds, verifies, and reviews, fixing what it can. Then you review one clear
PR: what changed, how it was checked, and what is still open. At the
[checkpoint](pr-verification.md#checkpoint), decide what happens next.

## Start here

New to branches and pull requests? [Shaka in pictures](shaka-in-pictures.md)
explains them and walks you through a practice task.

1. [Install Shaka, configure your repository, and run a first task](getting-started.md).
2. [Work with Shaka](working-with-shaka.md): choose a merge policy, give feedback,
   and resume unfinished work.
3. Use the [practical tips](working-with-shaka.md#useful-tips) or [FAQ](faq.md)
   when you want to plan first, pick settings, or understand a pause.

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
