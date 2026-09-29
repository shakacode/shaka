# Exploratory Jev PR analysis

Jev may help triage a material mismatch between a PR's goal and its change, but we have not established that it improves Shaka delivery. On September 28, 2026, the TypeSafe Playground ran `jev-1.13.0` on two short public PR excerpts. The `jev-latest` alias resolved to that version for these calls and can change later. The cost uses [TypeSafe's published input rate](https://typesafe.ai/blog/introducing-system-one-models-and-jev). These packets did not contain diff excerpts, so they do **not** evaluate the companion's current question about the change itself. They illustrate question-wording sensitivity and approximate input cost only. The Playground used the state text quoted below; `scripts/analyze` adds its own PR/head/evidence prefix, so these scores and token counts are not measured CLI output.

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
