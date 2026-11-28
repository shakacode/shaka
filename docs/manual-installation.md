# Install Shaka manually

For most installations, ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka for this coding agent
Use the latest published stable release (1.0.0 or later). If none is published, install from source
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
gems. It refuses installation folders other accounts can write to. On Windows it checks only the
permissions Ruby reports, not the folder's access control list, so another account's write access
granted there goes unnoticed.

## Install

If you prefer the terminal, use Ruby 3.4 or later, Git 2.41 or later, and an
authenticated [GitHub CLI](https://cli.github.com/).

### Install a published release

For a first terminal installation with the gem, wait until the version appears in
[Shaka's RubyGems versions](https://rubygems.org/gems/shaka/versions) (agent
installations check GitHub releases directly).

```sh
gem install shaka --version 1.0.0
shaka-install _1.0.0_ --agent codex
```

`_1.0.0_` selects that gem version when several are installed. Replace `codex`
with your coding agent's `--agent` value from the table below. The
installer fetches the release tag and links the skill at that commit. Start a new
chat and run the [health check](getting-started.md#1-install-shaka).

If you are upgrading from a pilot installation to `1.0.0`,
[check your project settings](migration.md#check-your-projects-against-10) first.
For later `1.x` upgrades, see [what stays compatible in 1.x](migration.md#what-stays-compatible-in-1x)
and check against the exact release you plan to install if you want a pre-upgrade check.

### Install from source

Use the source checkout if the release you want is unavailable. Read the source
and [installer](https://github.com/shakacode/shaka/blob/main/bin/install) before
running it.

<details>
<summary>Manual installation commands</summary>

```bash
shaka_install_dir="$HOME/.local/share/shaka/source"
umask 022
mkdir -p "$(dirname "$shaka_install_dir")"
git clone https://github.com/shakacode/shaka.git "$shaka_install_dir"
```

On Windows, clone from PowerShell instead, so the checkout keeps the stored line endings the
installer needs to match the commit:

```powershell
$shaka_install_dir = "$HOME\.local\share\shaka\source"
git clone --config core.autocrlf=false --config core.eol=lf https://github.com/shakacode/shaka.git $shaka_install_dir
```

After reading the checkout, run its installer. On Windows, from PowerShell:

```powershell
ruby "$shaka_install_dir\bin\install" --directory $shaka_install_dir --agent codex
```

On macOS or Linux:

```bash
"$shaka_install_dir/bin/install" --directory "$shaka_install_dir" --agent codex
```

Keep the checkout outside `~/.agents/`, which holds settings.

</details>

### Coding agent options

Repeat `--agent` to install for several agents. Pi loads the shared skill linked
for `codex`. Pass `--skills-dir DIR` in place of `--agent` for a custom skills
directory.

| Agent | `--agent` | Skills directory |
| --- | --- | --- |
| Codex | `codex` | `~/.agents/skills` |
| Claude Code | `claude` | `~/.claude/skills` |
| Cursor | `cursor` | `~/.cursor/skills` |
| OpenCode | `opencode` | `~/.config/opencode/skills` |
| GitHub Copilot | `copilot` | `~/.copilot/skills` |

The installer links `shaka` inside each selected directory and reports which
checkout and skill links it uses. Start a new chat, check the installation, and
[set up your project](getting-started.md#2-set-up-your-project).

## Install your own fork

See [create and install a fork](fork-and-hack.md#fork-and-install) or
[install a fork you already have](fork-and-hack.md#install-a-fork-you-already-have).
The fork guide also shows how to switch back to the official version.

## Keep a tested release

```text
Install the latest published stable Shaka release if the installer supports it.
Keep my current version available for rollback
```

If no suitable stable release is available, ask the agent to explain the official
installation options before choosing one. When switching after a compatibility
check, replace `the latest published stable Shaka release` with the exact version
and verified checkout you checked. A release stays at its recorded commit.
The installer can keep the earlier version available while it moves the skill links.

## Verify and update

```text
Which Shaka version am I using, and is an update available?
```

The agent can check the source checkout, skill links, and Ruby. Shaka never
installs updates on its own; [keep Shaka up to date](keep-shaka-up-to-date.md)
shows how to schedule a daily update or update check. Finish active
Shaka chats before updating. Then ask the agent to update and verify the
installation, and start a new chat. Updates can stop if the installed checkout
has local changes or its history no longer matches the recorded branch.
Set `SHAKA_NOTICES=off` if you want to silence Shaka's local reminders. Installing
for Claude Code also adds a reminder at chat start: a `SessionStart` hook in your
user settings in `~/.claude/settings.json`.

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

Check the result with `"$shaka_helper" install --verify`. To inspect an update
to a branch installation, run `"$shaka_helper" install --status` and resolve any
origin or branch mismatch before fetching. Set `shaka_branch` to the branch
shown in the checkout inventory, such as `shaka_branch=main`. Run the following
from the installed checkout in Bash or Git Bash when no other process is fetching there.

```bash
git fetch origin "refs/heads/${shaka_branch:?Set the registered Shaka branch first}" &&
  shaka_fetched=$(git rev-parse --verify FETCH_HEAD) &&
  git log --oneline --left-right "HEAD...$shaka_fetched" &&
  git diff HEAD "$shaka_fetched"
```

The log shows commits on the installed side (`<`) and the branch side (`>`),
even if both versions have the same file contents. The comparison leaves your
installed files and skill links in place.
After active chats finish, run `"$shaka_helper" install --update` to apply a
branch update. The updater fetches the branch again when it runs.
For a pinned release, use the [tested release prompt](#keep-a-tested-release)
to install a newer release.

Before running `"$shaka_helper" install --repair`, check the status output.
If it proposes a take-over for a split installation, the command names the
checkout that will receive the skill links. Check which agents will switch.
If Claude Code's startup hook follows a link that moves, new Claude chats
will run the new checkout. Run repair if you want that move.
If status gives you a decision instead of a command, leave the links in place
and ask your agent to inspect the checkouts before you choose which to keep.

Repair keeps local commits on a `kept-<commit>` branch and renames unused
records so you can inspect them later. It deletes only the temporary checkout
left by an interrupted update. It stops when it needs a decision.

To remove Claude Code's startup reminder, run
`"$shaka_source/bin/install" --directory "$shaka_source" --agent claude --no-session-hook`.
To add the reminder back, run it with `--session-hook` in place of
`--no-session-hook`. That flag also adds the reminder with an installer from
before the reminder was on by default.

</details>

### Repair a broken installation

```text
Check my Shaka installation and help me fix what's broken.
Preserve my changes and tell me if you need a decision
```

The agent checks what your coding tool loads, fixes what it can, and verifies
the result. If an old checkout or local changes need a decision, it explains
what it found first. If your old installation lives in `~/.agents/shaka`, ask the
agent to move it to a dedicated checkout and verify the skill links. Keep the old
checkout until the new one works.

## Develop Shaka in a separate clone

```text
Set up a separate clone for developing Shaka. Keep my installed copy working
```

Your coding agent loads the installed checkout directly. A separate development
clone lets you change Shaka without breaking the version you use in other projects.
Avoid installing from a temporary worktree that could disappear after its PR merges.

### Move Shaka out of a clone you develop in

```text
Move my Shaka installation to its own checkout. Preserve my branches, worktrees,
and local changes. Verify the installation afterward
```

If you scheduled a daily check, [point it to the new checkout](keep-shaka-up-to-date.md#move-an-installation-with-a-scheduled-check)
after moving the installation.

The agent checks which copy is installed and explains what it needs to move.
Ask it to confirm your development work is still available before removing any
old checkout.

<details>
<summary>Move Shaka's skill links to a dedicated checkout</summary>

Run the command below from the checkout your coding agents currently use.
It moves every skill link registered to that checkout. Check which agents
will switch before you run it. A Claude Code startup hook that follows a
moved link will run the new checkout in new chats. The old checkout keeps
its files, branches, and worktrees.
Choose a destination with no linked worktrees or extra branches. If the default
directory is in use, choose a separate destination.

```bash
./bin/install --directory "$HOME/.local/share/shaka/source" --take-over
```

If you run it from another checkout and use a custom skills folder, pass
that folder with `--skills-dir`. Verify from the new checkout with
`./bin/install --verify`.

If the installer was force-stopped during the move and neither checkout has an
active installation record, restore the newest
`.git/shaka-install.retired-*.json` in the old checkout to
`.git/shaka-install.json`. Retry with the same source and destination options,
then verify. If either checkout still has an active record, leave it in place
and check the installation state before retrying.

</details>
