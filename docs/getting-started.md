# Start here

Give your coding agent a task. Shaka guides it through implementation, checks,
independent review, and a pull request you can understand and decide whether to merge.
Start with a small fix in a project you know.

Examples use `$shaka` in Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode;
in Pi, load the installed Shaka skill. See [coding agents](coding-agents.md).

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Prefer to run the commands yourself? Follow [manual installation](manual-installation.md).

Then check your setup and follow what it reports:

```text
$shaka doctor
```

<a id="2-choose-private-trial-or-team-setup"></a>
<a id="2-choose-individual-trial-or-team-setup"></a>

## 2. Choose individual or team setup

If your project has no Shaka settings yet, the agent asks on your first task
whether to set it up just for you or for your team, and explains each choice.

- **Just for you:** settings stay out of commits, and the task continues.
- **For your team:** the agent opens a setup PR. **Review and merge it yourself
  on GitHub.** See [repository setup](configure-repository.md).

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Replace the example with a small outcome or an issue link. The agent asks when it
needs a choice or access from you.

For a different outcome, choose an example:

- [Plan before implementing](working-with-shaka.md#get-a-plan-before-implementing).
- [Review an existing PR](working-with-shaka.md#review-an-existing-pr).
- [Resume a PR](working-with-shaka.md#resume-a-pr-you-already-started) or
  [recover unfinished work](working-with-shaka.md#resume-unfinished-work).
- [Set up a repository for your team](working-with-shaka.md#configure-a-repository-for-your-team).

The PR explains what changed, how it was checked, and what is still open. Under
**Ask**, the default, you decide whether to merge.
[Working with Shaka](working-with-shaka.md) covers what to do next.

### Use a personal fork

To change Shaka itself and install that version:

```text
Fork https://github.com/shakacode/shaka and install my fork.
```

See [Fork Shaka and make it yours](fork-and-hack.md).
