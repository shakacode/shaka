# Documentation

Shaka is a skill for AI coding agents. Give it a task and get a tested, reviewed
pull request you can judge. By default, you decide whether it merges.

Start with a small task. Ask your agent for help whenever you need it:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Then, in Codex:

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Use `/shaka` in Claude Code, Cursor, or OpenCode. For Pi, load the installed skill.

<a id="why-use-shaka"></a>
<a id="start-here"></a>
<a id="what-to-do-first"></a>

[Start here](getting-started.md) helps with setup.
[Shaka in pictures](shaka-in-pictures.md) gives you a playground task if you are
new to pull requests. [Watch the demo](https://www.youtube.com/watch?v=T6Fstx2fGJI)
or [open an example PR](https://github.com/shakacode/shaka/pull/667).

<a id="configure-and-understand"></a>
<a id="learn-as-you-go"></a>
<a id="set-up-when-you-need-to"></a>
<a id="look-deeper"></a>

## Reference

| If you want to… | Try… |
| --- | --- |
| Plan before coding, review an existing PR, or give feedback | [Working with Shaka](working-with-shaka.md) |
| Choose who merges or which AI reviews | [Choose your settings](settings-guide.md) |
| Introduce Shaka to teammates | [Repository setup](configure-repository.md) |
| Resolve a setup or access problem | [FAQ](faq.md), [coding agents](coding-agents.md), or [recovery limits](expected-experience.md) |
| Install, update, or customize Shaka | [Manual installation](manual-installation.md), [updates](migration.md), or [forks](fork-and-hack.md) |
| Decide whether to merge | [Before you merge](pr-verification.md) and [releases after merge](releases-after-merge.md) |
| Look up a setting or reporting limit | [Settings](settings.md), [cost](reference/usage-and-cost.md), or [timings](reference/timings.md) |
| Understand trust and safeguards | [Workflow and enforcement](workflow.md) |
| Set a writing style | [Writing preferences](writing-preferences.md) |
| Coordinate several projects | [Control towers](control-towers.md) and [repository catalog](repository-catalog.md) |
| Improve Shaka itself | [Architecture](architecture.md), [PR trials](trying-pr-versions.md), [canary runs](canary.md), or [Contributing](../CONTRIBUTING.md) |

[Articles](articles/review-process-study.md) share measured experiments with AI review.

<a id="start-a-task"></a>
<a id="for-open-source-repositories"></a>
