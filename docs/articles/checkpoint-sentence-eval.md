# Does one prompt sentence change what the checkpoint reports?

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-10-19. The maintainer asked it to run step 3 of the
[#421 plan](https://github.com/shakacode/shaka/issues/421#issuecomment-6205960445)
and write up the result. The agent ran the trials, scored them, and drafted the
text. Codex and fresh Claude sessions reviewed the underlying report before
publication.*

Before a Shaka PR is called ready, a reviewer model runs the *checkpoint*. It reads
a short packet about the PR (problem, outcome, validation) and the diff, and
answers one question: did we build the right thing? PRs
[#547](https://github.com/shakacode/shaka/pull/547) and
[#549](https://github.com/shakacode/shaka/pull/549) added one sentence to that
reviewer's prompt. It asks whether the reported testing fits what a failure would
reach and whether a revert would undo it, and asks the reviewer to name paths
nobody exercised.

Tests can't show whether a sentence changes what a model writes. #547's own
checkpoint called the effect unknown. This study measured it.

## Main results

- The sentence changed what reviewers wrote, consistently. With it, every run on
  the two code PRs said whether a revert undoes the change. Without it, none did.
- On a merge-path PR, it surfaced a real untested decision. All 5 runs with the
  sentence noted that the agent, not Ruby, decides when to skip required checks,
  and that nothing tested that decision. None of the 5 runs without it did.
- It kept a docs edit cheap. All 10 runs said Proceed with no concerns. Reports
  with the sentence were 14 to 16 percent longer.
- One cost showed up: on a shared-helper PR, 2 of 5 runs with the sentence said
  Proceed and missed a real gap. All 5 runs without it found that gap. It is now
  [#752](https://github.com/shakacode/shaka/issues/752).
- Recommendation: keep the sentence. Defer the fixed verification table proposed
  for PR descriptions.

![Runs meeting each criterion, with and without the sentence. On #695, revert and untested-command mentions go from 0 to 5, and the HTTP status gap is found by 5 runs without and 3 with. On #552, revert, live-merge and consent mentions go from 0 to 5, and Simplify/reframe from 0 to 3. On #635, all runs say Proceed.](../img/checkpoint-sentence-eval.svg)

## Data and limits

- 30 runs of `shaka post-implementation run` on 2026-10-19, with `openai/codex`,
  `gpt-6.1-sol`, medium effort. That is the reviewer this repository configures
  for its checkpoint.
- Two prompts were tested:
  - this repository's prompt, `.agents/shaka/product-checkpoint.md` (#549):
    3 runs per case and arm;
  - Shaka's built-in prompt, which other repositories get (#547): 2 runs per case
    and arm.
- Each "without" prompt is the current prompt with only that sentence removed.
- One model, one effort, three PRs, one scorer. Two or three runs per cell can
  show a direction. They cannot show a rate.
- Packets were rebuilt from each PR's published description. The original packets
  are not kept.
- The criteria were written after the first of the 30 runs and before the other
  29. Reports were scored under shuffled IDs, but the person who wrote the
  criteria also scored them.
- One criterion, "named an untested consuming command", is narrower than the
  criterion written beforehand. Review caught that. The report shows both rows.
- Cost: $1.78 API-equivalent for all 30 runs, about 6 cents each.

## Method

- **Fixtures:** three merged Shaka PRs, so nothing was invented or planted.

  | Case | PR | Why it fits |
  | --- | --- | --- |
  | Bug in a shared helper | [#695](https://github.com/shakacode/shaka/pull/695) | `check_list.rb` feeds `pr`, `pr watch`, `handoff` and `merge`. |
  | Irreversible side effect | [#552](https://github.com/shakacode/shaka/pull/552) | Lets `shaka merge` submit with no required checks. A revert cannot undo a merge. |
  | Trivial edit | [#635](https://github.com/shakacode/shaka/pull/635) | Two tagline lines in Markdown. |

- **Packets:** each repeats the PR's published problem, scope, safety claim,
  checks and not-verified line.
- **Isolation:** both arms ran the real runner on a checkout of the PR's merge
  commit, with the same packet, diff, settings and AGENTS.md. Only
  `--prompt-file` differed.
- **Scoring:** criteria per case, such as "says whether a revert undoes it" or "names a
  path that was not exercised". Reports were read with the arm hidden.

## Findings

### 1. The sentence makes reviewers state revert limits and untested paths

- **Observed:**
  - #695: 5 of 5 runs with the sentence named a consuming command left untested
    end to end. 0 of 5 without it did.
  - #552: 5 of 5 said no live GitHub merge had run. 0 of 5 without it did.
  - Every run with the sentence said whether a revert undoes the change. No run without it did.
- **Partial overlap:** 4 of 5 runs without the sentence repeated the packet's own
  note that no live rate limit was triggered. They added no path of their own.
- **Evidence:** the result tables in the
  [report](https://github.com/shakacode/shaka/blob/main/eval/reports/checkpoint-blast-radius.md#results).

### 2. On the merge path, it found the decision nobody tested

- **Observed:** all 5 runs with the sentence noted that Ruby checks which commit
  is merged, but the agent decides when to pass `--empty-checks-confirmed-head`.
  They also noted that no reported test covers that decision. All 3 runs with this
  repository's prompt concluded Simplify/reframe. They asked for a decision replay
  covering approved Ask, unapproved Ask, Auto and a changed head, without a real
  merge.
- **Without the sentence:** all 5 runs concluded Proceed. Their main complaint
  was a missing instruction-growth report.
- **Real-world check:** the actual #552 checkpoint ran before #547 merged. It said
  Proceed with no concerns.
- **Consequence:** a wrong merge stays merged after Shaka is reverted. A
  replay could test consent without causing that effect.

### 3. On a docs edit, it stayed quiet

- **Observed:** 10 of 10 runs said Proceed with no concerns and asked for no extra
  checks.
- **Cost:** runs with the sentence added a line noting the rendered page wasn't
  checked. Mean visible words rose from 130 to 151 (this repository's prompt) and
  from 97 to 111 (built-in prompt).

### 4. It can crowd out the question of whether the PR delivers what it promises

- **Observed:** #695's summary promises users will "now see the real error and
  its 403 status". The status is kept only on the exception object. The CLI prints
  `gh pr N failed (exit 1).`
- **Who found it:** all 5 runs without the sentence. 3 of 5 with it. The 2 that
  missed it wrote a paragraph on whether the testing was proportionate and said
  Proceed. So did the real #695 checkpoint, which used the new prompt.
- **Follow-up:** [#752](https://github.com/shakacode/shaka/issues/752).
- **Caveat:** with 5 runs per arm this could be noise.

## Decision

- **Keep #547 and #549.** The sentence surfaces untested paths and revert limits,
  and it caught a real gap on an irreversible path. It added little to a trivial
  edit.
- **Description slice:** [#553](https://github.com/shakacode/shaka/pull/553)
  already shows the PR's intent and a "Not verified" line in every description.
  The remaining proposal was a fixed verification table. Each row would hold a
  claim, how it was checked, and one of `passed`, `failed`, `not verified` or
  `inconclusive`. Recommendation: defer it. Both gaps the reviewers found sat in a summary or
  safety claim that no listed check covered. Ruby cannot detect that from row
  shape, because the agent chooses which claims to list.
- **Next cheaper step:** give the checkpoint the description's intent and
  summary. It can then compare each promise with the evidence.

## Rerun it

The [report](https://github.com/shakacode/shaka/blob/main/eval/reports/checkpoint-blast-radius.md)
lists the commits, the unpublished settings commit, prompt hashes and settings. The
[fixture folder](https://github.com/shakacode/shaka/tree/main/eval/fixtures/checkpoint_blast_radius)
holds the packets, the four prompt versions, all 30 reports, the criteria, the
blind key and the scores.

To test a different checkpoint prompt change the same way, ask your agent:

```text
$shaka Compare the checkpoint prompt before and after PR NUMBER on three merged
PRs: a shared-helper fix, an irreversible change, and a docs edit. Score the
reports blind and write up the result.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
