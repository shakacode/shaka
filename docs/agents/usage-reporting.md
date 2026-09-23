# Model and token reporting

Each task reports the available native usage for its commits and contributions.
**Native** means copied from the host's own records, as against anything Shaka works
out for itself: native token counts are read from the transcript, while an
API-equivalent USD figure is a scenario Shaka prices from a published rate card. The
opposite of a native number is a derived one, not a foreign one. Where a host records
its own cost, as Pi does, Shaka publishes that recorded figure rather than recomputing
it, and says which it is.

`UNKNOWN` means the available records do not establish a value; it never means zero.
The agent runs the trusted installed helper and includes its output in the PR,
or the final response when there is no PR:

```bash
shaka usage --commit FULL_COMMIT_SHA --contribution implementation
```

The helper reads the current host's records: Codex, Claude Code, Cursor, OpenCode, or Pi. When
more than one host context is present, pass `--host codex`, `--host claude-code`, `--host cursor`,
`--host opencode`, or `--host pi`. This is required when another agent is started inside Pi because
that child inherits Pi's process marker. Selecting Pi never falls back to unrelated Codex records.

Contribution categories are `implementation`, `review`, `integration`, and
`shared-planning`. The local adversarial review is its own `review` report, from
that run's native source, not the implementation session. Hosted GitHub reviewers
and other agents stay UNKNOWN unless their native records are supplied. Supply
several affected commit SHAs separated by commas when
the same work spans them. A report maps the whole selected interval to those
commits as **SHARED**; it never divides usage into invented per-commit amounts.
Retain that original mapping after squash merge and associate the merged SHA
without recounting the work.

## What the Codex reader includes

The reader uses the exposed current thread identifier to find one matching native
session beneath `CODEX_HOME` (default `~/.codex`). It checks the session metadata
before reading usage. The default selects the latest turn in that source. It
does not search unrelated transcripts or fall back to a parent's session.
Host context can be inherited, so this selection is shared source evidence and
does not establish which agent performed every response.

The Markdown contains the affected commits, contribution, observed response
interval, source version, configured provider/model/effort, and native token
categories. Those fields appear as metric rows with one column per configuration
so GitHub does not force horizontal scrolling. Cached input and reasoning output are subsets of input and output
in the tested Codex records; do not add them again. Cache writes and the native
total remain separate fields. Routed model stays UNKNOWN because these tested
local records do not establish the model that executed each response.

The report also shows **rate-card scenarios** for the providers and models
in that snapshot: Standard Codex credits and Standard API-equivalent USD for
supported OpenAI models, Cursor on-demand USD for Grok 4.6 and Grok 4.7, and Anthropic list-price
USD for supported Claude models. The first three price the configured model. The
Anthropic scenario prices whichever of the routed or configured model it has a rate
for, taking the routed one first, because Claude Code records no configured model.
Source links and
rate notes cover only priced provider and model pairs, not a model name on the
wrong provider. They describe the rate card that applies to the pair, so they
still appear beside an UNKNOWN estimate when that response's own counters are
missing or contradictory; the reason line names why. The estimate prices each unique response
before summing, so model switches and requests crossing the API context threshold
are handled separately. Cached input is removed from ordinary input. For the API
scenario, cache writes are removed too and priced at the published write rate;
the Codex credit estimate is UNKNOWN when writes are present because the credit
rate card does not publish their price. Missing counters or unsupported models
also yield UNKNOWN. Effort changes are reported but have no price multiplier.

## What the Claude Code reader includes

The reader uses `CLAUDE_CODE_SESSION_ID` to find that session's transcript beneath
`CLAUDE_CONFIG_DIR` (default `~/.claude`), checks the session id inside the file, and
adds the session's subagent transcripts. The default selects the session's latest
turn together with the subagents started during it. Claude Code writes several lines
for one streamed response; the reader counts the last line, which carries the final
usage, once. A Claude CLI `-p --output-format json` file is one `result` object: the
reader copies its `usage` and, when `modelUsage` has exactly one entry, the routed
name from that entry's `canonicalModel`. It does not publish `result` text. An
`is_error` result is UNKNOWN. The CLI object usually has no top-level `model` or
`effort`; a present `model` is used, otherwise that single `canonicalModel`, and more
than one `modelUsage` entry stays UNKNOWN. Effort stays UNKNOWN unless the object
records it.

