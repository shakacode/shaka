# Evaluation experiments

Use the [contributor guide](../contributing/evaluating-changes.md) to set up and
grade a run. This index prevents a harness failure from being mistaken for a
successful skill evaluation or repeated without a changed hypothesis.

| Experiment | Evidence | Outcome |
| --- | --- | --- |
| Slice 0 main/Ask r4 | [#206](https://github.com/shakacode/shaka/issues/206); repository deleted before the retention decision | Harness failure. The repaired PR passed checks, but the final image's GitHub CLI could not execute the trusted required-check query. No COMMENT walkthrough or Ask marker. |
| Slice 0 main/Ask r5 | [retained repository](https://github.com/shaka-eval-repos/shaka-slice0-ask-feasibility-206-r5), [PR #1](https://github.com/shaka-eval-repos/shaka-slice0-ask-feasibility-206-r5/pull/1) at `7820fab178704b7a9cea88d480b7542bc753e40d` | Harness failure. The intended initial assertion failed locally and in hosted CI; the repair passed both, but restored the base exactly. With zero changed files, the trusted walkthrough could not publish. PR remains open and unmerged; no Ask marker. |
| Writing-style loader [PR #250](https://github.com/shakacode/shaka/pull/250), offline smoke | Historical baseline `ceb9989`, candidate `e387b5d`; [guide](../contributing/evaluating-changes.md#first-value-case-pr-250) | Baseline omitted `writing_style`; candidate returned a 903-byte trusted guide. Mechanism evidence only, not model behavior or value over a pointer. |
| PR #250 / PR #326 task replay, first pair | [Full pins, tests, usage and cleanup](https://github.com/shakacode/shaka/pull/250#issuecomment-5906768008); [baseline PR](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-a/pull/1) at `3730b62`; [candidate PR](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-b/pull/1) at `5ebc6a2` | Baseline helper `682527f`, candidate `9e25abe`; same target/style pointer and gpt-6.1-sol/medium, two fixed turns, 30 minutes each. Baseline timed out before the final Ask marker despite green checks and walkthrough. Candidate finished Ask in 28m11s but failed an independent recording-receipt probe. Benefit inconclusive; PR #250 remains on hold. Temporary access and runtimes removed; repositories retained. |
| PR #250 / PR #326 task replay, one-hour pair | [Results, writing comparison and next work](reports/pr250-pr326-one-hour.md); [execution evidence](https://github.com/shakacode/shaka/pull/250#issuecomment-5911241095) | Both delivered Ask and passed independent probes. Baseline 41m03s, candidate 46m22s. Writing differences are mixed; incremental value is inconclusive. Process reaping, portable trust setup and one grader assumption needed attention. Repos retained; temporary access removed. |

New runs use the [simple default](../contributing/evaluating-changes.md#simple-default-one-matched-pair):
one matched pair, one hour per arm including CI, separate time and cost limits.
The first pair above keeps its original 30-minute limit; a longer follow-up gets
its own record and does not turn that timeout into a historical success.

Retain evaluation repositories and PRs for history, keeping private measured cells
inaccessible to later agents. Remove temporary access after each run. Before a
new experiment, compare its hypothesis, fixture, baseline and candidate commits,
model/effort, prompt, and success gates with
this index. Public solved repos are not hidden test cells.
