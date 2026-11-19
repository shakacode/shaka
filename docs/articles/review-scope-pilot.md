# Can review skip what it already read? A first test

*An AI agent ran this pilot and wrote this article: Claude Code running Claude Opus 5.5, on
2026-11-17. The agent replayed historical review cycles from three Shaka PRs with paid
reviewer calls. A separate model scored the findings without knowing which policy produced
them. No person has rechecked the verdicts. The
[report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-scope-stage1-pilot.md)
has every run, cost and deviation.*

## Main results

1. **Re-reviewing only new commits missed known problems.** Of 5 problems that past
   reviewers found and the agent fixed, the new-commits policy missed 2 that full
   re-review found. Full re-review missed none that the new-commits policy found. The
   preregistered bar allowed a difference below 2, so the trial stops here and Shaka keeps
   re-reviewing the whole diff.
2. **One miss is the case the trial was built to catch.** On
   [#902](https://github.com/shakacode/shaka/pull/902), the code behind one problem was
   written in the first cycle, and no later diff contained it until the fix. The new-commits
   reviewers opened the file but did not report the problem. Full re-review reported it one
   cycle before the real loop did.
3. **The other miss looks more like chance.** On
   [#810](https://github.com/shakacode/shaka/pull/810), the faulty line was in the
   new-commits diff, and both reviewers still passed over it.
4. **Reading less cost about a third less.** Per cycle, new-commits re-review cost 0.64
   of what full re-review cost, and it reported 12 findings to full re-review's 39. The
   saving would matter only if the safety bar had passed.
5. **Five problems is a small sample.** The bar looks only for large harm. Each reviewer ran
   once per cycle and policy, and one miss fewer would have passed the bar.

## Why this ran

Before Shaka pushes a PR, AI reviewers read the change. The agent fixes what they find in
new commits, and the reviewers read again. Each reviewed commit is a *cycle*. Shaka's
reviewers read the whole PR diff on every cycle, so a PR with five cycles pays for five full
reviews.

- Addy Osmani [described](https://x.com/addyosmani/status/2114604912520921136) how the
  Claude Code team reviews code. After the first cycles, the team re-reviews only the new
  diff.
- Shaka's own [review signal study](review-signal-study.md) found that 6 of 17 sampled
  findings from later cycles sat in code the first cycle had already read. A review of only
  the new commits might miss problems like those.

Shaka also raised its default limit on review cycles from 5 to 8 in
[#1195](https://github.com/shakacode/shaka/pull/1195). Full re-review now costs more on a
long loop. A
[preregistered trial](https://github.com/shakacode/shaka/blob/main/eval/reports/review-scope-preregistration.md)
asks the safety question first, cheaply, before anyone builds the feature or prices the
whole loop.

## What ran

- **Two policies on the same commits.** For each later cycle of three past PRs, both AI
  reviewers read the commit twice. Policy A gave them the whole PR diff, as Shaka does
  today. Policy B gave them only the commits since the previous reviewed commit. Both got
  the same list of earlier findings.
- **Known problems.** Each PR's history records the problems its reviewers found and the
  agent fixed. A policy is credited with one when it reports it at or before the cycle where
  history first reported it.
- **Scoring.** A separate model, `gpt-6.1-sol`, compared each finding with the known
  problems. The scorer saw opaque ids, never which policy, reviewer or cycle produced the
  finding.
  Before any reviewer ran, the scorer was tested on 17 past findings with known answers,
  and it got all 17 right.
- **Size and cost.** 3 PRs, 9 later cycles, 36 reviewer runs: Claude Opus 5.5 and Codex on
  `gpt-6.1-sol`, both through `shaka review run`. The pilot cost $11.85 at Shaka's
  billed-equivalent estimates, against an approved $11.86.

## What happens next

- Shaka keeps full-diff re-review. Nothing in the product changes.
- The 25-PR replay and the live-loop stage do not run. A new trial would need a new
  preregistration.

## Limits

- **Small and known.** The three PRs were the preregistration's development rows, and five
  problems can only show a large effect.
- **Not today's reviewer.** This repository now reviews with Claude Sonnet 5.5. The pilot
  used Claude Opus 5.5, the model of the original runs.
- **Today's Claude reads files.** Shaka now gives Claude a read-only copy of the reviewed
  commit. Claude can look past a narrow diff, which the historical runs could not.
- **One scorer.** `gpt-6.1-sol` decided every match. A person has not checked the
  verdicts.

## Rerun it

The [report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-scope-stage1-pilot.md)
lists the fixtures, commands, deviations and the run record with every verdict. To rerun
the pilot in this repository, ask your agent:

```text
$shaka Rerun the review-scope Stage 1 pilot from eval/reports/review-scope-stage1-pilot.md with fresh fixtures
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
