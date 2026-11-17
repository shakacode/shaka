# Full-diff or new-commits re-review: Stage 1 pilot

A reader-facing summary is the [article](../../docs/articles/review-scope-pilot.md).

*An AI agent ran this pilot and wrote this report: Claude Code running Claude Opus 5.5, on
2026-11-17 (UTC). The reviewer runs and judge calls below are paid model calls on
subscription logins, priced at Shaka's billed-equivalent estimates. No person has
rechecked the judge's verdicts.*

**Status:** complete. The pilot missed its harm bar, P3. As the preregistration requires,
the eval stops here: Shaka keeps full-diff re-review, and neither the 25-item Stage 1 run
nor Stage 2 runs.

## Result

- **New-commits re-review missed known problems that full-diff re-review found.** Of the 5
  known fixed problems, arm B missed 2 that arm A found and found none that A missed:
  b − c = 2 against a bar of "below 2".
- **The two misses differ.** G11 sat in cycle 1 code that no new-commits diff contained
  until cycle 5, the case the [review signal report](review-signal.md) warned about. Arm B's
  reviewers opened that file in every cycle and still did not report it. Arm A found it at
  cycle 3, one cycle before history did. F5's line was inside arm B's cycle 2 diff, so that
  miss points to run-to-run variance more than to scope.
- **R1, the Stage 1 safety bar, cannot be evaluated.** It needs at least 20 scored K items;
  the pilot has 5 by design.
- **The scorer passed its controls.** It matched all 7 positive controls, none of the 10
  near misses, and no Stage 1 finding to another PR's problem.
- **Arm B cost about a third less.** Per later cycle, B's reviewer cost was 0.64 of A's, as a
  geometric mean of cache-neutral dollars. B reported 12 findings to A's 39.
- **Spend matched the estimate:** $11.85 billed-equivalent against $11.86 estimated and a
  $20 cap. In cache-neutral dollars it was $39.36, above the $35 alternative cap the
  approval did not use, because today's Claude reviewer reads files the historical runs
  could not.

## Why this ran

- Shaka's local review loop re-reads the whole PR diff on every cycle. A *cycle* is one
  reviewed commit; the agent fixes findings in new commits, and the reviewers read the next
  commit.
- Addy Osmani's [post](https://x.com/addyosmani/status/2114604912520921136) on the Claude
  Code team's review says the team re-reviews only the diff after the first cycles.
- The [review signal report](review-signal.md) found 6 of 17 sampled later-cycle findings
  in code the first cycle had already seen. A new-commits re-review could miss those.
