# Recover from host denial before launch

When the host denies the command before `shaka review run` starts, record a
**host-denied-before-launch** outcome in the task evidence. Preserve the denied
command, selected reviewer, head, host reason, and whether launch is known;
redact private paths and account details before publication. If launch is uncertain,
inspect existing output and processes before retrying; record UNKNOWN until resolved.

A confirmed prelaunch denial produces no helper result or reviewer report. It is
not a CLI attempt, missing credentials, exhausted quota, or a provider outage.
Do not fabricate `attempted`, `failure_stage`, a ledger round, or a review
attestation, and do not mark the selected reviewer `--unavailable` from this denial.
Helper setup failures and reviewer failures after launch retain their existing
classifications and diagnostic requirements.

Use this recovery checklist:

1. Explain the proposed provider request: the selected provider/model and effort,
   review instructions, committed `git diff BASE...HEAD`, checkout path and head (access remains adapter- and host-limited),
   trusted criteria and configured prompt from
   `--criteria-ref`, optional public-safe description, and earlier ledger findings
   when present. The runner sends this context to the selected provider through its
   CLI using local credentials; it excludes the implementation conversation.
   Restricted Claude reviews the embedded diff without Git access;
   a supplied path does not guarantee file access. Other adapters may inspect
   unchanged source only where restricted tools and host permission allow it.
   Report denied access and missing context rather than working around restrictions.
2. Reconcile the host reason with existing task authorization. An authorized review
   needs no repeated task approval, but task permission does not override the host's
   execution decision. If the host offers a permitted native approval or retry path,
   use it for the same scoped request and retain the resulting evidence. Do not
   disable approval checks, change tools or flags to evade denial, or retry unchanged
   refusals through another shell.
3. Use an alternative only when existing task authorization and host permission
   cover it, and the independent reviewer selection procedure permits it. A denial
   alone does not advance the ordered reviewer list or authorize a new provider,
   model, effort, current-host Task/subagent, or fresh host chat. Report the concrete
   blocked action and host reason when a human decision is needed; keep an already
   authorized alternative within its stated scope.
4. If review remains blocked, run the saved helper's `review check` with
   `--not-run-reason` set to the actual host denial, plus `--root`, `--settings-ref`,
   and `--repository`. Use the invocation shape below with that actual reason
   replacing the synthetic example. Pass the reason as data through structured argv
   or proper shell quoting that preserves apostrophes without evaluating its content. Retain
   its nonzero result, explain the missing review on the PR, and leave review
   readiness blocked. If the host also denies this evidence command, preserve that
   denial and state that not-run evidence could not be generated. Ask merging and
   required independent review remain in force; a completed review later needs its
   own current-head evidence.

## Replay the blocked path without launching a provider

Use a synthetic prelaunch denial to rehearse the checklist on a clean, committed
head. Label it synthetic; do not request a live denial on another task. Record that
`review run` was intentionally never invoked, no provider launched, and no CLI
attempt or report exists. Save output outside the checkout and use the saved
absolute helper path. The example creates a temporary result file; verify its
location is outside `$ROOT` before invoking the helper:

```bash
NOT_RUN_RESULT="$(mktemp)"
"$SHAKA" review check --root "$ROOT" --head "$HEAD" \
  --settings-ref "$TRUSTED" --repository OWNER/REPO \
  --not-run-reason 'Synthetic replay: host denied review run before launch; no provider started' \
  > "$NOT_RUN_RESULT"
```

Expect exit status 1 and JSON `status: not_completed` for that head, with the stated
reason and no report or verified CLI invocation. The returned
`same_model_fallback_available: true` describes a possible independent review path;
it grants no host permission and does not mean review succeeded. Keep this replay
result separate from actual review evidence and the review ledger. Confirm no
`--unavailable` substitution, fabricated attempt, or successful-review claim entered
its handoff. This rehearses blocked evidence handling, not a real host's approval UI.
