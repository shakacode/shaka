# Exploratory Jev PR analysis

Jev may help triage a material mismatch between a PR's goal and its change, but we have not established that it improves Shaka delivery. On September 28, 2026, the TypeSafe Playground ran `jev-1.13.0` with the current `material_concern_open` question on a selected excerpt of public [PR #305](https://github.com/shakacode/shaka/pull/305), then on a clearly labeled counterfactual that contradicted its goal. The `jev-latest` alias resolved to that version for these calls and can change later. Cost estimates use [TypeSafe's published input rate](https://typesafe.ai/blog/introducing-system-one-models-and-jev). These are small, selected packets, not blind or complete PR reviews. The CLI adds its own PR/head/evidence prefix, so the scores and token counts are not measured CLI output.

| Current-question case | Material concern open | Input tokens | Estimated input cost at $0.042/MTok |
| --- | ---: | ---: | ---: |
| #305, selected real goal and change excerpts | 0.13 | 626 | $0.00002629 |
| Synthetic counterfactual lacking required alignment and fallback | 0.92 | 515 | $0.00002163 |

The real packet stated #305's scoped goal, cited its alignment, labeling, and fallback changes in `docs/pr-verification.md` and `workflow.yml`, and noted that issue #300's later real-UI trial was outside this PR. The counterfactual kept the goal but replaced those changes with instructions to compare even mismatched image sizes and omit the fallback explanation. It explicitly identified itself as synthetic. The same question distinguished these two hand-picked cases; the counterfactual was not a defect in #305. The real packet also mentioned that reviewers found no material issue, which may have influenced the score. Neither case establishes calibration, false-positive rate, or reviewer benefit.

Earlier Playground work used a different question about PR validation claims and two short packets with no diff excerpts. That question has been removed because Shaka and GitHub can check validation and commit coverage deterministically. The historical results below illustrate wording sensitivity only.

| Case | Earlier material-concern question | Input tokens | Estimated input cost at $0.042/MTok |
| --- | ---: | ---: | ---: |
| [#302](https://github.com/shakacode/shaka/pull/302), current reviewed head | 0.08 | 535 | $0.00002247 |
| [#305](https://github.com/shakacode/shaka/pull/305), scoped guidance step | 0.31 | 482 | $0.00002024 |

The full state text sent for #302 was:

> Public PR https://github.com/shakacode/shaka/pull/302 at head 60ea70b0988e6c66473e7935ac496a305d8224b9. The PR states: “Ready for your GitHub merge of 60ea70b0988e6c66473e7935ac496a305d8224b9: required validate passed, claude-review reported no findings on this head, and the local Codex review found nothing.” Review history says local Codex had no findings on 60ea70b and claude-review on 60ea70b had no findings. Required CI validate passed for 60ea70b; focused tests ran 62 tests with zero failures; RuboCop had no offenses.

The full state text sent for #305 was:

> Public PR https://github.com/shakacode/shaka/pull/305 at head fb40dcdd1b9577b8f66785b76efe55be4a79c024. The PR says: “This ships the guidance step from #300. The issue stays open until a real UI PR tries it; no new tooling was added.” Remaining for #300: “Acceptance still needs a Shaka agent to produce this comparison on a representative UI PR at its tested commit.” Required CI validate passed, local review found no findings, and claude-review found no findings for fb40dcd.

The first wording of `material_concern_open` asked about any unresolved acceptance gap. It gave #305 a 0.74 probability because issue #300 remained open, even though that PR explicitly delivered only the guidance step. The revised question excluded deferred work outside the PR's stated scope and returned 0.31 on the same packet. The companion now asks about a possible mismatch between the goal and change excerpts; that wording has not been evaluated. A synthetic stale-head case was also tried, but checking the current head is deterministic Shaka/GitHub work and is no longer a Jev question.

Before recommending the optional companion broadly, test complete public goal-and-diff packets against independent human labels, examine false positives and false negatives, and compare reviewer attention against Shaka without Jev. This exercise did not measure that benefit or a live CLI call's cost.
