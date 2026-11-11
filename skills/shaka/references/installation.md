# Installation details

Use [official installation](official-installation.md) to install, update, and verify Shaka.
This reference covers prerequisites, forks, removal, and each coding host.
The [getting started guide](https://github.com/shakacode/shaka/blob/main/docs/getting-started.md) supplies the prompts.
Use source installation: the published name-reservation gem
predates the current workflow. Confirm the requested source, version, and coding
environment before installation. Preserve existing customizations during updates.
Shaka is the successor to `shakacode/agent-workflows`; new installations need only
this repository.

## Prerequisites

You need Ruby 3.4, Git 2.41 or later, an authenticated [GitHub CLI](https://cli.github.com/), and
a [supported coding agent](installation.md#development-environment-details).

```bash
git --version
ruby --version
gh auth status
```

Use `gh auth login` if you are not signed in.

Shaka keeps its own Ruby, separate from your projects. The installer records the
Ruby that runs it, and the installed `scripts/shaka` starts with that Ruby in every
project. It also ignores a project's `RUBYOPT`, Bundler setup, and installed gems,
because Shaka needs only Ruby's standard library. Run the installer where
`ruby --version` reports 3.4 or later; an older Ruby stops with that requirement.
If that Ruby or its record is removed, `scripts/shaka` stops and asks you to
install again or set `SHAKA_RUBY` to another Ruby 3.4 interpreter. Without a
registered installation or PR trial package, `scripts/shaka` uses `ruby` from `PATH`.

Optional: [ImageMagick 7](https://imagemagick.org/script/download.php) can draw
[annotations and pixel diagnostics](visual-diff.md). Check it with `magick --version`.
Agents can also use an existing editor or browser overlay; ImageMagick is not required.

## Install from a personal fork

When the user requests a fork, create or select it on GitHub. Create and push a
dedicated branch, such as `mine`, so the fork's `main` can follow upstream.
With no registered installation, clone the fork directly at its install branch
with `git clone --branch BRANCH URL DIR`. Review that source and installer before
running `bin/install --directory DIR --repository URL --branch BRANCH --agent HOST`
with that prepared checkout. Keep the fork as `origin` and add the official
repository with `git -C DIR remote add upstream https://github.com/shakacode/shaka.git`.
See [official installation](official-installation.md) for prerequisites.

To switch sources, record the active directory, origin, branch or release,
revision, linked hosts and skills directories, and any Shaka Claude Code
`SessionStart` hook. Take-over moves every registered link. If Claude's hook
follows one of those links, it will run the new source at chat startup.
Explain the effect before switching. If the request covers only one host,
show the wider scope and ask before proceeding.

If the previous checkout is under `~/.agents/shaka`, it cannot be a take-over
destination. Explain this before switching. If rollback is required, identify
a supported directory and verify the saved source and revision are still
installable there before moving any links.
Clone the actual destination directly at the selected branch with
`git clone --branch BRANCH URL DIR`, or prepare it at the selected release.
For a fork, add the official repository as `upstream`.
Inspect that revision before invoking take-over, which runs the incoming
helper. Pass the prepared checkout as the destination.

From the currently registered checkout's trusted installer, run
`bin/install --take-over --directory DIR --repository URL --branch BRANCH`;
use `--release VERSION` for a pinned release. Keep the old checkout and remotes
intact. Run `bin/install --verify` from the newly active checkout. If take-over
reports an error, check which checkout owns the links before retrying.

To switch back, use the retained checkout if it is a supported destination.
Otherwise prepare a supported checkout at the saved revision. In the actual
destination, check the saved origin and branch or release and compare
`git -C DIR rev-parse HEAD` with the saved commit. Stop before take-over
if the destination is empty, the source differs, or HEAD does not match.

Use a trusted installer, such as the retained official checkout's
`bin/install`. Pass the checked destination with `--directory`, the saved
URL with `--repository`, and the saved `--branch` or `--release`.
Pass `--skills-dir DIR` for an active custom skills directory so the
installer can locate the owner. Verify the restored source and revision.

Before updating, confirm that `origin` points to the user's fork and
`upstream` points to `shakacode/shaka`. Add the official `upstream` if it is
missing. If either remote points to a different repository, stop and report
the mismatch before fetching or integrating changes.
Fetch upstream and inspect the diff. Fast-forward when possible.
Keep the installed branch's history intact. Preserve fork changes by merging
or rebasing on a feature branch, then merge into the installed branch.
Use `install --update` when the latest branch tip is acceptable. It fetches
and verifies the tip it receives.

When the user asks to install the tested or inspected commit, use take-over.
Clone directly at the install branch in a separate directory. In that clean
clone, run `git -C DIR reset --keep TESTED_SHA` to set the branch to the tested
commit while keeping its `origin/BRANCH` tracking configuration. Before
take-over, verify the checkout is clean, the branch tracks `origin/BRANCH`,
and HEAD matches the tested commit. Stop if the commit is unavailable or a
check fails.
`install --update` can fetch and run a newer revision if the branch advances
after testing.

Verify the installed revision before starting a new chat. Contribute improvements through a branch
and PR to upstream when the user authorizes that publication. Never overwrite
local customizations to make an update succeed.

## Configure a repository

After installing, follow [repository setup](repository-setup.md), then run
`shaka doctor --root /path/to/repository` from the trusted installed helper.
Resolve failed checks before publishing work.
`shaka doctor --installation-json` prints the installed version, package ID, and
source identity without checking a repository. A source records an exact revision
only when it is the repository root, its selected file set matches `HEAD`, its
selected paths have clean Git status, the file bytes and executable modes match
`HEAD`, each selected directory contains a tracked file, and no selected file is
world-writable. A Git-clean checkout with converted line endings can therefore
record a development installation. Development installations record a base
revision when available and a content hash.
Doctor reports the identity recorded at install time; it does not recheck the
installed files or compare the recorded revision with Git on each run.

## Remove

Inspect the link first and confirm it points into the Shaka checkout:

```bash
ls -l "$HOME/.agents/skills/shaka"
```

Then remove that link:

```bash
unlink "$HOME/.agents/skills/shaka"
```

Use the appropriate directory for other environments. If you installed tower skills,
inspect and remove their links too: `mct` and `rct`, or `mct-claude` and `rct-claude`.
Preserve unrelated files. Removing skill links leaves repositories and PRs intact.
After every Shaka link in that skills directory is removed and no install is
running, remove its `.shaka-install.lock` file too.

When the user wants to remove a duplicate menu entry, inspect `shaka` links in every
skills directory their host reads. For example, Codex can discover both
`~/.agents/skills/shaka` and an older `~/.codex/skills/shaka`. Unlink the unwanted entry
using the procedure above, preserving the desired entry. Start a new chat or restart the
host if its skill list still shows the removed link. PR trial packages add no host links;
delete one only after every chat pinned to its paths has finished.

## Development environment details

Use the following sections for terminal launchers, usage hooks, and environment
limitations. [Official installation](official-installation.md) lists each host's skills directory.

## Codex

In the app, open a task in your repository and invoke `$shaka`.

For a terminal session, the optional launcher creates a separate session directory
and gives the Codex sandbox write access to that directory and your checkout:

```bash
"$HOME/.local/share/shaka/source/bin/install" --skills-dir "$HOME/agent-tools/shaka-pilot/skills"
"$HOME/agent-tools/shaka-pilot/skills/shaka/scripts/shaka" work \
  --repo /path/to/repository "Fix the failing search test. Use Ask."
```

Replace the path and task. Native trust and command-approval prompts still apply.
The launcher refuses paths that overlap the trusted installation. Choose a
`TMPDIR` outside the checkout if your current one is inside it.

The optional `mct` and `rct` skills need the **Codex app's** task and project tools.
Select them independently with `--with-mct` and `--with-rct`; terminal-only installations use the [control-tower role prompts](control-towers.md#role-prompts).

## Claude Code

Install into `~/.claude/skills`, then start `claude` in your repository and invoke
`/shaka`. Shaka has no Claude Code launcher. Your existing permission mode applies;
keep its trusted source outside the checkout and any writable `--add-dir` path.

The desktop app can also use `mct-claude` and `rct-claude`. Install them with
`--with-claude-towers` and follow [control-tower setup](control-towers.md).
Those skills require desktop session tools and cannot run in the terminal CLI.

## Cursor

Install into `~/.cursor/skills` and start a new Agent chat to confirm discovery.
The recorded trial did not discover the skill through `~/.agents/skills`.

To save token usage, add this entry to the `stop` array in `~/.cursor/hooks.json`,
preserving existing hooks:

```json
{
  "command": "skills/shaka/scripts/cursor-usage-hook"
}
```

On Windows, use the launcher instead. Cursor cannot run the extensionless script, and the hook
process may not have `ruby` on its PATH. The launcher finds `ruby.exe` from the user or machine PATH.
If that search fails, it writes `cursor-usage-hook: ruby.exe was not found` to standard error and exits
with status 1.

```json
{
  "command": "skills/shaka/scripts/cursor-usage-hook.cmd"
}
```

Start a new chat after changing hooks. User-level hooks run from `~/.cursor`, so
this relative path reaches the installed skill. The hook saves aggregate usage
fields; it does not save prompt text. When this conversation already published a
description, the hook then fills that description's Cursor usage row.
[Usage reporting](usage-reporting.md#what-the-cursor-reader-includes)
explains what is counted.

## GitHub Copilot

Select `--agent copilot` with the [official installer](official-installation.md#install).
Start a new Copilot CLI session or VS Code Agent chat and invoke `/shaka`.
In Copilot CLI, use `/skills list` to check discovery and `/skills info` to inspect
its location.
For limitations and supported surfaces, see the [Copilot guide](https://github.com/shakacode/shaka/blob/main/docs/coding-agents.md#github-copilot).

## OpenCode

Use `~/.config/opencode/skills` to avoid overlapping compatibility installations.
Keep the skill outside the repository's `.opencode/skills`, where candidate code
could replace it.

You can also start the interactive TUI through the installed helper:

```bash
"$HOME/.config/opencode/skills/shaka/scripts/shaka" work \
  --host opencode --repo /path/to/repository "Fix the failing search test. Use Ask."
```

The launcher disables project-local OpenCode configuration, plugins, and
instructions. Trusted global configuration still loads, and your existing
permissions apply. Account and model settings are unchanged.

For usage, provide the session ID from `opencode session list`:

```text
shaka usage --host opencode --session ses_ID --commit FULL_COMMIT_SHA --contribution implementation
```

## Pi

Pi uses the shared skill and its existing tool permissions. There is no separate
Pi launcher or tower skill. Its usage reader needs a persistent v3 session with
matching `PI_SESSION_FILE` and `PI_SESSION_ID` values. Missing or unsupported
records produce `UNKNOWN`.

For actual session renaming, manually add the installed skill's absolute
`extensions/pi-session-name.js` path to the `extensions` array in your personal Pi
settings file (`~/.pi/agent/settings.json`, or under `PI_CODING_AGENT_DIR`). Preserve
existing settings and extension entries. For example:

```json
{
  "extensions": ["/absolute/trusted/skills/shaka/extensions/pi-session-name.js"]
}
```

Keep this path outside candidate checkouts. Run `/reload` in Pi after changing settings.
The extension exposes `shaka_session_name`; omit `name` to read the current title or
supply it to request a rename. It changes session metadata through Pi's API, not the
terminal window title. Follow [chat naming](launchers-and-sessions.md#name-the-chat).
Without the extension, the workflow prints a suggested title only. Shaka's installer
does not register the extension automatically. No additional npm packages are needed.

## Operating details

Agents should read [launchers and agent sessions](launchers-and-sessions.md) when launching
Codex/OpenCode or enumerating Claude Code tower sessions. [Usage reporting](usage-reporting.md)
covers session selection, token categories, and attribution limits for each host.