The native usage table lists metrics as rows and each configuration as a column.
It reports provider `anthropic`, the response's model as the routed model, the
recorded effort setting, and native token categories. Unlike Codex, Anthropic input
excludes cache reads and cache writes, so the three are separate amounts; reasoning
output is part of output. The configured model and native total stay UNKNOWN because
the transcript does not record them. A turn is a prompt id, so `--turn` selects
prompts, and every supplied file uses the first file's latest turn by default.

The report also prices an **API-equivalent USD scenario** from Anthropic's published
list prices, verified September 19, 2026. Uncached input, cache reads, and cache writes
are billed separately at their own rates, and the reader reads the transcript's
`cache_creation` split so a 1-hour cache write is priced at its higher rate rather than
the 5-minute one; that split is priced but not published as its own table row. A write
total the transcript does not split stays UNKNOWN instead of being priced at either
rate. Codex credits are omitted because they do not price Anthropic usage. Only
responses the transcript records at standard speed are priced: fast mode bills at its
own rates, so a fast or unrecorded speed stays UNKNOWN and the report names which.
Web search bills per request on top of tokens, so the reader keeps that counter and
the estimate adds its published charge; web fetch adds none. A response that used no server tool omits the
counter or the whole group, which the reader reports as no searches; a group that is
present but unreadable, or a count that is not a non-negative whole number, stays
UNKNOWN rather than being priced as though nothing was searched. A response recorded
at fast speed is labelled apart from a standard one on the same model, so a report
covering both still says which column is which. Server-side code execution is not priced here at all. Anthropic
meters it by container time against a monthly allowance rather than per request, and
waives it when the same request uses web search or fetch, so no per-response record
establishes what it cost; none of these estimates include it. A response that pins inference to the US is billed at
1.1 times every token rate, so the estimate applies that multiplier when the transcript
records it; the multiplier covers tokens rather than the per-request search charge.
Global routing is Anthropic's default, so a response that does not name US routing is
priced at standard rates rather than refused. Anthropic publishes no context threshold,
so no long-context multiplier applies. The
cost table heads its column with the priced model, which for Claude Code is the routed
model, because the configured model is UNKNOWN. Models outside the published rate table
stay UNKNOWN and the report omits Anthropic rate copy and source links for them.

Claude Code documents its transcript format as internal and version-dependent. The
reader was exercised against desktop `2.1.270` and CLI `2.1.272` transcripts. It
matched an independent per-response aggregate for a session with a subagent, and
Claude Code's own totals for two CLI runs. Records it cannot read produce UNKNOWN.

## What the Cursor reader includes

The reader uses `CURSOR_CONVERSATION_ID` to find one JSONL file beneath
`CURSOR_USAGE_DIR` (default `~/.cursor/shaka-usage`). Cursor agent transcripts and
local bubble `tokenCount` values are not used: Grok sessions store those counters as
zero even when the host reports tokens on hooks.

Cursor writes usable counters on `stop` and `afterAgentResponse` hook payloads. The
installed `cursor-usage-hook` persists only the `stop` payload's allowlisted usage
fields. Input includes cache reads and cache writes; the three remain separate
metric rows as in Codex. Reasoning output and native total stay UNKNOWN. A turn is a
`generation_id`. The default selects that source's latest generation. `stop` and
`afterAgentResponse` for the same generation are one response. Subagent tokens are
absent from these parent-agent events. A Cursor adversarial review is a different
conversation: report it with `--contribution review` and that chat's stop-hook file.

