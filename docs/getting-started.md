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
Install Shaka from https://github.com/shakacode/shaka for this coding agent.
Keep the installation outside the repositories I'll work on.
Follow its installation instructions and confirm the skill is available.
```

The agent checks for Ruby 3.4 or later, Git, and an authenticated GitHub CLI.
It installs a managed copy outside your projects. Start a new chat if the skill
does not appear. Use a source installation: the published gem is a
name-reservation prerelease without the current workflow.

Try `$shaka` without a task for a guided welcome and setup check. Or ask:

```text
$shaka doctor
```

Doctor reports what is ready, which supported reviewer CLIs are on PATH, and
where to install missing ones. It gives setup advice even before this repository
is configured. Finding a CLI does not verify sign-in, quota, or a working review.
An extra provider can supply independent review; installing every CLI is optional.
The diagnostic changes no settings. Give the agent a task when you are ready.

## 2. Choose private trial or team setup

For a private first task, open a chat in your project and ask:

```text
$shaka Fix search when the query contains an apostrophe.
Try Shaka privately in this clone using the project's existing checks.
Keep merge policy ask. Go.
```

Shaka instructs the agent to infer commands from project instructions, scripts,
and CI, prepare local settings, and continue into the feature task. No team setup PR, manual
YAML edit, or PATH edit is needed. Private settings remain excluded from the
feature diff. Host permissions may require approval for protected Git writes.
Genuine new-user acceptance remains unproven; see the
[trial evidence and limitations](expected-experience.md#private-trials-available-tools-incomplete-guided-experience).

For shared team settings, ask:

```text
$shaka Configure this repository for Shaka. Reuse its existing checks,
explain the choices I need to make, and keep merge policy ask.
```

The agent prepares shared settings and scripts in a **setup PR**. They connect
Shaka to your project's commands and record its review and merge choices.
**Review the choices and merge this first setup PR yourself on GitHub.**
Then start your feature task. If the repository is already configured, skip this step.
You can ask the agent to change settings later; you do not need to maintain them by hand.
See [repository setup](configure-repository.md) for details.

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe.
Keep merge policy ask. Go.
```

Replace the example with a small outcome or an issue link. `Go` lets the agent
start with its current model and effort settings. It handles routine work and
asks when a missing choice, access problem, or consequential decision needs you.

Look for a PR explaining what changed, what was tested and reviewed, and any
remaining gaps. With **Ask**, you decide whether to merge; **Auto** lets the agent
merge after the required checks, review, and approvals.
[Working with Shaka](working-with-shaka.md) covers these choices, useful prompts,
feedback, and resuming a task.

### Use a personal fork

To customize Shaka and contribute improvements upstream:

```text
Fork https://github.com/shakacode/shaka into my GitHub account and install
Shaka from that fork. Keep upstream configured so we can pull updates
and submit improvements back to shakacode/shaka.
```

For later maintenance, ask the agent to [upgrade your installation](migration.md).
To evaluate an unmerged workflow change, [try a Shaka PR on real work](trying-pr-versions.md).
