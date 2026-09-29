# Exploratory Jev PR evidence check

Jev can be useful as optional review triage, but this small check does not establish that it improves Shaka delivery. On September 28, 2026, the TypeSafe Playground ran `jev-1.13.0` with the two fixed Noul questions in [`analysis.rb`](../skills/shaka-jev/lib/shaka_jev/analysis.rb). The cost uses [TypeSafe's published input rate](https://typesafe.ai/blog/introducing-system-one-models-and-jev). The cases below use public Shaka PR excerpts and one explicitly synthetic control. They are short, selected packets, not blind or complete PR reviews.

| Case | Validation supported | Material concern open | Input tokens | Estimated input cost at $0.042/MTok |
| --- | ---: | ---: | ---: | ---: |
| [#302](https://github.com/shakacode/shaka/pull/302), current reviewed head | 0.78 | 0.08 | 535 | $0.00002247 |
| [#305](https://github.com/shakacode/shaka/pull/305), scoped guidance step | 0.62 | 0.31 | 482 | $0.00002024 |
| Synthetic new head with only older evidence | 0.06 | 0.75 | 450 | $0.00001890 |

The full state text sent for #302 was:

> Public PR https://github.com/shakacode/shaka/pull/302 at head 60ea70b0988e6c66473e7935ac496a305d8224b9. The PR states: “Ready for your GitHub merge of 60ea70b0988e6c66473e7935ac496a305d8224b9: required validate passed, claude-review reported no findings on this head, and the local Codex review found nothing.” Review history says local Codex had no findings on 60ea70b and claude-review on 60ea70b had no findings. Required CI validate passed for 60ea70b; focused tests ran 62 tests with zero failures; RuboCop had no offenses.

The full state text sent for #305 was:

> Public PR https://github.com/shakacode/shaka/pull/305 at head fb40dcdd1b9577b8f66785b76efe55be4a79c024. The PR says: “This ships the guidance step from #300. The issue stays open until a real UI PR tries it; no new tooling was added.” Remaining for #300: “Acceptance still needs a Shaka agent to produce this comparison on a representative UI PR at its tested commit.” Required CI validate passed, local review found no findings, and claude-review found no findings for fb40dcd.

The synthetic control changed the head while leaving older observations:

> Synthetic control based on public PR https://github.com/shakacode/shaka/pull/302. Hypothetical new head: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb. The PR claims validation is complete, but every supplied check and review observation names earlier commit 60ea70b0988e6c66473e7935ac496a305d8224b9. No validation or review observation for the hypothetical new head is supplied.

The first wording of `material_concern_open` asked about any unresolved acceptance gap. It gave #305 a 0.74 probability because issue #300 remained open, even though that PR explicitly delivered only the guidance step. The revised question excludes deferred work outside the PR's stated scope and returned 0.31 on the same packet. This sensitivity is a reason to show probabilities and evidence to a person, never to turn a score into a merge gate. The current-head check remains deterministic Shaka/GitHub work; the synthetic case only tests Jev's response to missing evidence.

These three cases support an experimental, opt-in companion. A decision to automate or recommend it broadly needs a fixed, larger set of complete public evidence packets, independent labels, false-positive and false-negative review, and comparison against Shaka without Jev. Measure reviewer attention as well as API cost; this exercise did not measure it.
