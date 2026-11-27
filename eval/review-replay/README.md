# Replay a reviewer change

Before changing a local reviewer's model pin or repository prompt, run this
manual comparison from a clean Shaka checkout. Use the same installed Shaka
helper and CLI version for both arms. Supply both models explicitly. If you
want to compare against a CLI default, identify the default model first and
name it in the corresponding arm. A repository prompt comparison takes two
criteria commits and the same model on both arms.

## When to rescore

Rescore by hand before merging a change to a local reviewer's model pin or
repository prompt, and publish the aggregate on that PR. Also rescore when you
notice a new CLI default model for a reviewer that has no pin, such as the
default Codex reviewer, because that change happens outside Shaka.

It stays a manual step, not a check on every PR, for three reasons. The runner
signs in with a personal Claude or ChatGPT subscription, which hosted CI does
not hold. A rescore costs a few dollars of model usage, and reviewer changes are
rare. Scoring is a blind human comparison of reports, which a check cannot do.

## Run the paired review

Use this pilot on macOS. Codex CLI 0.170.0 passed the isolation check, and
0.172.0 completed subscription-backed control replays. See the
[Linux qualification results](#linux-qualification) before trying another host.

Sign in to `claude` with your Claude subscription or to `codex` with ChatGPT.
Supply your trusted installed helper by absolute path. The runner strips
platform key and endpoint overrides, verifies the subscription login, and
gives Codex a temporary home containing only the login file. Codex replay
requires a CLI with named permission profiles and starts with a dummy-file
check. The reviewer commands can read the fixture and basic OS files. The
profile blocks reads of the login and earlier transcripts and disables command
network access. If the dummy-file check fails, the replay stops before
reserving budget. The same helper runs both arms through `shaka review run`
with the full diff. Results stay local.

Fetch the public PR refs holding the frozen commits:

```sh
git fetch --no-tags origin refs/pull/1024/head refs/pull/708/head refs/pull/710/head \
  refs/pull/577/head refs/pull/757/head refs/pull/947/head refs/pull/592/head \
  refs/pull/807/head refs/pull/961/head
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
set both model flags to the same model. Pass one `--effort` for both arms and
pass `--candidate-criteria CANDIDATE_SETTINGS_SHA`. Keep the configured prompt
under `.agents/shaka/`. Keep all `AGENTS.md` files the same in both commits.
The runner accepts regular settings and criteria files.
Inspect the settings diff and confirm that the changed file supplies the
effective reviewer prompt. Packaged prompts and CLI-version comparisons need
a separate replay procedure.

The runner replays the newest bank, v2, by default. Pass `--bank v1` to repeat
the [four-case run](https://github.com/shakacode/shaka/issues/1283) on its
original cases.

`--preview` builds every fixture without sign-in or model calls. Drop it after
checking the fixtures and approving the run. Use `--case r04` for a small
smoke run. Each isolated fixture holds the reviewed head and its ancestors, no
Git remote, and a projected settings commit containing review configuration
and applicable repository instructions. The runner supplies neither the scoring
key nor earlier reports to the reviewers. Codex commands use the fixture-only
profile. Check the transcript for reads of the scoring material before scoring.
This follows [the Stage 1 replay](../reports/review-scope-stage1-pilot.md#rerun-it).

The existing eval ledger counts cache-neutral API-equivalent dollars against
the $15 per-PR and $200 monthly limits. Native evidence also reports billed-
equivalent dollars. These are token cost estimates for subscription sessions.
The ledger checks settled spend before each call. The last call can cross the
cap, and missing usage leaves an unresolved reservation that stops later calls.
The CLI exits unsuccessfully for a partial run. Retain completed records and
include any gaps in the report. Each v1 arm cost $0.67 to $2.79 cache-neutral
in the four-case run. Scaling by case count, a v2 arm would cost about
$1.70 to $7, so a Codex pair can approach the $15 limit and stop with an
incomplete case.

## Linux qualification

Linux subscription replay remains unqualified. On ARM64 with Codex CLI 0.172.0,
Ubuntu 24.04.4 failed to start the sandbox. On Debian 13 with a system-installed
Codex package, the sandbox read the fixture and hid the dummy login, prior
transcript, and saved report. Linux reported those private files as absent.
The replay preflight requires an explicit permission denial and stopped before
login or budget reservation. These checks used dummy data in VMs with no host
directory mounts.

## Score the results

See [#1283](https://github.com/shakacode/shaka/issues/1283) for evidence from
the four-case run on both subscription paths.

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
| r05 | Review signal #10, [PR #577](https://github.com/shakacode/shaka/pull/577#issuecomment-6229495111) | The thread reader sees only the first 100 comments, so a reply past that page reads as missing and handoff keeps owing a reply. |
| r06 | Review signal #36, [PR #757](https://github.com/shakacode/shaka/pull/757#issuecomment-6310097710) | A review-effort floor word written with capitals never matches, so its floor is not applied. |
| r07 | Review signal #29, [PR #947](https://github.com/shakacode/shaka/pull/947#issuecomment-6487735655) | A task URL with userinfo before an empty host, such as `https://a@:443/task`, passes as valid. |
| r08 | Review signal #18, [PR #592](https://github.com/shakacode/shaka/pull/592#issuecomment-6230622190) | The guide says the Next line is optional for any recommendation, but validation requires `next_action` for every disposition except Merge. |
| r09 | Review signal #7, [PR #807](https://github.com/shakacode/shaka/pull/807#issuecomment-6314019812) | A parseable call-log line for the PR's commit that lacks a field yields a nil timeline step and crashes publication. |
| r10 | Review signal #22, [PR #961](https://github.com/shakacode/shaka/pull/961#issuecomment-6491745232) | A bracket inside a comment ends a wrapped call early, so the seam upgrade check loses that call's working-directory dependency. |

Cases r01 to r04 form v1. v2 keeps them unchanged and adds r05 to r10, chosen
across code and documentation defects. Every new reviewed head is reachable from
its public PR ref. For five new cases, the source study ran the fix's regression
test and saw it fail at the reviewed head. r08 rests on reading the guide against
the validation code. v2 leaves out the largest verified diffs to keep one pair of
arms under the per-PR budget limit; that cost is an estimate until a v2 run.

Reveal the arm labels and report, for each arm, the known findings found and
missed, confirmed new findings, unsupported claims, incomplete cases, and both
cost totals. A single pass on these cases can expose a regression. It
cannot estimate the overall reviewer's recall or establish hosted parity. Use
the [hosted replay study](../reports/hosted-review-prompt.md) for the hosted
reviewer's GitHub-tool and workflow context.

Keep v1 and v2 frozen. Append verified later misses in a new version with the reviewed
head, base, confirmation and scoring criterion. Draw cases across defect types
and from both [source studies](../README.md). Keep raw reports and per-run usage
in private state. Publish aggregate results on the reviewer-change PR.
