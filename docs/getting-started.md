# Start here

Install Shaka, then give it a small fix in a project you know. You don't need to
read anything else first.

Use `/shaka` in Claude Code, Cursor, or OpenCode and `$shaka` in Codex
([other agents](coding-agents.md)).

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

You need Ruby 3.4 or later, Git 2.41 or later, an authenticated
[GitHub CLI](https://cli.github.com/), and a coding agent that can load skills and
run commands. To run the commands yourself, follow [manual installation](manual-installation.md).

Check the install:

```text
/shaka doctor
```

It checks Ruby, Git, and GitHub access. If it reports a problem, tell your agent to
fix it. If the Shaka skill doesn't appear, start a new chat and try again.

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
/shaka Fix search when the query contains an apostrophe. Go.
```

Use your own small outcome or an issue link. The agent asks when it needs you.
Under **Ask**, the default, you decide whether to merge the PR.

## 4. Ask your agent for the rest

To see or change this repository's settings:

```text
/shaka settings
```

For anything else, ask your agent, such as:

```text
How do I get Shaka to review an existing PR?
```

Your agent reads the [reference pages](README.md#reference), so you don't have to.
[Working with Shaka](working-with-shaka.md) is the one to open if you want to browse
the prompts for plans, reviews, and resuming work.
