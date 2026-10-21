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

The agent checks for Ruby 3.4 or later, Git, and an authenticated GitHub CLI.
It installs Shaka in its own checkout, `~/.agents/shaka` by default, and links it
into your coding agent's skills folder, such as `~/.claude/skills`. If your rules
protect that folder, allow the link. See
[what the installer changes](manual-installation.md#what-the-installer-changes).

- Keep the installation outside your project repositories.
- Install from source. The published gem only reserves the name.
- Start a new chat if the skill does not appear.
- When the skill reports an update, ask your agent to [update Shaka](migration.md).

Check your setup:

```text
$shaka doctor
```

Doctor reports what is ready and which reviewer CLIs it found, with install hints
for missing ones. Finding a CLI does not prove it is signed in or has quota.
Doctor changes no settings and exits with status 1 when any check fails.
`$shaka` alone gives a guided welcome with the same check. One extra provider is
enough for an independent review; you do not need every CLI.

Optional: set `SHAKA_MACHINE_ALIAS` in your shell profile to a short name such as
`mini`. Unfinished PRs then show which machine holds the work. PRs may be public,
so do not use the machine's real name.

<a id="2-choose-private-trial-or-team-setup"></a>
<a id="2-choose-individual-trial-or-team-setup"></a>

## 2. Choose individual or team setup

Open a chat in your project and give Shaka a task:

```text
$shaka <task or issue link>
```

If Shaka is not configured, the agent asks which setup you want. **Individual
setup** keeps settings out of commits in a project without team settings.
To choose it upfront:

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

The agent finds your test and lint commands, explains AI review choices, and
defaults to Ask. Individual setup continues into the task without a team setup PR.
Host permissions may require approval for protected Git writes. See
[individual support and acceptance gaps](expected-experience.md#individual-setup).

For shared team settings, ask:

```text
$shaka Set up Shaka for this repository.
```

The agent prepares shared settings and scripts in a **setup PR** that connects
Shaka to your project's commands and records its review and merge choices.
**Review the choices and merge this first setup PR yourself on GitHub.**
Skip this step if the repository is already configured. Later, ask the agent to
change settings. See [repository setup](configure-repository.md).

After the setup PR merges, check that your AI CLI accounts can run the chosen
reviewer models:

```text
$shaka Probe this project's configured reviewers.
```

The agent sends each reviewer one short prompt, which may use quota or cost money,
and reports which ones answered. It keeps your settings, explains any failure,
and asks how to proceed.

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Replace the example with a small outcome or an issue link. `Go` starts with your
agent's current model and effort. The agent asks when it needs a choice or access from you.

For a different outcome, choose an example:

- [Plan before implementing](working-with-shaka.md#get-a-plan-before-implementing).
- [Review an existing PR](working-with-shaka.md#review-an-existing-pr).
- [Resume a PR](working-with-shaka.md#resume-a-pr-you-already-started) or
  [recover unfinished work](working-with-shaka.md#resume-unfinished-work).
- [Set up a repository for your team](working-with-shaka.md#configure-a-repository-for-your-team).

The PR explains what changed, what was tested and reviewed, and any remaining
gaps. Under **Ask**, the default, you decide whether to merge.
[Working with Shaka](working-with-shaka.md) covers what to do next.

### Use a personal fork

To change Shaka itself and install that version:

```text
Fork https://github.com/shakacode/shaka and install my fork.
```

[Fork Shaka and make it yours](fork-and-hack.md) covers installing the fork,
changing it, and sending a change back. For later maintenance, ask the agent to
[upgrade your installation](migration.md). To evaluate one unmerged change
without replacing your installation,
[try a Shaka PR on real work](trying-pr-versions.md).
