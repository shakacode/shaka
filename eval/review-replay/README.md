# Replay a reviewer change

Before changing a local reviewer's prompt, model pin, or CLI default, run this
manual comparison from a clean Shaka checkout. Use the same installed Shaka
helper and CLI version for both arms. To compare a pinned model with the CLI
default, drop the pin in the candidate criteria commit while preserving the rest
of the settings. Review a prompt change by supplying the trusted base commit
and the inspected candidate commit with the proposed prompt. Keep model and
effort constant for a prompt comparison.

## Run the paired review

Sign in to `claude` with your Claude subscription or to `codex` with ChatGPT.
Supply your trusted installed helper by absolute path. The runner strips
platform key and endpoint overrides, verifies the subscription login, and
gives Codex a temporary home containing only the login file. The same helper
runs both arms through `shaka review run` with the full diff. Nothing is posted.

Fetch the public PR refs holding the frozen commits:

```sh
git fetch --no-tags origin refs/pull/1024/head refs/pull/708/head refs/pull/710/head
```

Create a mode-0700 state directory outside any checkout. Reuse the same state
directory and reviewer-change PR number across all runs so the budget counts
them together. Use the existing shared evaluation state directory if one exists
(the existing budget ledger must be at `STATE/account/budget.jsonl`).

```sh
eval/bin/review-replay --helper /absolute/path/to/installed/scripts/shaka \
  --reviewer openai/codex --criteria BASE_SETTINGS_SHA \
  --baseline-model BASE_MODEL --candidate-model CANDIDATE_MODEL \
  --state PRIVATE_STATE_DIR --pr PR_NUMBER --cap 15 --preview
```

For Claude Code, use `--reviewer anthropic/claude`. For a settings-only change,
replace the model flags with `--candidate-criteria CANDIDATE_SETTINGS_SHA`.
Keep any required settings or prompt files under `.agents/shaka/`. Inspect
the settings diff first. The runner checks which inputs differ, and the operator
verifies the candidate commit changes only the intended review setting.

`--preview` builds every fixture without sign-in or model calls. Drop it after
checking the fixtures and approving the run. Use `--case r04` for a small
smoke run. Each isolated fixture holds the reviewed head and its ancestors, no
Git remote, and a projected settings commit containing review configuration
and applicable repository instructions. Neither arm sees the scoring key or the
other arm's report. This follows [the Stage 1 replay](../reports/review-scope-stage1-pilot.md#rerun-it).

The existing eval ledger counts cache-neutral API-equivalent dollars against
the $15 per-PR and $200 monthly limits. Native evidence also reports billed-
equivalent dollars. These are token cost estimates for subscription sessions.
The ledger checks settled spend before each call. The last call can cross the
cap, and missing usage leaves an unresolved reservation that stops later calls.
The CLI exits unsuccessfully for a partial run. Retain completed records and
include any gaps in the report.

## Score the results

Extract each completed record's `result.report`, label the two reports with
opaque IDs, and save the ID-to-arm mapping separately. For each case, compare
both reports against the expected problem on the pinned diff. Credit a match
when the report identifies the same triggering condition and bad outcome.
Count each expected problem once, and count it as missed only for a completed
review. Check unmatched claims against the diff before calling them new findings.
Mark cases with a missing arm incomplete. Flag any transcript reads outside the
fixture that could have supplied the answers, and exclude those runs from scoring.

| Case | Source | Expected finding |
| --- | --- | --- |
| r01 | Review signal #27, [PR #1024](https://github.com/shakacode/shaka/pull/1024#issuecomment-6569337020) | Rendering the review preview with older floor data lacking groups raises when the renderer maps the missing groups. |
| r02 | Review signal #34, [PR #708](https://github.com/shakacode/shaka/pull/708#issuecomment-6260128941) | A failed update check counts as fresh and suppresses the daily reminder. |
| r03 | Hosted prompt study T04, [PR #710](https://github.com/shakacode/shaka/pull/710#discussion_r4331938341) | If removal fails partway through repairing the install, a restore that only runs on install failure leaves previously removed links missing. |
| r04 | Fix-only control from [PR #1024](https://github.com/shakacode/shaka/commit/6365c3b9d11bafa18a57a1dcb12c7ee7d37da3da) | The r01 failure is gone. Verify any claim it remains against the fix. |

Reveal the arm labels and report, for each arm, the known findings found and
missed, confirmed new findings, unsupported claims, incomplete cases, and both
cost totals. A single pass on these four cases can expose a regression. It
cannot estimate the overall reviewer's recall or establish hosted parity. Use
the [hosted replay study](../reports/hosted-review-prompt.md) for the hosted
reviewer's GitHub-tool and workflow context.

Keep v1 frozen. Append verified later misses in a new version with the reviewed
head, base, confirmation and scoring criterion. Draw cases across defect types
and from both [source studies](../README.md). Keep raw reports and per-run usage
in private state. Publish aggregate results on the reviewer-change PR.
