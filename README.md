# Shaka

**Know what your AI coding agent really did before you merge it.**

Shaka is a free, open-source skill for Claude Code, Codex, Cursor, OpenCode, and Pi.
A skill is a set of instructions your coding agent loads. Give your agent a task with
`/shaka`, and it tests the work, gets a second AI to review it, and brings you a pull
request (PR), a proposed change you can check before it goes in. The PR shows what
changed, what was proven, and where to look closely.

[Try it on a small fix](#get-started) ·
[Watch the 52-second demo](https://www.youtube.com/watch?v=T6Fstx2fGJI) ·
[Read a real Shaka PR](https://github.com/shakacode/shaka/pull/667)

![You give a task. The agent builds, verifies, and reviews. You review one clear PR with a walkthrough, check and review results, and the decisions left for you.](docs/img/task-to-pr.svg)

<a id="why-use-it"></a>

## The problem

Your agent writes code faster than you can check it, and then it tells you the work is
done. So you read every line, or you merge on hope and find the bug after it ships. You
shouldn't have to take a machine's word for it.

We hit this wall too. We're [ShakaCode](https://www.shakacode.com), the team behind
React on Rails and Shakapacker, and we build with coding agents every day. Shaka is how
we get past it. We build Shaka with Shaka, so its PRs are public for you to judge: across
147 of them, the second-AI review found
[102 defects](docs/articles/review-process-study.md) before that code was pushed.

## What changes when you use it

- **You know where to look.** Each PR says why the change exists and rates, from 1 to 5,
  how closely to read the code. A typo gets a glance. A risky change gets every line.
- **You see proof instead of a claim.** Each check links to its result, and anything
  unproven says so. UI changes come with before-and-after screenshots.
- **A second AI checks the work before you do.** The reviewer never saw the chat that
  wrote the code. Problems get fixed before the push, so you repeat fewer CI runs.
- **You stop directing the process.** Describe the outcome once. You don't have to remind
  the agent to test, review, or explain itself.
- **You decide what merges.** By default, the agent hands the finished PR back to you.
  If you [let it merge](docs/working-with-shaka.md#choose-a-merge-policy), it still returns
  large or risky changes.
- **Strangers can't steer your agent.** On public repositories, Shaka keeps comments from
  untrusted authors [away from the agent](docs/workflow.md#trust-model).

### Why not just tell my agent to test and review?

You can, and it helps. Shaka adds three things a one-off prompt doesn't: a reviewer with no
stake in the code, the same steps on every task, and, when your agent does the merging, a
check that stops it if no posted review covers that commit. [What is enforced](docs/workflow.md#what-is-enforced)
separates what code checks from what still relies on the agent.

## What it works with

| | |
| --- | --- |
| **Coding agents** | Claude Code, Codex, Cursor, OpenCode, and Pi ([details](docs/coding-agents.md)) |
| **AI models** | Whatever your agent runs. Shaka doesn't change your model or permissions. |
| **Second reviewer** | Claude, Codex, Grok, or DeepSeek when one is set up. Otherwise, a fresh session of your own model. |
| **Cost** | Shaka is free ([MIT](LICENSE)). You pay only your own AI usage, and each PR reports it. In our repository, one review run takes under a minute at the median and costs about $0.09 to $0.25. |
| **You need** | A GitHub repository, Git 2.41 or later, an authenticated [GitHub CLI](https://cli.github.com/), and Ruby 3.4 or later. Shaka uses Ruby itself; your project can be in any language. `/shaka doctor` tells you what's missing. |
| **Your code** | Installing changes none of your repositories. Your change goes to another AI provider only after you agree, and Shaka [shows you what it sends](docs/coding-agents.md#give-consent-once) when it asks. |

<a id="get-started"></a>
<a id="requirements"></a>
<a id="example-prompts"></a>

## Try it on a small fix

1. Paste this into your coding agent:

   ```text
   Install Shaka from https://github.com/shakacode/shaka.
   ```

   Prefer to read it first? [Install it by hand](docs/manual-installation.md).

2. In a project you know, give it something small you can check:

   ```text
   /shaka Fix search when the query contains an apostrophe. Go.
   ```

   Use `$shaka` in Codex. On your first task in a project, it asks whether to keep settings
   just for you or share them with your team.

3. Read the PR and decide. You'll see what changed, what was proven, and where to look
   closely. If you don't like it, close it. Nothing goes in until you merge.

New to pull requests? [Shaka in pictures](docs/shaka-in-pictures.md) walks you through a
practice task.

## All you need to remember

| Say | What happens |
| --- | --- |
| `/shaka <task or issue link>` | Delivers the task as a PR. |
| `/shaka doctor` | Checks your setup. If it reports a problem, tell your agent to fix it. |
| `/shaka settings` | Explains this repository's settings. Ask it to change one. |
| Anything else | Ask your agent how to get Shaka to do it. |

You don't need to read the docs to use Shaka. They are mostly reference for your agent, and
you can [browse them](https://shaka.shakacode.com/) anytime.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Names and logos

The MIT license covers the code and documentation. It does not grant rights to
use the Shaka or ShakaCode names or logos. ShakaCode is a registered trademark of
ShakaCode LLC in the United States. You may say that your work uses or is based on
Shaka. Give a fork or product its own name, so it does not appear to come from
ShakaCode.
