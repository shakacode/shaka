# Documentation

Shaka is a skill for AI coding agents. Give your agent a task and get a pull
request (PR) with checks and review results. By default, you decide whether it merges.

Use the PR's evidence to decide what to do next and improve the process through
regular retrospectives.

Ask your coding agent to install Shaka:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Then open your project in the agent and give Shaka a small task. For example:

```text
/shaka Fix search when the query contains an apostrophe.
```

Replace the example with your own task or an issue link. In Codex, use `$shaka`
instead of `/shaka`. For Pi, load the installed skill.

<a id="why-use-shaka"></a>
<a id="start-here"></a>
<a id="what-to-do-first"></a>

[Start here](getting-started.md) covers setup and checking your installation.
If you need a practice project, follow [Shaka in pictures](shaka-in-pictures.md).
[Watch the demo](https://www.youtube.com/watch?v=T6Fstx2fGJI)
or [open an example PR](https://github.com/shakacode/shaka/pull/667).

<a id="configure-and-understand"></a>
<a id="learn-as-you-go"></a>
<a id="set-up-when-you-need-to"></a>
<a id="look-deeper"></a>

<a id="reference"></a>

## Find help

Ask your agent, or choose a guide below:

```text
Explain what I need to check before merging this PR: <PR link>.
```

| I want to… | Guide |
| --- | --- |
| Plan work, review an existing PR, or give feedback | [Working with Shaka](working-with-shaka.md) |
| Choose who merges | [Choose a merge policy](working-with-shaka.md#choose-a-merge-policy) |
| Review the result and learn from completed PRs | [Review the PR and improve the process](pr-verification.md) |
| Choose reviewers or change settings | [Choose your settings](settings-guide.md) |
| Set up Shaka for my team | [Configure a repository](configure-repository.md) |
| Fix a setup problem or resume unfinished work | [FAQ](faq.md) · [What to expect from Shaka](expected-experience.md) |
| Understand token use, cost, or timing | [Usage and cost](reference/usage-and-cost.md) · [PR timings](reference/timings.md) |

<details>
<summary>More guides</summary>

- [Coding agents](coding-agents.md), [manual installation](manual-installation.md), [updates](migration.md), and [forks](fork-and-hack.md)
- [Settings reference](settings.md), [workflow and safeguards](workflow.md), and [writing preferences](writing-preferences.md)
- [Releases after merge](releases-after-merge.md)
- [Control towers](control-towers.md) and [repository catalog](repository-catalog.md)
- [Architecture](architecture.md), [PR trials](trying-pr-versions.md), [canary runs](canary.md), and [Contributing](../CONTRIBUTING.md)
- [Articles](articles/review-process-study.md) about measured experiments with AI review

</details>

<a id="start-a-task"></a>
<a id="for-open-source-repositories"></a>
