# Host support

Codex CLI is the reference host for this pilot and Claude Code the second host.
OpenCode is the third host: its canonical install path, TUI launcher, and
export-based usage reader are implemented. Follow the [getting-started guide](getting-started.md)
for installation and your first task. Neither Claude Code, Cursor, nor OpenCode
has a verified complete V2 consumer delivery yet.

The hosts share one `shaka` skill and the same Ruby helpers for GitHub
operations. The optional `rct` skill currently requires the Codex app's native
project, task, pin, follow-up, and wait tools, so install it only there with
`--with-rct`. Your repository keeps its existing `AGENTS.md`, commands, and policy.
Host-specific work covers installation, instruction loading, execution permissions,
and reading native usage records. It does not create three copies of the workflow.

## What has been verified

These observations were made on September 14 and 15, 2026. A successful install or CLI
startup does not establish a complete workflow, and workflow success does not
establish complete usage attribution.

| Capability | Codex CLI 0.154.0 | Claude Code desktop 2.1.270, CLI 2.1.272 | Cursor CLI 2026.09.10-fd3934a | OpenCode 1.18.31 |
| --- | --- | --- | --- | --- |
| Installation and startup | Dedicated skill installation and explicit trusted-file startup checked. | A symlinked personal skill loaded in the desktop app and in `claude -p`; `/shaka` asked for the task and merge preference and stopped before edits. A same-named repository skill did not replace it. | Dedicated CLI package version/help checked; V2 instruction activation unverified. | Canonical `~/.config/opencode/skills` install documented; TUI activation trial pending. |
| OS write boundary | A native workspace sandbox denied writes to the separate trusted source, installed link, and link directory while allowing the session and target checkout. | No launcher or sandbox; the user's permission mode applies. Not separately probed. | Native V2 sandbox boundary unverified. | No launcher sandbox; the user's permission mode applies. Not separately probed. |
| Real workflow | Protected PR operations exercised in V2. A fresh CLI task implemented and verified the Astro website guides using its repository instructions; the owning task handled publication. | Consumer delivery unverified. | Consumer delivery unverified. | Consumer delivery unverified. |
| Usage | Reader matched 14 real CLI responses and repeated-source input without double counting; attribution remains partial. | Reader matched an independent per-response aggregate for a desktop session with a subagent and two models, and Claude Code's own totals for two CLI runs. | Stop-hook reader exercised against desktop `3.20.21` `grok-4.6` payloads; transcripts and bubble `tokenCount` remain unused. | Export reader matched an independent per-response aggregate for a real 49-response session (all counters, interval, version); the session must be named with `--session` and attribution remains partial. |

The Codex write test establishes that particular local boundary. It does not
establish equivalent behavior in the desktop app, other versions, or other hosts.
Repeated consumer use, including failed checks, changed PR heads, and Ask/Auto
stopping behavior, is still required before claiming broader adoption.

## Codex first

Use the canonical [startup instructions](getting-started.md).
Keep the trusted workflow source and installed link outside both the writable
session directory and target checkout. The guided startup names the trusted skill for the agent; do not add a discovery
link inside the writable session.

