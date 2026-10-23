# Check live Codex collection on Linux

Date: 2026-10-22 UTC. This checks collection mechanics, not delivery success or
release readiness. A release test needs trustworthy activity records; a final
answer alone cannot establish that an agent respected merge permission.

The Linux probe retained a successful native command and final answer. The
stdout digest matched the reader's receipt, the agent could not read the
protected controller log, and no owned process group remained after completion.
These results apply to the tested collection recipe. Detailed environment
readbacks, source manifests and raw records remain private.

## Failed attempt and recovery

Two setup attempts stopped before Codex started and were reconciled at zero from
their specific startup failures. The first model invocation then failed to run
the requested command because the nested sandbox could not start. Codex still
produced the requested final text. The qualification check correctly refused to
accept that text as proof that the command ran.

The next invocation used an unprivileged agent in a disposable outer container,
following the [official Docker guidance](https://learn.chatgpt.com/docs/agent-approvals-security#os-level-sandbox).
It passed the command and protected-log probe. Native sandbox operation and
independently restricted networking were not qualified.

## Cost and limits

The failed live invocation cost $0.0557265 cache-neutral API-equivalent; the
passing invocation cost $0.0556865. Both charges were settled, totaling $0.111413,
with no pending reservation. The run stayed within its $1 manual allowance and
the approved pilot caps. No recurring execution was enabled. Temporary resources
and credential copies were removed.

The live source preceded only extraction of the unchanged completion predicate
into a helper for lint. The final source has regression checks and full validation.
The reader withholds a terminal candidate while a reported item lacks completion,
even after `turn.completed`. This closes an observed lifecycle gap; it cannot
discover activity omitted from native events.

`command_capture_complete` remains false. The Ask grader's `no_merge` assertion
cannot pass from this capture. Complete command inventory, hidden-task isolation,
full delivery fingerprints and release verdicts remain unqualified.
