# Install Shaka manually

For most installations, ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka for this coding agent.
```

Use [Start here](getting-started.md) for your first task. This page also explains
how to check, update, or repair the installation. To inspect and run the installer
yourself, see [Install](#install).

## What the installer changes

The installer uses a dedicated Shaka checkout outside the projects you edit.
It links Shaka into each selected coding agent, records the source and Ruby it
uses, and leaves an empty lock file in each skills directory. Project settings
stay in the project. See [where Shaka keeps things](settings-guide.md#where-shaka-keeps-things)
and the [local timing log](reference/timings.md#local-timing-log).

The installer does not use `sudo`, edit your shell profile or `PATH`, or install
gems. It refuses installation folders other accounts can write to.

## Install

If you prefer the terminal, use Ruby 3.4 or later, Git 2.41 or later, and an
authenticated [GitHub CLI](https://cli.github.com/). Read the source and the
[installer](https://github.com/shakacode/shaka/blob/main/bin/install) before running it.

<details>
<summary>Manual installation commands</summary>

```bash
shaka_install_dir="$HOME/.local/share/shaka/source"
umask 022
mkdir -p "$(dirname "$shaka_install_dir")"
git clone https://github.com/shakacode/shaka.git "$shaka_install_dir"
```

After reading the checkout, run its installer:

```bash
"$shaka_install_dir/bin/install" --directory "$shaka_install_dir" --agent codex
```

Replace `codex` with your coding agent: `claude`, `cursor`, `opencode`, or `copilot`.
Repeat `--agent` to select more than one. Pi loads the shared skill linked for
`codex`. Keep the checkout outside `~/.agents/`, which holds settings.

| Agent | Skills directory |
| --- | --- |
| Codex | `~/.agents/skills` |
| Claude Code | `~/.claude/skills` |
| Cursor | `~/.cursor/skills` |
| OpenCode | `~/.config/opencode/skills` |
| GitHub Copilot | `~/.copilot/skills` |

The installer links `shaka` inside each selected directory. Pass
`--skills-dir DIR` for a custom directory in place of `--agent`.

</details>

The installer reports which checkout and skill links it uses. Start a new chat,
check the installation, and [set up your project](getting-started.md#2-set-up-your-project).

## Install your own fork

Use [Fork Shaka and make it yours](fork-and-hack.md) to install your own version
and learn how to switch back to the official version.

## Keep a tested release

```text
Install the latest published stable Shaka release if the installer supports it.
Keep my current version available for rollback.
```

If no suitable stable release is available, ask the agent to explain the official
installation options before choosing one. A release stays at its recorded commit.
The installer can keep the earlier version available while it moves the skill links.

## Verify and update

```text
Which Shaka version am I using, and is an update available?
```

The agent can check the source checkout, skill links, and Ruby. Finish active
Shaka chats before updating. Then ask the agent to update and verify the
installation, and start a new chat. Updates can stop if the installed checkout
has local changes or its history no longer matches the recorded branch.
Set `SHAKA_NOTICES=off` if you want to silence Shaka's local reminders. In Claude
Code, you can opt in to reminders at chat start; that adds a `SessionStart` hook
to your user settings in `~/.claude/settings.json`.

<details>
<summary>Check or update from a terminal</summary>

Start with the checkout you installed. If you switched sources, use the
destination the installer printed. From a custom skills folder, run
`./shaka/scripts/shaka install --status` to find the active checkout.
If the helper cannot start, inspect the `shaka` link. Its target is
`skills/shaka` inside the active checkout.

For the default checkout, run:

```bash
shaka_source="$HOME/.local/share/shaka/source"
shaka_helper="$shaka_source/skills/shaka/scripts/shaka"
"$shaka_helper" install --status
```

If you installed elsewhere, set `shaka_source` to the active checkout before
setting `shaka_helper`. If the helper says its recorded Ruby is unavailable,
use Ruby 3.4 or later and run `ruby "$shaka_source/bin/install" --status`.
Status shows the next step. When it asks you to reinstall to record Ruby again,
run `ruby "$shaka_source/bin/install"` from that checkout.

Check the result with `"$shaka_helper" install --verify`. After active chats
finish, run `"$shaka_helper" install --update` to update a branch installation.
For a pinned release, use the [tested release prompt](#keep-a-tested-release)
to install a newer release.
`"$shaka_helper" install --repair` can fix recoverable problems and stops
when it needs a decision. It keeps local commits on a `kept-<commit>` branch
and renames unused records so you can inspect them later.

To enable Claude Code's startup reminder, run
`"$shaka_source/bin/install" --directory "$shaka_source" --agent claude --session-hook`.
Run it again without `--session-hook` to remove the reminder.

</details>

### Repair a broken installation

```text
Check my Shaka installation and help me fix what's broken.
Preserve my changes and tell me if you need a decision.
```

The agent checks what your coding tool loads, fixes what it can, and verifies
the result. If an old checkout or local changes need a decision, it explains
what it found first. If your old installation lives in `~/.agents/shaka`, ask the
agent to move it to a dedicated checkout and verify the skill links. Keep the old
checkout until the new one works.

## Develop Shaka in a separate clone

```text
Set up a separate clone for developing Shaka. Keep my installed copy working.
```

Your coding agent loads the installed checkout directly. A separate development
clone lets you change Shaka without breaking the version you use in other projects.
Avoid installing from a temporary worktree that could disappear after its PR merges.

### Move Shaka out of a clone you develop in

```text
Move my Shaka installation to its own checkout. Preserve my branches, worktrees,
and local changes. Verify the installation afterward.
```

The agent checks which copy is installed and explains what it needs to move.
Ask it to confirm your development work is still available before removing any
old checkout.

<details>
<summary>Move the installation from a terminal</summary>

From the currently registered checkout, run this to move the links to a
dedicated checkout. The old checkout keeps its files, branches, and worktrees.
Choose a destination with no linked worktrees or extra branches. If the default
directory is in use, choose a separate destination.

```bash
./bin/install --directory "$HOME/.local/share/shaka/source" --take-over
```

If you run it from another checkout and use a custom skills folder, pass
that folder with `--skills-dir`. Verify from the new checkout with
`bin/install --verify`.

If the installer was force-stopped during the move and neither checkout has an
active installation record, restore the newest
`.git/shaka-install.retired-*.json` in the old checkout to
`.git/shaka-install.json`. Retry with the same source and destination options,
then verify. If either checkout still has an active record, leave it in place
and check the installation state before retrying.

</details>
