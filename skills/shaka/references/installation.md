# Install and maintain Shaka

Use this procedure when the user asks to install, upgrade, or remove Shaka.
The [getting started guide](https://github.com/shakacode/shaka/blob/main/docs/getting-started.md) supplies the prompts.
Use source installation: the published name-reservation gem
predates the current workflow. Confirm the requested source, version, and coding
environment before installation. Preserve existing customizations during updates.
Shaka is the successor to `shakacode/agent-workflows`; new installations need only
this repository.

## Prerequisites

You need Ruby 3.4, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
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
registered installation or managed package, `scripts/shaka` uses `ruby` from `PATH`.

Optional: [ImageMagick 7](https://imagemagick.org/script/download.php) can draw
[annotations and pixel diagnostics](visual-diff.md). Check it with `magick --version`.
Agents can also use an existing editor or browser overlay; ImageMagick is not required.

## Install

Review the source and installer, then clone into a directory outside the
repositories your agent will edit:

```bash
mkdir -p "$HOME/.local/share/shaka"
git clone https://github.com/shakacode/shaka.git "$HOME/.local/share/shaka/source"
"$HOME/.local/share/shaka/source/bin/install" --agent codex
```

Default: `~/.local/share/shaka/source`; respect chosen locations with `--directory DIR`.
Keep it for direct links and develop separately. `~/agent-tools/shaka` is an optional example.

<a id="use-shaka-in-claude-code"></a>
<a id="use-shaka-in-cursor"></a>
<a id="use-shaka-in-opencode"></a>

| `--agent` | Skill links | Invocation |
| --- | --- | --- |
| `codex` (default) | `~/.agents/skills` | `$shaka` |
| `claude` | `~/.claude/skills` | `/shaka` |
| `cursor` | `~/.cursor/skills` | `/shaka` in a new Agent chat |
| `opencode` | `~/.config/opencode/skills` | `/shaka` in a new session |

Repeat `--agent` for several hosts, or use `--skills-dir DIR` for a custom directory.
Add `--with-rct` for the Codex tower or `--with-claude-towers` for Claude towers.
Reinstallation preserves recognized towers and registered hosts. Start a new chat
and look for **Shaka**; restart the host if its list is stale.

## Configure a repository

After installing, follow [repository setup](repository-setup.md), then run
`shaka doctor --root /path/to/repository` from the trusted installed helper.
Resolve failed checks before publishing work.

## Verify and update

Use the registered helper with your chosen path:

```bash
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --verify
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --update
```

Verification is read-only and checks checkout identity, clean status, links, and Ruby.
Update checks these before fetching and fast-forwarding the recorded origin branch. Dirty tracked or untracked files, unexpected checkout changes,
and divergent updates stop it. Preserve changes in a development checkout;
do not reset them to make installation succeed. Repair missing Ruby records by
running `bin/install` with Ruby 3.4 or later.

Pause active chats before updating this mutable path. Doctor reads recorded identity;
verification rechecks it. Project settings use [repository migration](migration.md).

## Migrate retained-copy installations

When the user selects migration:

1. Select the dedicated directory. Clone the current official source there, or
   bring an existing clean, expected checkout to the current default branch before
   first registration. Stop for local changes or an unexpected remote.
2. Run its new `bin/install --directory DIR` with every selected `--agent`, or
   the original custom `--skills-dir`. Recognized tower links migrate too.
3. Run its helper's `install --verify` and confirm Shaka in a new chat.

Canonical Codex installation retires verified `~/.codex/skills` aliases after
`~/.agents/skills` links succeed. This covers the standard managed directory
and selected checkout; inspect other duplicates and preserve intentional trials.
Keep every older package: active chats may reference its absolute paths.

## Teams and forks

Use [team instructions](https://github.com/shakacode/shaka/blob/main/docs/migration.md#teams-and-forks).
For forks, register `--repository URL` and optionally `--branch NAME`.
Publish upstream integrations from a development checkout before updating.

## Separate PR trials and retained copies

Use [PR trials](https://github.com/shakacode/shaka/blob/main/docs/trying-pr-versions.md)
for intentional evaluation. They retain packages with version labels and absolute
invocations without changing default links. Explicit legacy operations remain:

```bash
/path/to/source/bin/install --managed --skills-dir DIR [--managed-dir DIR]
/path/to/source/bin/install --skills-dir DIR --rollback PACKAGE_ID [--managed-dir DIR]
```

Include the rollback package's tower flags. Use the updated installer for rollback of labeled packages.
No automatic cleanup or expiry exists. Only discoverable links add menu entries.
Keep copies used by chats or needed for rollback; an unlinked copy can still be in use.

## Remove

Inspect the link first and confirm it points to your selected Shaka installation:

```bash
ls -l "$HOME/.agents/skills/shaka"
```

Then remove that link:

```bash
unlink "$HOME/.agents/skills/shaka"
```

Use the appropriate directory for other environments. If you installed tower skills,
inspect and remove their links too: `rct`, or `mct-claude` and `rct-claude`.
Preserve unrelated files. Removing skill links leaves repositories and PRs intact.
After every Shaka link in that skills directory is removed and no install is
running, remove its `.shaka-install.lock` file too.
Managed copies remain available for rollback; remove one only after no host link
or active task uses it.

## Development environment details

Use the following sections for terminal launchers, usage hooks, and environment
limitations. Basic installation uses the directories above.

## Codex

In the app, open a task in your repository and invoke `$shaka`.

For a terminal session, the optional launcher creates a separate session directory
and gives the Codex sandbox write access to that directory and your checkout:

```bash
"$HOME/.local/share/shaka/source/bin/install" --skills-dir "$HOME/.local/share/shaka-pilot/skills"
"$HOME/agent-tools/shaka-pilot/skills/shaka/scripts/shaka" work \
  --repo /path/to/repository "Fix the failing search test. Use Ask."
```

Replace the path and task. Native trust and command-approval prompts still apply.
The launcher refuses paths that overlap the trusted installation. Choose a
`TMPDIR` outside the checkout if your current one is inside it.

The optional `rct` skill needs the **Codex app's** task tools. Install it with
`--with-rct`; terminal-only installations use the [control-tower role prompts](control-towers.md#role-prompts).

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

Start a new chat after changing hooks. User-level hooks run from `~/.cursor`, so
this relative path reaches the installed skill. The hook saves aggregate usage
fields; it does not save prompt text. When this conversation already published a
description, the hook then fills that description's Cursor usage row.
[Usage reporting](usage-reporting.md#what-the-cursor-reader-includes)
explains what is counted.

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

## Operating details

Agents should read [launchers and agent sessions](launchers-and-sessions.md) when launching
Codex/OpenCode or enumerating Claude Code tower sessions. [Usage reporting](usage-reporting.md)
covers session selection, token categories, and attribution limits for each host.
