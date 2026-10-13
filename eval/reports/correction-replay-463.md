# Correction replay, #468

Issue [#468](https://github.com/shakacode/shaka/issues/468) reports about an hour spent
on a one-line security correction in [PR #463](https://github.com/shakacode/shaka/pull/463).
This report replays that correction three ways: the defect on both URI versions, the
work sequence the PR records, and a model decision comparison between the workflow on
`main` and the [correction path](../../skills/shaka/references/review.md#correct-a-reviewed-change).
No PR was changed and nothing was merged.

## The defect on both URI versions

[Commit a43ad7f](https://github.com/shakacode/shaka/commit/a43ad7f32d009737ba592059d58846f628eb85cc)
adds `address.password = nil` to the installer's SSH origin cleanup. Its regression
test, `test/install_ssh_origin_test.rb`, was run at the parent commit and at the fix
with the `uri` gem pinned for the test and the installer it starts.

| Commit | URI 1.0.3 | URI 1.1.1 |
| --- | --- | --- |
| Parent `94479c8e` | 1 failure: `ssh://git:secret@example.com/team/shaka.git` recorded | 0 failures |
| Fix `a43ad7f3` | 0 failures | 0 failures |

URI 1.1.1 clears the password when the user is assigned; URI 1.0.3 keeps it. A pass
on 1.1.1 says nothing about the version the required checks used.

The first attempt at this table passed in all four cells. It pinned the gem in the
test process only, and the test starts the installer as a separate process that loaded
the default gem. Pinning through `RUBYOPT` reached both. A reproduction is evidence
only for the versions that ran the code under test.

```sh
echo "gem 'uri', ENV.fetch('URI_PIN')" > /path/outside/checkout/pin_uri.rb
URI_PIN=1.0.3 RUBYOPT=-r/path/outside/checkout/pin_uri.rb ruby -Itest test/install_ssh_origin_test.rb
```

## What PR #463 records

Times are GitHub timestamps in UTC on October 7 and 8, 2026. They do not measure
active human time, and the time inside each interval is UNKNOWN.

| Step | Time |
| --- | --- |
| Finding dismissed from a local URI 1.1.1 result | 23:26 |
| Correction committed | 00:06 |
| Local review of the whole PR published | 00:12 |
| Checkpoint rerun and published | 00:14 |
| Hosted review of the new commit | 00:19 |
| New walkthrough, then replies | 00:20 to 00:23 |

Forty of the 57 minutes passed before the commit. The issue attributes part of that to
agent command mistakes and timeout retries, which no instruction here removes. The
checkpoint rerun finished within three minutes of the review publication.

## Before and after, by step

| Step | Workflow on `main` | Correction path |
| --- | --- | --- |
| Reproduce the finding | Versions not stated | On the versions the required checks use |
| Repository validation | Before review, and again after repairs | Once, on the last commit of the repair |
| Local review | Configured reviewers, asked to review the full diff fresh | Same reviewers, asked to review the correction and report only defects and risks elsewhere |
| Required checks, hosted review wait | Required | Unchanged |
| Checkpoint | Rerun for the new head | Unchanged |
| Walkthrough | Written again from the whole diff | Previous content, affected steps rewritten |
| Reply on the finding | Required | Once |
| Replies to settled advisory comments | Not stated | Left out |
| Merge authority | Ask or Auto as resolved | Unchanged |

Time saved is UNKNOWN. This change removes no required check, reviewer, or gate.

## Decision comparison

- Date: October 13, 2026 UTC.
- Baseline: rendered workflow and review guide at `main`
  `e95b321b90d7c9a8c8995a4f6de2823c62072e52`, SHA-256 `d0bbf8c784b9…`.
  Candidate: the same two files from this change, SHA-256 `601281620983…`.
  Checkout paths normalized to `/trusted/shaka`.
- Requested model `gpt-6.1-sol`, effort `medium`; routed model UNKNOWN. One fresh
  local subscription Codex CLI session per case and arm, read-only, with user
  configuration, rules, and skill injection disabled, in a neutral directory.
- [Fixture](../fixtures/correction_replay/cases.json) and
  [response schema](../fixtures/correction_replay/response.schema.json). Expectations
  stayed outside the prompt. One run per cell; 240 seconds per session; no retries.

| Decision in the one-line repair case | Expected | Baseline | Candidate |
| --- | --- | --- | --- |
| Dismiss the finding from the local pass | no | no | no |
| Path | bounded | full | bounded |
| Validation runs on the new head | 1 | 1 | 1 |
| Local review batches on the new head | 1 | 1 | 1 |
| Reuse the earlier validation as current evidence | no | no | no |
| Checkpoint | rerun | rerun | rerun |
| Walkthrough | affected steps | rewritten whole | affected steps |
| Wait for hosted review of the new head | yes | yes | yes |
| New replies to settled advisory comments | no | no | no |
| A nit in untouched code reopens implementation | no | no | no |
| Final action under Ask | handoff | handoff | handoff |

In the control case the repair grows into a shared module and a new setting. Both arms
chose the full path, a rewritten walkthrough, a fresh checkpoint, the hosted review
wait, and handoff.

| Arm | Input tokens | Output tokens |
| --- | ---: | ---: |
| Baseline, two sessions | 71,771 | 1,709 |
| Candidate, two sessions | 72,669 | 1,528 |

## What this does and does not show

The candidate kept every required rerun and both arms stopped at the same gates. The
only decisions that changed were the path name and the walkthrough. The baseline
workflow, read fresh with the versions stated, already chose one validation run, one
review batch, no advisory replies, and no reopening for a nit.

The fixture tells the agent which URI version the required checks use, so it does not
test whether an agent finds that out. It asks for a plan and executes nothing, so it
does not measure the reviewer prompt change, command mistakes, retries, or elapsed
time. Two cases with one run each cannot establish a rate.
