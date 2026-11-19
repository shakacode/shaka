# Start here

Install Shaka, give your coding agent a small task, and review the pull request
(PR) it produces.

Use a project you already work on. If you want a practice project, follow
[Shaka in pictures](shaka-in-pictures.md).

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka
Use the latest published stable release. If none is published, install from source
```

Prefer to install it manually? Follow [manual installation](manual-installation.md).

After installation, start a new chat and check the setup:

```text
/shaka doctor
```

In Codex, use `$shaka` instead of `/shaka`. For Pi, load the installed skill and
ask it to run doctor. See [coding agents](coding-agents.md).

The agent explains what is ready and what needs fixing. Missing project settings
are expected before project setup. Ask the agent to help resolve other problems
before starting your task.

If Shaka doesn't appear, restart your coding tool and try again.

For a pinned release, ask your agent about [choosing a newer release](manual-installation.md#keep-a-tested-release).
For a branch install, see [verify and update](manual-installation.md#verify-and-update).

<a id="2-choose-private-trial-or-team-setup"></a>
<a id="2-choose-individual-trial-or-team-setup"></a>

<a id="2-choose-individual-or-team-setup"></a>

## 2. Set up your project

Open your project in your coding agent. If the project already has Shaka settings,
the agent uses them. Otherwise, choose:

- **Just for me:** keep Shaka settings local, without adding them to the shared repository.
- **For my team:** open a PR with shared settings for teammates to review.

For a first trial, include **Set up Shaka just for me** in your task below. You
can adopt shared settings later.

<a id="3-start-a-task"></a>

## 3. Give Shaka a task

Choose a small change you can check yourself. For example:

```text
/shaka Fix search when the query contains an apostrophe
Set up Shaka just for me if there are no shared settings. Ask me before merging. Go
```

Replace the example with your own task or an issue link. The agent makes the change,
runs checks, and arranges review. `Go` starts with your current model and effort.
You still decide whether to merge the PR.

Open the resulting PR. Read what changed, what was checked, and what remains
unverified. Try the changed feature when relevant.

Ask for revisions in the same chat. Before approving a merge, confirm that the PR
is the version you reviewed. When you're satisfied, merge through GitHub or tell
the agent:

```text
You can merge
```

Required checks and approvals still apply. See
[Review the PR and improve the process](pr-verification.md) for help assessing the
result. [Working with Shaka](working-with-shaka.md) covers planning, feedback, and
resuming unfinished work.