The reader was exercised against desktop `3.20.21` hook payloads for `grok-4.6`.
Desktop `3.21.16` `grok-4.7` stop payloads use model id `grok-4.7` and record effort as
`reasoning_effort`, which the reader accepts when `effort` is absent. They also include
a `context` param. That value is not a price. Cursor Agent Skills are selected by the
host for both models; both model pages list the full agent tool set.
Install the hook as described in [getting started](../people/host-support.md#cursor).
Without persisted stop records, token counters stay UNKNOWN, the report names
`usage reader unavailable: no readable Cursor stop-hook records`, and an inferred
host-context row still uses provider `cursor` plus `CURSOR_MODEL_ID`,
`CURSOR_MODEL`, and `CURSOR_MODEL_EFFORT` when those host values are present.
Explicit `--file` or `--turn` reports do not copy the current chat's model environment.
`shaka doctor` fails on Cursor when `~/.cursor/hooks.json` has no
`cursor-usage-hook` stop command. A missing file for this conversation only
degrades: that is expected until the first `stop` event. Missing usage still
does not block an otherwise authorized merge.

When the `fast` model param is present, the cost table also shows a configured-model
on-demand USD scenario for `grok-4.6`, `grok-4.6-fast`, `grok-4.7`, and `grok-4.7-fast`
using Cursor's published list prices verified September 21, 2026. Grok 4.7 input above
256k tokens uses twice the standard rates, and Fast Grok 4.7 at that length uses three
times the standard rates. The threshold uses that generation's reported input total.
Grok 4.6 has no long-context multiplier. Cursor-only reports omit the unused Codex
credits row. Cache writes have no published Cursor rate, so they remain inside
ordinary input. Missing Fast/standard billing mode or an unsupported Cursor model
keeps the scenario UNKNOWN and omits Cursor rate-card copy. The dollar amount is that list-price scenario, not an
invoice: included quota, actual charges, and other account terms remain UNKNOWN.

## What the OpenCode reader includes

The reader runs `opencode export` for one session and keeps only per-message usage
metadata; message parts carry transcript text and are never read. OpenCode 1.18.31
publishes no session identifier to the commands it runs, so name the session yourself
with `--host opencode --session ID` (`ses_...`); `opencode session list` prints the
identifiers. The reader also accepts `OPENCODE_SESSION_ID` for a wrapper or plugin that
sets it, and reports UNKNOWN when neither is present. `opencode export` truncates its
JSON when stdout is a pipe, so the helper redirects to a temporary file before parsing.

A turn is a user message: assistant messages join the turn through their `parentID`.
The default selects the session's latest user turn with its assistant responses;
`--turn ID` selects explicit user messages and `--all-turns` counts every assistant
response with an identified turn. Pass repeated `--file PATH` with saved export JSON
for contributor or resumed-session snapshots instead of running the export.

Rows report the export's provider, the session model as the configured model, the
response's model as the routed model, and the per-response variant as effort.
Unlike Codex, input excludes cache reads and writes, so the three are separate
amounts that the native total sums with output and reasoning. The OpenAI and Cursor rates bill input
inclusive of those subsets, so OpenCode rows stay UNKNOWN with a cache-exclusive reason
even when the response ran on a provider the helper otherwise prices. An OpenCode
response on a supported Anthropic model is not priced either, because the export records
no billing speed. The configured model falls back to UNKNOWN when the export omits it.

The reader was exercised against `opencode export` from 1.18.31. It matched an
independent per-response aggregate for a real 49-response session: response count,
all five token categories and their total, the response interval, and the source
version. Records it cannot read produce UNKNOWN.

## What the Pi reader includes

The reader uses `PI_SESSION_FILE` only when its v3 session header has a non-empty ID that
matches `PI_SESSION_ID` exactly. This supports current SDK-provided custom IDs without publishing
them. An ephemeral session, missing file, older format, malformed header, or identity mismatch
stays UNKNOWN; it never triggers the old Codex fallback. Reopen or export a legacy session with
current Pi before reporting it. Explicit `--host pi --file PATH` remains available for saved
contributor or resumed-session evidence.

Pi stores an append-only session tree. The reader validates entry identities and parent
links, starts at the current leaf, and walks back to the root. Abandoned `/tree` branches
are therefore excluded. A Pi turn is one user message and the assistant responses that
follow it before the next user message. The default selects the latest such turn on the
active branch; `--turn ID` selects active-branch user entries, and `--all-turns` includes
all identified turns on that branch.

Rows use each assistant response's provider and selected model as configured evidence.
The optional `responseModel` is the routed model; it stays UNKNOWN when the provider does not
record it rather than falling back to the configured model. Active-branch thinking-level entries
supply effective effort. Pi input excludes cache reads and cache writes, so the three counters
stay separate. The native total is copied rather than recomputed. Supported providers also record
reasoning as a subset of output. When reasoning is absent, it stays UNKNOWN unless zero output
proves zero reasoning. A present invalid value or one that exceeds output makes that response's
usage contradictory and therefore UNKNOWN.

Pi's recorded `usage.cost.total` appears as the USD estimate: native nominal cost,
not a token recalculation. Codex credits are omitted. Subscription treatment,
discounts, service tier, account terms, and the actual invoice remain UNKNOWN.

The reader was exercised against Pi 0.85.1 in a real delivery session. Its selected active-branch
responses matched an independent aggregate for input, output, reasoning, cache reads, cache writes,
native total, and native nominal cost. Malformed trees and conflicting response copies produce
UNKNOWN without publishing session content, paths, or identifiers.

Compaction and branch-summary entries can carry separate summarizer usage, but the pilot reader
counts assistant responses only and discloses when such usage on the active branch is excluded.
Tool-nested model usage is also excluded. Pi's `/session` total may be
published separately as comparison evidence for a dedicated session; never hand-edit it into the
helper's report or use it to attribute summary usage to a turn.

## Coverage and fallback

The Codex adapter was exercised against desktop `0.154.0-alpha.6.2` and stable Codex
CLI `0.154.0` records. The fresh CLI consumer trial matched 14 responses to an
independent aggregate; repeating its source left the report unchanged. Unsupported
or unreadable records and missing fields produce UNKNOWN. Reports are PARTIAL
snapshots: active work, external reviewers, tool-model calls, and other agents
may add usage that is absent from the selected sources. Routed model, billing mode,
service tier, account terms, and actual provider charges are not established by
these tokens. API-equivalent USD is a scenario or Pi's recorded native nominal cost,
not a subscription invoice. A published list price is not the amount charged: a
subscription, negotiated terms, service tier, or data-residency routing can all differ
from it.
Human active time and total historical consumption are not inferred.

When host discovery is unavailable or several turns/contributors belong to the
work, the agent may supply repeated `--file PATH` and `--turn ID` options using
its private source context. Without `--turn`, each Codex file contributes its latest
turn, Claude Code files use the first file's latest turn, Cursor files use
each source's latest generation, and Pi files use the first file's latest active-branch
user turn. For a session dedicated to one task, use `--all-turns` to include planning,
implementation, user answers, and merge turns together. It cannot be combined with
`--turn`. A fresh `shaka work` session starts with one task; if it later contains
unrelated work or inherited history, select relevant turns instead. Never include
other tasks just to obtain a bigger total. The visible report states its scope;
latest-turn output is not a whole-task total. Retain earlier non-overlapping task
reports when continuing in an existing conversation; replace only overlapping
snapshots. Include available review, retries, and subagent records. The helper counts
each response ID once across all supplied files, including forked/resumed copies;
it ignores cumulative snapshots. Conflicting counters, configuration, or interval metadata in response copies yield UNKNOWN.
Replace an earlier overlapping report instead of adding its totals again.

No usage report contains source paths, turn/response IDs, prompts, transcripts, or
tool output. Recovery-note thread locators follow their separate [publication
rule](working-with-your-agent.md#recover-an-unfinished-pr). The helper reads local files
and prints allowlisted aggregate metadata; it neither modifies sessions nor publishes
to GitHub. Review the report for task coverage before publishing it. The visible
coverage note stays outside the expandable details. For a `--contribution review`
report it says whether countable local-reviewer tokens are included below; empty or
conflicting review records stay UNKNOWN. Missing usage does not block a PR.

## Naming the published block

A PR description has to carry the report inside a `details` entry whose summary
mentions usage; that much the renderer checks. It does not check the wording, and
nothing but the agent keeps the rest of this section.

Call that entry **Usage and cost**. Put the dollar table in the visible summary when
the figures are known, for example `Usage and cost — $8.29 grok-4.6, $0.94 claude-opus-5`.
The helper prints the USD estimate above its collapsed `Token detail` block so a reader
does not open two nested details to see what the task cost. Rate-card notes and sources
stay with that estimate; native token rows stay inside `Token detail`. The renderer
also copies `USD estimate` cells onto that summary when the body has them and the
summary does not already include each occurrence.

## PR execution provenance

Every PR description requires a compact `provenance` object. It records the
task source, the installed workflow version, and the requested, recommended, and
active model/effort routes. The renderer adds the public machine alias from
`SHAKA_MACHINE_ALIAS`, or `UNKNOWN` when that variable is unset. Because the
alias is published on a public PR, the renderer never falls back to a host name;
set a short, publication-safe alias such as `m5`. The native
usage table remains the only record of the observed route and token data. The
execution-provenance renderer never accepts prompt text, reasoning text, transcripts,
local paths, run identifiers, or arbitrary metadata.

Supply one of `description`, `issue`, or `pull_request` for `task_source`; use
`UNKNOWN` where route metadata is unavailable. The public record is useful for
comparing comparable tasks and workflow versions, but it does not establish a
causal saving. Compare it with developer attention, retries, review findings,
delivery time, accepted quality, and regressions or reverts.
