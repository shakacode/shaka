# Replay a reviewer change

Before changing a local reviewer's model pin or repository prompt, run this
manual comparison from a clean Shaka checkout. Use the same installed Shaka
helper and CLI version for both arms. Supply both models explicitly. If you
want to compare against a CLI default, identify the default model first and
name it in the corresponding arm. A repository prompt comparison takes two
criteria commits and the same model on both arms.

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

Create a mode-0700 state directory outside any checkout. Pass the shared
evaluation budget directory with `--budget`. The directory holds
`budget.jsonl`. Use the same budget directory and reviewer-change PR number
across runs so the budget counts them together.

```sh
eval/bin/review-replay --helper /absolute/path/to/installed/scripts/shaka \
  --reviewer openai/codex --criteria BASE_SETTINGS_SHA \
  --baseline-model BASE_MODEL --candidate-model CANDIDATE_MODEL \
  --state PRIVATE_STATE_DIR --budget SHARED_BUDGET_DIR --pr PR_NUMBER --cap 15 --preview
```

For Claude Code, use `--reviewer anthropic/claude`. For a prompt-only change,
set both model flags to the same model and pass `--candidate-criteria
CANDIDATE_SETTINGS_SHA`. Keep the configured prompt under `.agents/shaka/`.
Inspect the settings diff and confirm that the changed file supplies the
effective reviewer prompt. Packaged prompts and CLI-version comparisons need
a separate replay procedure.

`--preview` builds every fixture without sign-in or model calls. Drop it after
checking the fixtures and approving the run. Use `--case r04` for a small
smoke run. Each isolated fixture holds the reviewed head and its ancestors, no
Git remote, and a projected settings commit containing review configuration
and applicable repository instructions. The runner supplies neither the scoring
key nor earlier reports to the reviewers. Codex uses Shaka's normal read-only
sandbox. Check its transcript for access outside the fixture before scoring.
This follows [the Stage 1 replay](../reports/review-scope-stage1-pilot.md#rerun-it).

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
