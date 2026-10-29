# Start here

Start with a small fix in a project you know.

Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode
([other agents](coding-agents.md)).

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

To run the commands yourself, follow [manual installation](manual-installation.md).

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

Under **Ask**, the default, you decide whether to merge the PR.
[Working with Shaka](working-with-shaka.md) covers what comes next.
