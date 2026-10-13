# Install Shaka manually

Run the installation yourself when you want to read what will run before it
runs. You need Ruby 3.4 or later, Git, and an authenticated
[GitHub CLI](https://cli.github.com/). To let your coding agent do this instead,
use the [installation prompt](getting-started.md#getting-started).

## What the installer changes

Shaka installs as one Git checkout that you keep only for Shaka, outside the
repositories your agent edits. The installer, [`bin/install`](https://github.com/shakacode/shaka/blob/main/bin/install),
is a Ruby script that uses only Ruby's standard library. It makes these changes:

- **Skill links.** It adds a `shaka` symbolic link in your coding agent's skills
  directory, pointing into the checkout. Nothing is copied.
- **Installation records.** It writes the checkout's origin, branch, and selected
  agents, plus the path of the Ruby that ran it, inside the checkout's `.git`
  directory. Shaka then runs with that Ruby in every project.
- **Older Codex links.** For Codex, it removes a `shaka` link from
  `~/.codex/skills` when that link points at this checkout or at a Shaka copy an
  earlier installer made. It leaves every other entry alone.

It does not use `sudo`, edit your shell profile or `PATH`, or install gems.
It refuses a checkout or skills directory that other accounts can write to.

## Install

Clone first, read the source and `bin/install`, then run it with the Ruby you
want Shaka to keep using:

```bash
umask 022
mkdir -p "$HOME/.agents"
git clone https://github.com/shakacode/shaka.git "$HOME/.agents/shaka"
"$HOME/.agents/shaka/bin/install" --agent codex
```

Replace `codex` with your coding agent, and repeat `--agent` to select several:

| `--agent` | Skill link | Start a task |
| --- | --- | --- |
| `codex` | `~/.agents/skills/shaka` | `$shaka` |
| `claude` | `~/.claude/skills/shaka` | `/shaka` |
| `cursor` | `~/.cursor/skills/shaka` | `/shaka` in a new Agent chat |
| `opencode` | `~/.config/opencode/skills/shaka` | `/shaka` in a new session |

Pi has no option of its own; it loads the shared skill linked for `codex`.
To clone somewhere else, such as `~/agent-tools/shaka`, change both paths.
`bin/install --help` lists the remaining options.

Start a new chat and look for **Shaka**, then continue with
[setup](getting-started.md#2-choose-individual-or-team-setup).

## Verify and update

Check the installation at any time. This command changes nothing:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --verify
```

It confirms that the checkout comes from the recorded origin, has no local
changes, and is the target of each skill link, and that the recorded Ruby still exists.

Shaka tells you when an update is available. Finish active Shaka chats, then
fetch and apply it:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --update
```

The update stops without changing the checkout when it finds local changes or
history that diverged from the recorded branch. To read an update before you
apply it, run `git fetch` in the checkout and compare `origin/main` with `HEAD`.
Start a new chat afterward.
