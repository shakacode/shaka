# Install and maintain Shaka

Use this procedure when the user asks to install, upgrade, or remove Shaka.
The [getting started guide](../getting-started.md) supplies the prompts.
Use source installation during the pilot: the published name-reservation gem
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

## Install

Review the source and installer, then clone into a directory outside the
repositories your agent will edit:

```bash
mkdir -p "$HOME/agent-tools"
git clone https://github.com/shakacode/shaka.git "$HOME/agent-tools/shaka"
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills"
```

This installs a link for Codex. Open a new task in your project and look for
`$shaka`; restart Codex if it does not appear.

<a id="use-shaka-in-claude-code"></a>
<a id="use-shaka-in-cursor"></a>
<a id="use-shaka-in-opencode"></a>
## Other development environments

Use the same installer with your environment's skills directory:

| Environment | `--skills-dir` | Invocation |
| --- | --- | --- |
| Claude Code | `"$HOME/.claude/skills"` | `/shaka` |
| Cursor | `"$HOME/.cursor/skills"` | `/shaka` in a new Agent chat |
| OpenCode | `"$HOME/.config/opencode/skills"` | `/shaka` in a new session |

Keep the source and links outside the agent's writable directories. See
[environment details](#development-environment-details) for terminal launchers, Pi, Cursor usage hooks,
and tested limitations.

## Configure a repository

After installing, follow [repository setup](repository-setup.md), then run
`shaka doctor --root /path/to/repository` from the trusted installed helper.
Resolve failed checks before publishing work.

## Upgrade

Inspect and preserve local changes in the trusted checkout, then fast-forward:

```bash
git -C "$HOME/agent-tools/shaka" status --short
git -C "$HOME/agent-tools/shaka" switch main
git -C "$HOME/agent-tools/shaka" pull --ff-only
```

Start a new task after upgrading. Installed links use the updated source.
Run the installer again with your original options if you want newly added skills.
Pilot configuration changes may also require a repository migration.

## Remove

Inspect the link first and confirm it points to this Shaka installation:

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

## Development environment details

Use the following sections for terminal launchers, usage hooks, and environment
limitations. Basic installation uses the directories above.

## Codex

In the app, open a task in your repository and invoke `$shaka`.

For a terminal session, the optional launcher creates a separate session directory
and gives the Codex sandbox write access to that directory and your checkout:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/agent-tools/shaka-pilot/skills"
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
fields; it does not save prompt text. [Usage reporting](usage-reporting.md#what-the-cursor-reader-includes)
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

Agents should read [host operations](host-operations.md) when launching
Codex/OpenCode or enumerating Claude Code tower sessions. [Usage reporting](usage-reporting.md)
covers session selection, token categories, and attribution limits for each host.
