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
Set `SHAKA_NOTICES=off` if you want to silence Shaka's local reminders.

<details>
<summary>Check or update from a terminal</summary>

For the default installation, locate the helper and check it:

```bash
shaka_helper="$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka"
"$shaka_helper" install --status
"$shaka_helper" install --verify
```

Use the corresponding path if you installed elsewhere. After active chats finish,
run `"$shaka_helper" install --update` if you choose to update. For a broken
installation, `"$shaka_helper" install --repair` checks for recoverable problems
and stops when it needs a decision.

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
<summary>If the installer was force-stopped while moving the checkout</summary>

If the old checkout has no active installation record and the new checkout is
unregistered, restore the newest `.git/shaka-install.retired-*.json` in the old
checkout to `.git/shaka-install.json`. Then retry the move and verify the skill
links. Leave any active record in place and ask the agent to inspect the state
if either checkout still has one.

</details>