- [PR #1195](https://github.com/shakacode/shaka/pull/1195) raised the default round limit
  from 5 to 8, so a long loop now pays for more full-diff re-reviews.
- The [preregistration](review-scope-preregistration.md) splits the question in two. Stage
  1 replays historical later cycles under both policies with no implementing agent, and asks
  whether new-commits re-review loses known defects. Stage 2 runs the implementing agent and
  prices the whole loop. The maintainer approved this Stage 1 pilot at $11.86
  billed-equivalent, capped at $20, and nothing beyond it.

## What ran

- **Arms:** A reviews `git diff MERGE_BASE...CK` at every cycle K. B reviews
  `git diff C(K-1)...CK`, the commits since the previous reviewed commit. Both get the same
  description: the PR title and the earlier findings with their state at that cycle.
- **Reviewers:** `anthropic/claude` on `claude-opus-5-5` and `openai/codex` on its CLI
  default, `gpt-6.1-sol`, both through `shaka review run` at helper commit
  [`61f9d1a`](https://github.com/shakacode/shaka/tree/61f9d1ab94f2a2a4352e9ee433ec230cd83b9734)
  with no ledger.
- **Items:** the three pilot PRs, [#810](https://github.com/shakacode/shaka/pull/810),
  [#902](https://github.com/shakacode/shaka/pull/902) and
  [#954](https://github.com/shakacode/shaka/pull/954): 9 later cycles, 36 reviewer runs.
- **Order:** #902 in one lane; #810 then #954 in another. Each cycle ran its two arms back
  to back in the preregistered order, with both reviewers of an arm at once.
- **Judge:** one fresh `codex exec` per finding, `gpt-6.1-sol` at low effort, with the
  [judge prompt](review-scope/judge-prompt.md) at
  [`86cbc57`](https://github.com/shakacode/shaka/blob/86cbc57253c6efab2994c7c910d5db26248ef04d/eval/reports/review-scope/judge-prompt.md).
  The 17 controls ran first, before any reviewer was paid.
- **Record:** [stage1-pilot-records.jsonl](review-scope/stage1-pilot-records.jsonl) holds
  one line per known problem, warm-up, reviewer run and judge call, with ids, verdicts,
  tokens and both cost figures. Each judge line holds the finding text the judge received,
  so every judge prompt can be rebuilt byte for byte with the pinned prompt. The reviewer
  reports and transcripts are kept outside the repository.

## Bars

| Metric | Bar | Result | Verdict |
| --- | --- | --- | --- |
| P1 completeness | Every attempt completed or recorded; at most 1 retry; usage on every attempt | 36 of 36 runs completed on the first attempt, each with usage | Pass |
| P2 scorer | J1 to J3 hold on the controls | J1 7 of 7; J2 0; J3 0 of 10 | Pass |
| P3 harm signal | `b - c` below 2 over 5 K items | b = 2, c = 0 | **Miss** |
| P4 spend | Within the pilot cap | $11.85 of $20 billed-equivalent | Pass |
| R1 safety | `b - c <= max(1, ceil(0.10 * size(K)))` over at least 20 scored K items | 5 scored K items | Inconclusive by design |
| R2 reviewer cost | Geometric mean of per-cycle B/A, cache-neutral, at most 0.80 | 0.64 (billed 0.59) | Reported only |
| R3 findings per later cycle | Report only | B 12, A 39 over 9 cycles | Reported only |

A missed P3 means "stop and recommend keeping full diff; no full run." J2 also held over
all 51 Stage 1 findings: none matched a cross-PR decoy, and #954, the null item, credited none.

## Known problems

A K item counts as found by an arm when any of that arm's runs, from cycle 2 through the
cycle where history first reported it, has a finding the judge matched to it.

| Item | K item | History first reported | Window | Arm A | Arm B |
| --- | --- | ---: | --- | --- | --- |
| #810 | F4 defect: Guide says the line folds when everything passed, but a review with findings also folds | 2 | 2 | Found by Claude and Codex | Found by Claude |
| #810 | F5 risk: Folded summary says completed for a review that was only host-reported | 2 | 2 | Found by Claude | Missed |
| #902 | G10 defect: A republish can move a known Prompt to CI time later | 3 | 2 to 3 | Missed | Missed |
| #902 | G11 risk: A ready time from an older head can be relabelled with the current head | 4 | 2 to 4 | Found by Claude at cycle 3 | Missed |
| #902 | G14 defect: A new head without a check start keeps the previous head's Prompt to CI time | 5 | 2 to 5 | Found by Claude at cycle 5 | Found by Claude at cycle 5 |

- **G11:** the `fields` method in `pr_watch/throughput.rb`, lines 72 to 74 at cycle 1, writes
  the current head's label but keeps an older ready time. No commit from cycle 2 to 4 changed
  those lines, so no arm B prompt contained them. Arm B's Claude and Codex runs each opened the
  file at every cycle from 2 to 4.
- **F5:** cycle 2's commit rewrote the folded summary to say "local review completed". Arm B's
  diff held that line; its Claude run reported F4 instead, and its Codex run reported nothing.
- **G10:** both arms reported it at cycle 4, after the description listed it as fixed, as
  history did. That is outside its window.

## Cost and findings per cycle

| Item | Cycle | First | A findings | B findings | A billed | B billed | A cache-neutral | B cache-neutral | B/A cache-neutral |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| #810 | 2 | B | 5 | 1 | $0.70 | $0.47 | $3.08 | $1.73 | 0.56 |
| #810 | 3 | A | 1 | 1 | $0.60 | $0.35 | $2.11 | $0.90 | 0.43 |
| #810 | 4 | B | 3 | 1 | $0.54 | $0.32 | $1.59 | $1.07 | 0.67 |
| #902 | 2 | A | 5 | 1 | $1.00 | $0.52 | $3.50 | $1.92 | 0.55 |
| #902 | 3 | B | 5 | 3 | $0.94 | $0.38 | $3.05 | $1.23 | 0.40 |
| #902 | 4 | A | 7 | 2 | $0.76 | $0.50 | $1.92 | $1.98 | 1.03 |
| #902 | 5 | B | 5 | 2 | $0.75 | $0.53 | $1.63 | $1.56 | 0.96 |
| #902 | 6 | A | 5 | 0 | $0.90 | $0.47 | $3.02 | $1.67 | 0.55 |
| #954 | 2 | A | 3 | 1 | $0.64 | $0.49 | $2.42 | $2.13 | 0.88 |

| Arm | Reviewer | Runs | Findings | Mean seconds | Billed | Cache-neutral |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| A | anthropic/claude | 9 | 27 | 80 | $5.38 | $15.79 |
| A | openai/codex | 9 | 12 | 94 | $1.44 | $6.54 |
| B | anthropic/claude | 9 | 11 | 51 | $3.47 | $12.02 |
| B | openai/codex | 9 | 1 | 51 | $0.56 | $2.16 |

- Arm B's prompts were 24% to 74% smaller, but the reviewers read files beyond the prompt.
  Claude's cost fell less than its prompt did.
- Today's Claude reviewer read 1 to 8 files per run from the commit export. The historical
  Claude runs saw only the diff. Arm A's Claude runs averaged $0.60 billed, at the top of
  the historical $0.23 to $0.61 range.

## Spend

| Part | Calls | Billed | Cache-neutral | Estimate, billed |
| --- | ---: | ---: | ---: | ---: |
| Reviewer runs | 36 | $10.85 | $36.51 | $9.28 |
| Warm-ups | 7 | $0.44 | $0.58 | $2.58 with the judge |
| Judge | 75 | $0.56 | $2.27 | |
| **Total** | 118 | **$11.85** | **$39.36** | **$11.86** |

- By item, billed: #902 $7.46, #810 $3.17, #954 $1.22, all under the $15 per-PR limit.
- The 36 runs took 15 minutes of wall-clock time, 08:10 to 08:25 UTC, in two lanes.
- Calls ran on subscription logins. The figures are Shaka's estimates, not invoices.

## Checks on the runs

- **Transcripts:** Claude runs read the commit export with Read and Grep. Two of them also
  wrote a one-line plan-mode note to Claude's own plans folder. Codex runs used read-only Git
  commands: `show`, `grep`, `diff` and `ls-tree`. No run made a web call, read the preregistration or `eval/reports/review-scope/`, or read a
  path outside its fixture. No attempt was void.
- **Models:** every Claude run reported `claude-opus-5-5`, and every Codex run and judge call
  reported `gpt-6.1-sol`.
- **Judge calls:** all 75 returned a valid answer on the first try, and none used a tool.
- **Finding text:** two parser errors surfaced before scoring. A `### Observations`
  subheading and a "no findings" report's checklist were each read as findings. After the
  fix, every report's count matches its attestation. The 7 verdicts on that text are
  marked `"scored": false` in the record and count only in spend.

## Deviations from the preregistration

None changes an arm, bar, decoy, item rule, stop rule, or scorer prompt. Each was settled before
the first paid call unless marked.

1. **Claude reviewer model named on the command.** At pilot start, this repository's trusted
   settings pin the Claude reviewer to `claude-sonnet-5-5`, and `claude -p` defaults to
   `claude-haiku-5-5` on this machine. The preregistration fixes `claude-opus-5-5`, the model
   the historical runs used. Every Claude run passed `--model claude-opus-5-5`; effort stayed
   the CLI default. Codex ran its CLI default, which every run reported as `gpt-6.1-sol`.
2. **#902's fixture path.** `/Users/justin/claude/shaka-worktrees/902` is a live Git worktree
   holding #902's own branch, so the fixture used `/Users/justin/claude/shaka-worktrees/902-2`.
   #810 and #954 used `<PR>`. Both arms of an item share one path.
3. **A fresh Codex home per call.** Each Codex reviewer, warm-up and judge call ran with
   `CODEX_HOME` set to a new directory holding only the login file, to keep machine-level
   Codex instructions out of the calls.
4. **Description labels as of cycle K.** The description lists earlier findings in the
   format Shaka's ledger uses, `- [ID] class: summary (label)`. Each label is the finding's
   recorded state before cycle K was reviewed, rebuilt from the published comments: #902's G7
   reads "fixed in 5e00bf9" at cycle 3 and "Needs your decision" from cycle 4, and G10 reads
   "fixed in 5aec7cb" at cycle 4. Rebased #902 SHAs replace the original ones.
5. **Pinned helper.** Stage 1 used an export of Shaka at `61f9d1ab`, `main` when the task
   started, for both the helper and the fixture settings. `main` moved to `db92844e` before
   the first paid call.
6. **Finding text** (changed after reviewer output arrived). The judge prompt says a finding
   is a numbered item. Codex reports list findings as bullets or as `###` subheadings instead.
   A finding's text is each list item, or each subheading with the text under it, below the
   report's Findings heading, without its number, bullet or heading marks. The parser gained
   subheadings after #902's cycle 2, and stopped at an Observations subheading or a "no
   findings" line after all runs. Every report's count then matched its own `FINDINGS N`
   attestation. Under the literal numbered-item reading, the result is the same: every
   in-window match that decides b and c is a numbered Claude item.
7. **Temporary directory.** `TMPDIR` pointed at `/Users/justin/claude/shaka-state/tmp`, so
   the commit export path the Claude prompt names holds no eval word.
8. **Near miss G7.** G7 was reported in three rounds; its decoy is the first report (round 4).
9. **#902's Claude warm-up ran twice** (after the first paid call). A harness error stopped
   the Codex warm-up; the rerun repeated the Claude warm-up. Both are in the spend.
10. **An extra transcript rule.** Besides the preregistration's void rules, the transcript
    check voided any read outside the item's fixture, such as the real `902` worktree. After
    reviewer output arrived, the protocol-read rule was narrowed from any `eval/reports` path
    to the preregistration's own files: two Codex runs had listed `eval/reports` inside the
    reviewed commit, which predates every review-scope file. No run was void under the final
    rules.

## Limits

- **Five K items.** The pilot scores 5 known fixed problems on 3 PRs. Its harm bar, P3,
  looks for a large effect only. R1, the Stage 1 safety bar, needs at least 20 scored K items
  and is inconclusive here by design.
- **Development rows.** The preregistration's author read these three PRs' reviews, and this
  run's operator tuned the harness on them. The full run draws 25 held-out PRs.
- **History shaped by arm A.** Each K item counts only up to the cycle where history first
  reported it. Stage 1 cannot show what arm B's own loop would have done next.
- **Not today's reviewer.** This repository now reviews with Claude Sonnet 5.5, and the CLI
  default is Haiku 5.5. The pilot measures the preregistered Opus 5.5 arm.
- **Today's Claude reviewer reads files.** The historical Claude runs saw only the diff.
  Today's helper gives Claude a read-only export of the reviewed commit. A new-commits diff
  therefore loses less context for Claude than it would have in October.
- **One run per reviewer, arm and cycle.** F5 shows how much one run can vary: arm B's
  reviewers had its line in their diff and did not report it.
- **Partly rerunnable from the record.** Anyone can re-judge every finding from the record.
  The reviewer reports, transcripts and harness stay outside the repository, so the
  transcript check and the finding parse cannot be rerun from committed files. The record
  keeps each run's tool-call counts and void verdict.
- **One judge.** `gpt-6.1-sol` decided every match. It passed its controls, but no person
  checked the Stage 1 verdicts.

## Rerun it

1. Build the fixtures as the preregistration's
   [dry-run steps](review-scope-preregistration.md#rerun-the-dry-run) describe, with the
   deviations above: settings and helper at `61f9d1ab`, #902 at `902-2`.
2. Write each item's description for cycle K from the published ledger comments, with each
   earlier finding's label as of cycle K.
3. For each later cycle, run both reviewers for one arm, then for the other, in the
   preregistered order:

   ```text
   shaka review run --root FIXTURE --head CK --base BASE --reviewer REVIEWER \
     --criteria-ref FIXTURE_MAIN --description-file DESCRIPTION [--model claude-opus-5-5]
   ```

   BASE is the merge base for A and `C(K-1)` for B. Run Codex with a fresh `CODEX_HOME`
   holding only `auth.json`.
4. Send every finding to the judge one at a time, with the item's known problems from the
   [record](review-scope/stage1-pilot-records.jsonl).
5. Read each transcript for web calls and reads outside the fixture before scoring.

The Ruby harness that ran these steps is not committed. It has no tests, and the
preregistration's stop rule ends the eval here.