The launcher or direct invocation must establish the intended permissions even
when the user's existing configuration grants broader access. Temporary writable
directories also count: placing the trusted skill in a system temporary directory
can undermine an otherwise separate installation. See the
[Codex permissions documentation](https://learn.chatgpt.com/docs/permissions)
for the host's controls; the getting-started guide owns the tested V2 recipe.

## Startup boundary and current validation

Each launch creates a private temporary session outside the consumer checkout,
reads the trusted skill by its absolute source path, and directs repository
commands to the checkout. It adds no skill link to that writable session. The
launcher rejects canonical or lexical overlaps between writable paths and the
trusted source or installed command/link parents. If your `TMPDIR` is inside the
target checkout, choose a temporary directory outside it before launching.

The native shell sandbox permits writes in the session and target checkout,
overrides extra writable roots, excludes ambient temporary directories, and uses
approval prompts for this launch. It sets shell `TMPDIR` and zsh `TMPPREFIX`
inside the session's temporary directory. It leaves authentication and model settings
alone. Session scratch stays in the system temporary directory after Codex exits;
the launcher leaves no background process. Codex still shows its native directory
trust and command-approval prompts; the launcher does not bypass them.

On Codex CLI 0.154.0, separate startup and native sandbox probes kept candidate
skill metadata out of the initial prompt and denied writes to the trusted source,
installed link, and link parent while permitting session and checkout writes.
A live terminal trial verified temporary-file access, protected-file write denial,
and automatic native usage discovery. A separate native sandbox check reproduced
and corrected zsh heredoc failures using the session temp prefix. Launcher tests
verify the executed arguments and path refusals. App startup,
other host versions, and complete isolation remain unverified. The sandbox does
not establish that dependencies are trustworthy or remove secrets from published
text. Do not approve an escape merely to make a check pass.

## Claude Code

Use the [Claude Code install recipe](getting-started.md#use-shaka-in-claude-code).
Claude Code runs a personal skill instead of a same-named skill in a repository's
`.claude/skills`, as its [skill locations](https://code.claude.com/docs/en/skills)
document; the September 15 trial confirmed this with a canary repository copy.
There is no `shaka work` launcher for Claude Code. Start `claude` in the repository,
keep the trusted source outside any `--add-dir` directory, and rely on the permission
mode you already use. The next required evidence is a complete ordinary consumer PR
delivered with `/shaka`.

## Cursor

Keep an existing, authenticated host configuration in place when preparing a
compatibility trial. Check its version and available controls before starting.
Native `SKILL.md` support is [documented for Cursor](https://cursor.com/docs/skills),
but shared file format alone does not prove V2 activation or safe execution.

Cursor user skills can be installed at `~/.cursor/skills` with the standard
installer. A September 14 trial did not find the skill through `~/.agents/skills`,
so use the Cursor-specific directory and still confirm discovery in a new Agent chat.
The trial did not establish a complete Cursor workflow or a supported launch recipe.

The checked Cursor CLI exposes `--workspace`, `--add-dir`, `--sandbox`, and
`--plugin-dir`. Its public help has no direct skill-file option. The native sandbox
and V2 delivery have not been exercised, so these flags are not sufficient grounds
for a supported launch recipe.

Inspect the targets in the [official Cursor installation instructions](https://cursor.com/docs/cli/installation)
before installing. The inspected upstream installer creates both `agent` and
`cursor-agent` commands; those names can collide with another installed tool.
Prefer an existing signed-in host for a trial. The dedicated package startup check
did not change global command links or establish a general installation method.

## OpenCode

Use the [OpenCode install recipe](getting-started.md#use-shaka-in-opencode).
The canonical global directory is `~/.config/opencode/skills`; the
`~/.claude/skills` and `~/.agents/skills` compatibility directories also load,
so prefer the canonical path to avoid shadowing. Do not copy the skill into a
project `.opencode/skills` directory inside a candidate checkout: a later source
overrides the same skill ID. Keep the trusted source outside the working
directory and rely on the permission mode you already use.

`shaka work --host opencode --repo /path/to/repository "task"` starts the
interactive TUI in that repository with the trusted workflow prompt; OpenCode
keeps its own sessions outside the checkout, so the launcher creates no separate
session directory. It refuses a target that overlaps the trusted workflow and
leaves account and model settings alone. The next required evidence is a
complete ordinary consumer PR delivered with `/shaka`, including TUI skill
activation and Ask/Auto stopping behavior.

OpenCode publishes no session identifier to the commands it runs, so
`shaka usage --host opencode` needs an explicit `--session ID`. The next reader
evidence is an identifier published into the tool environment, or a confirmed
upstream way to read the current session from inside it.

## Usage is a separate capability

Follow [usage reporting](usage-reporting.md) for the supported reader, available
fields, and attribution limits. Record host/version separately from provider/model.
Preserve native reasoning settings and cache categories; similarly named settings
across hosts are not equivalent measurements.

Report missing data as `UNKNOWN`, and label shared or partial coverage. Publish
aggregate metadata only, without prompts, raw sessions, account details, or local
paths. Missing usage does not block an otherwise authorized merge, and CLI startup
does not establish model usage or savings.
