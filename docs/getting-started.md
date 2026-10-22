# Start here

Start with a small fix in a project you know.

Examples use `$shaka` in Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode.
In Pi, load the installed Shaka skill. See [coding agents](coding-agents.md).

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

To run the commands yourself, follow [manual installation](manual-installation.md).
Don't install the `shaka` gem. It only reserves the name.

Check the install, and follow what the report says:

```text
$shaka doctor
```

If the Shaka skill doesn't appear, start a new chat and try again.

<a id="2-choose-private-trial-or-team-setup"></a>
<a id="2-choose-individual-trial-or-team-setup"></a>

## 2. Choose individual or team setup

On your first task in a project without Shaka settings, the agent asks whether to
set Shaka up just for you or for your team.

- **Just for you:** settings stay out of commits, and the task goes on.
- **For your team:** the agent opens a setup PR for you to review. See
  [repository setup](configure-repository.md).

To check that your AI accounts can run the chosen reviewers, ask
`$shaka Probe this project's configured reviewers.` Each probe may use quota or
cost money.

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Use your own small outcome or an issue link. The agent asks when it needs you.

Other kinds of tasks:

- [Plan before implementing](working-with-shaka.md#get-a-plan-before-implementing).
- [Review an existing PR](working-with-shaka.md#review-an-existing-pr).
- [Resume a PR](working-with-shaka.md#resume-a-pr-you-already-started) or
  [recover unfinished work](working-with-shaka.md#resume-unfinished-work).
- [Set up a repository for your team](working-with-shaka.md#configure-a-repository-for-your-team).

Under **Ask**, the default, you decide whether to merge the PR.
[Working with Shaka](working-with-shaka.md) covers what comes next.

### Use a personal fork

To change Shaka itself and install that version:

```text
Fork https://github.com/shakacode/shaka and install my fork.
```

See [Fork Shaka and make it yours](fork-and-hack.md).
