# Install Shaka manually

Run the installation yourself when you want to read what will run before it
runs. You need Ruby 3.4 or later, Git, and an authenticated
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
- **Older Codex links.** For Codex, it removes a `shaka` link from
  `~/.codex/skills` when that link points at this checkout or at a Shaka copy an
  earlier installer made. It leaves every other entry alone.
- **Lock files.** It leaves an empty `.shaka-install.lock` file in each skills
  directory it links.

It does not use `sudo`, edit your shell profile or `PATH`, or install gems.
It refuses a checkout or skills directory that other accounts can write to.

Afterward, each Shaka command adds a line to a timing log at
`~/.local/state/shaka/calls.jsonl`. The log stays on your machine and holds no
arguments, paths, or task text. Set `SHAKA_CALL_LOG=off` to stop recording.

## Install

Clone the source. To install somewhere else, such as `~/agent-tools/shaka`,
change `SHAKA_DIR` on the first line:

```bash
SHAKA_DIR="$HOME/.agents/shaka"
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

Start a new chat and look for **Shaka**. [Coding agents](coding-agents.md) shows
how to start a task in each one. Then continue with
[setup](getting-started.md#2-choose-individual-or-team-setup).

## Verify and update

Check the installation at any time, using the directory you installed into.
This command changes nothing in the checkout or your skill links:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --verify
```

It confirms that the checkout comes from the recorded origin, has no local
changes, and is the target of each skill link, and that the recorded Ruby still exists.

Shaka tells you when an update is available. Finish active Shaka chats, fetch
and apply it, then start a new chat:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --update
```

The update stops without changing the checkout when it finds local changes or
history that diverged from the recorded branch. To read an update before you
apply it, run `git fetch` in the checkout and compare `HEAD` with the recorded
branch, which is `origin/main` unless you chose another.

## Install your own fork

Install a fork to change Shaka itself and use your version in every project.
Project commands, settings, and review criteria need no fork; see
[where project rules go](faq.md#where-do-i-put-project-rules). To try one
unmerged change on a single task, [try a Shaka PR](trying-pr-versions.md).

Fork the repository and clone the fork. Put your changes on a branch of their
own, so your fork's `main` stays the same as Shaka's. Create and push that
branch before you install:

```bash
gh repo fork shakacode/shaka --clone=false
FORK_URL="https://github.com/YOUR-LOGIN/shaka.git"
SHAKA_DIR="$HOME/.agents/shaka"
umask 022
mkdir -p "$(dirname "$SHAKA_DIR")"
git clone "$FORK_URL" "$SHAKA_DIR"
git -C "$SHAKA_DIR" remote add upstream https://github.com/shakacode/shaka.git
git -C "$SHAKA_DIR" switch -c mine
git -C "$SHAKA_DIR" push -u origin mine
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" --repository "$FORK_URL" \
  --branch mine --agent codex
```

`--repository` must match the clone's `origin` URL exactly. Otherwise the
installer stops with `Installation origin differs from the selected repository`.
Using `FORK_URL` for both keeps them equal; for SSH, set it to your SSH URL.

Leave the installed checkout unedited, because `install --update` stops when it
has local changes. Make changes in a separate clone of your fork with the same
`upstream` remote, run `.agents/shaka/bin/validate` there, and push them to `mine`.
[Developing Shaka](https://github.com/shakacode/shaka/blob/main/contributing/development.md)
explains the source tree. Then run `install --update` as shown above.

Shaka's update notice does not count new Shaka commits for a fork, and
`install --update` only fast-forwards to your fork's `mine`. To bring in Shaka's
changes, merge them in your working clone:

```bash
git fetch upstream
git switch mine
git merge upstream/main
.agents/shaka/bin/validate
git push origin mine
```

Merge rather than rebase. After a rebase and force-push, `install --update`
stops with `Not possible to fast-forward` and keeps the previous commit.

To send a change to Shaka, branch from `upstream/main` instead of `mine`, and
open the PR against `shakacode/shaka`. Read
[Contributing](https://github.com/shakacode/shaka/blob/main/CONTRIBUTING.md) first.
