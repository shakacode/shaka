# Host support

Install the same Shaka skill in each host. The host supplies the model, tools,
permissions, and session storage; Shaka supplies the delivery procedure and GitHub
helpers. Installing Shaka does not change your account or model settings.

| Host | Skills directory | Start a task | Recorded evidence |
| --- | --- | --- | --- |
| Codex | `~/.agents/skills` | `$shaka` | CLI delivery and startup trials |
| Claude Code | `~/.claude/skills` | `/shaka` | One complete consumer delivery |
| Cursor | `~/.cursor/skills` | `/shaka` in a new Agent chat | CLI startup and captured usage payloads; full delivery unverified |
| OpenCode | `~/.config/opencode/skills` | `/shaka` | Launcher and usage reader implemented; full delivery unverified |
| Pi | Host's shared Agent Skill installation | Load the installed Shaka skill | Usage-reader delivery trial; broader use unverified |

The [validation record](project/host-validation.md) lists tested versions and the
limits of those trials. Follow [getting started](getting-started.md) for the source
installation. Keep the trusted source and installed links outside directories the
agent can edit.

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
fields; it does not save prompt text. [Usage reporting](agents/usage-reporting.md#what-the-cursor-reader-includes)
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

Agents should read [host operations](agents/host-operations.md) when launching
Codex/OpenCode or enumerating Claude Code tower sessions. [Usage reporting](agents/usage-reporting.md)
covers session selection, token categories, and attribution limits for each host.
