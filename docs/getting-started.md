# Start here

You don't need to read the rest of the docs first. Install Shaka, give your agent
a small task, and review the result.

Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode.
For Pi, load the installed skill.

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Your agent checks the requirements and tells you if anything is missing.
Prefer to install it manually? Follow [manual installation](manual-installation.md).
If the skill doesn't appear, start a new chat and try again.

<a id="2-choose-private-trial-or-team-setup"></a>
<a id="2-choose-individual-trial-or-team-setup"></a>

## 2. Choose individual or team setup

If your project has no Shaka settings, the agent asks whether to set it up just
for you or for your team.

- Individual settings stay out of commits.
- Team setup opens a PR so your teammates can review the settings.

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Use your own small task or an issue link. The agent builds, verifies, and gets an
independent review before opening a PR. It asks when it needs your input.

Read the PR and ask for revisions if needed. By default, you decide whether to
merge. [Working with Shaka](working-with-shaka.md) covers feedback, merge choices,
and resuming unfinished work.
