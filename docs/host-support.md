# Host support

Codex CLI is the reference host for this pilot and Claude Code the second host.
OpenCode is the third host: its canonical install path, TUI launcher, and
export-based usage reader are implemented. Pi runs the same Agent Skill and has a
native persistent-session usage reader. Follow the [getting-started guide](getting-started.md)
for installation and your first task. Claude Code has one verified consumer
delivery, recorded below. Neither Cursor nor OpenCode has one yet; this reader
task is the first recorded Pi delivery trial, not broad Pi adoption evidence.

The hosts share one `shaka` skill and the same Ruby helpers for GitHub
operations. Control tower skills are host-specific because they drive native task
tools. The optional `rct` skill requires the Codex app's native project, task,
pin, follow-up, and wait tools, so install it only there with `--with-rct`. Claude
Code desktop has its own equivalents and installs `mct-claude` and `rct-claude`
with `--with-claude-towers`. Cursor, OpenCode, and terminal-only installs stay
Shaka-only and use the [role prompts](control-towers.md#role-prompts).
Your repository keeps its existing `AGENTS.md`, commands, and policy.
Host-specific work covers installation, instruction loading, execution permissions,
and reading native usage records. It does not create separate copies of the workflow.

## What has been verified

These observations were made on September 14, 15, and 17, 2026. A successful install or CLI
startup does not establish a complete workflow, and workflow success does not
establish complete usage attribution.

| Capability | Codex CLI 0.154.0 | Claude Code desktop 2.1.270, CLI 2.1.272 | Cursor CLI 2026.09.10-fd3934a | OpenCode 1.18.31 | Pi 0.85.1 |
| --- | --- | --- | --- | --- | --- |
| Installation and startup | Dedicated skill installation and explicit trusted-file startup checked. | A symlinked personal skill loaded in the desktop app and in `claude -p`; `/shaka` asked for the task and merge preference and stopped before edits. A same-named repository skill did not replace it. | Dedicated CLI package version/help checked; Cursor skill instruction activation unverified. | Canonical `~/.config/opencode/skills` install documented; TUI activation trial pending. | Shared Agent Skill loaded from a trusted external source; no Pi-specific copy or launcher. |
| OS write boundary | A native workspace sandbox denied writes to the separate trusted source, installed link, and link directory while allowing the session and target checkout. | No launcher or sandbox; the user's permission mode applies. Not separately probed. | Native Cursor sandbox boundary unverified. | No launcher sandbox; the user's permission mode applies. The launcher disables project-local discovery so the target's `.opencode` plugins, config and instructions never load. Not separately probed. | The user's Pi tool permissions apply; no separate boundary was probed. |
| Real workflow | Protected PR operations exercised with Shaka. A fresh CLI task implemented and verified the Astro website guides using its repository instructions; the owning task handled publication. | One consumer PR delivered end to end on September 17, 2026: agent-workflows-com#62, branch through TDD, seam validation, five review rounds, helper-published description and walkthrough, helper merge in Ask mode. | Consumer delivery unverified. | Consumer delivery unverified. | This usage-reader implementation is the first recorded delivery trial; broader consumer evidence remains pending. |
| Usage | Reader matched 14 real CLI responses and repeated-source input without double counting; attribution remains partial. | Reader matched an independent per-response aggregate for a desktop session with a subagent and two models, and Claude Code's own totals for two CLI runs. | Stop-hook reader works against captured desktop `3.20.21` `grok-4.6` payloads, but has not produced records in a real delivery ([#111](https://github.com/shakacode/shaka/pull/111)); transcripts and bubble `tokenCount` remain unused. | Export reader matched an independent per-response aggregate for a real 49-response session (all counters, interval, version); the session must be named with `--session` and attribution remains partial. | Reader matched an independent aggregate of selected active-branch responses, including reasoning and native nominal cost; abandoned branches were excluded. Compaction, branch-summary, and tool-nested model usage remain excluded. |

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
for the host's controls; the getting-started guide owns the tested Codex launch recipe.

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
mode you already use.

One ordinary consumer PR has been delivered this way: [agent-workflows-com#62](https://github.com/shakacode/agent-workflows-com/pull/62)
on September 17, 2026, fixing link-checker edge cases. It ran the whole procedure —
a failing fixture test first, the repository's own `.agents/bin` seam for validation,
five review rounds with every finding answered on its thread, a description and
walkthrough published by the helpers, and a helper merge after an explicit Ask-mode
decision.

Two differences from Codex showed up, neither host-specific:

- The helper could not publish or merge until that repository's `main` was
  protected, because it reads required-check evidence with `gh pr checks --required`
  and cannot tell an unprotected branch from unreadable evidence. Shaka's own
  repository is protected, so earlier deliveries never hit it. See
  [#146](https://github.com/shakacode/shaka/issues/146).
- There is no launcher, so the trust boundary rests on the permission mode already
  in use and on keeping the trusted source outside the edited checkout. The delivery
  used a separate worktree for that reason.

Repeated consumer use, failed checks, and changed-head behavior across more
deliveries are still required before claiming broad support.

### Control towers in Claude Code

The desktop app exposes session tools that cover what the Codex tower skill needs,
so `--with-claude-towers` installs `mct-claude` for the master role and `rct-claude`
for repository towers. These tools belong to the desktop app; `claude` in a terminal does not have them, and the skill
stops with a setup error rather than guessing.

| Tower requirement | Codex app | Claude Code desktop |
| --- | --- | --- |
| Current task and its project | Native task and project tools | `get_session` for `self`; its `cwd` alone selects the repository |
| Find towers and read candidates | Native task search | `list_sessions` for titles, `list_events` for a candidate's own record |
| Stamp the role | Native rename and pin | `set_session_title` and `set_pinned`, read back with `get_session` |
| Reach another tower | Native follow-up | `send_message`, whose result distinguishes `delivered` from `queued` |
| Wait for a reply | Bounded native task wait | No equivalent |

The missing bounded wait changes one step rather than blocking the role.
Registration is acknowledged by a reply that arrives as an ordinary labelled user
turn, so a tower reports `awaiting acknowledgment`, ends its turn, and completes
setup when the reply lands. Towers do not poll or start a monitor, and neither a
`queued` nor a `delivered` result is acknowledgment.

Sidebar groups are deliberately unused: `move_sessions` unpins a pinned session, so
the title suffix is the only role stamp and the live session list is the only
registry. These tool observations were made on September 17, 2026. A complete
Claude Code tower and delivery trial is still required.

### Read the session listing completely

Both tower skills find each other by title, so a listing that stops early is a tower
that does not exist as far as the reader is concerned. `list_sessions` returns one
recent page, twenty by default, and a role held past that page reads as unheld: setup
then creates the duplicate the search exists to prevent. Raise the limit until the
listing is exhausted.

A busy account can make that listing too large to return whole. The host saves it and
names the file in the tool result; read it from that path. Never answer an oversized
listing by retrying with a smaller limit, which silently restores the paging bug. A
first trial on September 18, 2026 exhausted one account at 413 sessions and overflowed
at roughly 210KB, so both branches occur in ordinary use.

This applies to every listing a tower takes, not only the one at setup. Checking that
a repository is unowned, and refreshing the tower set later, read the same account and
fail the same way when they stop at the first page.

`list_sessions` also never includes the session calling it. A rule that counts every
session holding a role cannot be answered from the listing alone, or the count is short
by one and a genuine conflict reads as an ordinary handover. How this session is added
depends on what the role is made of: a title comes back from `get_session`, while a
record written into a session's transcript is not readable for the caller at all, since
`list_events` refuses it. Each tower skill names the source its own rule needs.

`search_session_transcripts` does not help here: it matches message content, not
titles, and the trial returned nothing for a title stamp. Find towers by title with
`list_sessions`, and confirm a candidate's role by reading it with `list_events`.

## Cursor

Keep an existing, authenticated host configuration in place when preparing a
compatibility trial. Check its version and available controls before starting.
Native `SKILL.md` support is [documented for Cursor](https://cursor.com/docs/skills),
but shared file format alone does not prove Shaka skill activation or safe execution.

Cursor user skills can be installed at `~/.cursor/skills` with the standard
installer. A September 14 trial did not find the skill through `~/.agents/skills`,
so use the Cursor-specific directory and still confirm discovery in a new Agent chat.
The trial did not establish a complete Cursor workflow or a supported launch recipe.

The checked Cursor CLI exposes `--workspace`, `--add-dir`, `--sandbox`, and
`--plugin-dir`. Its public help has no direct skill-file option. The native sandbox
and Shaka delivery have not been exercised, so these flags are not sufficient grounds
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
leaves account and model settings alone. It also sets
`OPENCODE_DISABLE_PROJECT_CONFIG`, because OpenCode otherwise reads `.opencode`
plugins, `opencode.json` and instructions from its working directory upward and
runs that plugin code; the trusted global configuration still loads. The next
required evidence is a complete ordinary consumer PR delivered with `/shaka`,
including TUI skill activation and Ask/Auto stopping behavior.

OpenCode publishes no session identifier to the commands it runs, so
`shaka usage --host opencode` needs a session named with `--session ID`, a
wrapper that sets `OPENCODE_SESSION_ID`, or saved exports passed with `--file`.
The next reader evidence is an identifier published into the tool environment,
or a confirmed upstream way to read the current session from inside it.

## Pi

Pi exposes the current persistent session through `PI_SESSION_FILE` and
`PI_SESSION_ID`. The usage reader checks those values against a v3 header, walks only
the active JSONL tree branch, and does not search other session files. Missing,
ephemeral, mismatched, older, or malformed evidence stays UNKNOWN instead of falling
back to Codex. Mixed Pi and nested-host markers require explicit `--host` selection.
The reader publishes only aggregate metadata; [usage reporting](usage-reporting.md)
documents turn selection, optional reasoning, nominal native cost, and excluded
summary/tool-model usage.

This support adds no Pi-specific skill copy, launcher, installation mechanism, or RCT
behavior. Pi continues to use the shared skill and the user's existing tool permissions.

## Usage is a separate capability

Follow [usage reporting](usage-reporting.md) for the supported reader, available
fields, and attribution limits. Record host/version separately from provider/model.
Preserve native reasoning settings and cache categories; similarly named settings
across hosts are not equivalent measurements.

Report missing data as `UNKNOWN`, and label shared or partial coverage. Publish
aggregate metadata only, without prompts, raw sessions, account details, or local
paths. Missing usage does not block an otherwise authorized merge, and CLI startup
does not establish model usage or savings.
