# Install Shaka manually

Run the installation yourself when you want to read what will run before it
runs. You need Ruby 3.4 or later, Git 2.41 or later, and an authenticated
[GitHub CLI](https://cli.github.com/). To let your coding agent do this instead,
use the [installation prompt](getting-started.md).

## What the installer changes

Shaka installs as one Git checkout that you keep only for Shaka, outside the
repositories your agent edits. The installer, [`bin/install`](https://github.com/shakacode/shaka/blob/main/bin/install),
is a Ruby script that uses only Ruby's standard library. It makes these changes:

- **Skill links.** It adds a `shaka` symbolic link in your coding agent's skills
  directory, pointing into the checkout. Nothing is copied.
- **Installation records.** It writes the checkout's origin, branch, and selected
  agents, plus the path of the Ruby that ran it, inside the checkout's `.git`
  directory. Shaka then runs with that Ruby in every project.
- **Lock files.** It leaves an empty `.shaka-install.lock` file in each skills
  directory it links.

It does not use `sudo`, edit your shell profile or `PATH`, or install gems.
It refuses a checkout or skills directory that other accounts can write to.

Commands record local timings in `~/.local/state/shaka/calls.jsonl`. The log holds
repository and PR identifiers, commits, reviewer models, and validation hashes;
it contains no paths or task text. PR descriptions publish their own
[timings](reference/timings.md). Set `SHAKA_CALL_LOG=off` to stop recording.

## Install

Clone the source. To install somewhere else, such as `~/agent-tools/shaka`,
change `SHAKA_DIR` on the first line. Keep it out of `~/.agents/`, which holds
settings; the installer refuses any folder there:

```bash
SHAKA_DIR="$HOME/.local/share/shaka/source"
umask 022
mkdir -p "$(dirname "$SHAKA_DIR")"
git clone https://github.com/shakacode/shaka.git "$SHAKA_DIR"
```

Read the source and `bin/install`, then run the installer in the same terminal.
It records the first `ruby` on your `PATH`, and `--directory` makes it register
the checkout you just read:

```bash
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" --agent codex
```

Replace `codex` with your coding agent, and repeat `--agent` to select several.
Each one adds this link:

| `--agent` | Skill link |
| --- | --- |
| `codex` | `~/.agents/skills/shaka` |
| `claude` | `~/.claude/skills/shaka` |
| `cursor` | `~/.cursor/skills/shaka` |
| `opencode` | `~/.config/opencode/skills/shaka` |

Pi has no option of its own; it loads the shared skill linked for `codex`.
`bin/install --help` lists the remaining options.

When it finishes, the installer prints where everything lives: the source
checkout and its commit, each skills folder it linked, and your settings. The
source checkout is not configuration. Settings live in each project's
`.agents/shaka/` folder and in `~/.agents/trusted-github-actors.yml`.

Start a new chat and look for **Shaka**. [Coding agents](coding-agents.md) shows
how to start a task in each one. Then continue with
[setup](getting-started.md#2-choose-individual-or-team-setup).

## Install your own fork

The commands above install ShakaCode's repository. To run a version you can
change, follow [Fork Shaka and make it yours](fork-and-hack.md). Pass
`--repository` with your fork's exact origin URL.

## Keep a tested release

Once a tested release is published, ask your agent:

> Install Shaka VERSION and keep my previous version available for rollback.

Replace VERSION with the published version you chose. Shaka keeps that release at
its recorded commit, even when development continues on `main`. Changing versions
uses a separate checkout and moves your skill links; the previous helper remains
available to active chats. Rollback points the links back to the retained version.

Release pinning refuses older tags that cannot maintain the installation record.

## Verify and update

Check the installation at any time, using the directory you installed into.
This command changes nothing in the checkout or your skill links:

```bash
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --verify
```

It confirms that the checkout comes from the recorded origin, has no local
changes, and is the target of each skill link, and that the recorded Ruby still exists.

When verification or an update refuses, or you are not sure which checkout your
agents use, ask for the installation state. It also changes nothing and works
offline:

```bash
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --status
```

The report names the active checkout, skill links, retained PR trials, and the
next command or decision. It also identifies older installations that need to
move to the dedicated source directory. `shaka doctor` reports the same state.

To have Shaka run those steps for you, ask it to repair the installation:

```bash
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --repair
```

Repair handles interrupted updates, broken links, missing Ruby, and conflicting
installation records. It preserves local commits on a `kept-<commit>` branch and
renames replaced records rather than deleting them. For links split between
checkouts, it selects the installation record changed most recently. Inspect
`install --status` first; repair stops when it needs your decision.

Shaka reports available updates once you are three commits behind or the oldest
missing change is a day old. Later commands repeat notices at most once a day,
without a network request. Notices also identify a moved checkout, an outdated
update check, missing project settings, or a doctor check you have not run.
Set `SHAKA_NOTICES=off` to silence them.

For a notice at the start of each Claude Code chat, add `--session-hook` to
`bin/install --agent claude`. It adds a `SessionStart` hook to
`~/.claude/settings.json`. Installing again without the flag removes the hook.

When an update is due, finish active Shaka chats, fetch and apply it, then start a new chat:

```bash
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --update
```

The update stops without changing the checkout when it finds local changes or
history that diverged from the recorded branch. To read an update before you
apply it, run `git fetch` in the checkout and compare `HEAD` with the recorded
branch, which is `origin/main` unless you chose another.

## Develop Shaka in a separate clone

Keep the installed checkout separate from the clone where you develop Shaka.
The installer refuses linked worktrees during installation, verification, and
updates. Extra branches or worktrees stop a new installation; verification and
updates warn about those instead.
See [Fork Shaka and make it yours](fork-and-hack.md) for development and contribution.

### Move Shaka out of a clone you develop in

From your development clone, create the dedicated installation:

```bash
./bin/install --directory ~/.local/share/shaka/source --take-over
```

The old clone keeps its files, branches, and worktrees. Before the new installation
record is saved, a failed move restores the earlier installation and reports
anything it could not restore. After a later failure, run `install --status`
to see which installation is active. For a custom skills directory when running
from another clone, add
`--skills-dir DIR`.

After a forced stop such as `kill -9`, no clone may count as installed. Rename
the newest `.git/shaka-install.retired-*.json` in the old clone to
`.git/shaka-install.json`, then retry the command.
