# Early caller verification

Issue [#421](https://github.com/shakacode/shaka/issues/421) asks Shaka to learn from
poteto's verification practice. This change replaces the existing TDD paragraph
with caller-level reproduction before production edits and an explicit check of
the fix's safety assumption. It keeps the existing delivery gates.

The isolated comparison shows a useful difference in this fixture: the candidate
checked the shipped CLI before editing and preserved empty-chunk delivery. Both
arms already wrote a failing receiver test before editing. Earlier testing alone
is therefore a tie; broader effectiveness is unknown.

## Comparison

On October 17, 2026 UTC, four fresh subscription Codex CLI sessions used
`gpt-6.1-sol`, requested medium effort, a 180-second deadline each, and the
[same seed](../fixtures/early_verification/seed) and [tasks](../fixtures/early_verification/cases.json).
Observed routed model is UNKNOWN. Only the implementation paragraph differed;
this tests that instruction, not a whole-workflow rollout. No GitHub mutation or
metered provider was used.

Baseline is the implementation paragraph at `a5026372f4734ab77369068634f99d476a8d9ceb`;
candidate is this PR's replacement. Their SHA-256 hashes are respectively
`6ab4d852660187d57ab963585fd127bcd7164b700db5a4926f27c0aff15b9253` and
`6f1e57796247e27cfc3847b7f1a183c64dc3178aeea84ad1165a829224ccc5a6`.
Prompts contained `Implementation guidance:`, that paragraph, `Task:`, and the
unchanged task. Neutral directories contained no project instructions. A temporary
Codex home retained subscription authentication without global instructions;
rules, user config and skill injection were disabled. Completed command traces
showed no global guidance or installed Shaka reads in these four runs.

Criteria fixed before these sessions: reproduce through a real caller before the
first production edit, rerun the same check after the fix, exercise the shared
decoder's buffering assumption, and keep the typo control limited to its README.
The independent probe, developed after preliminary trials, was fixed before these
sessions and never included in their prompts. It tests all 595 two-cut partitions
of three records, asserting delivery after each of the three chunks, including
empty chunks. These are 1,785 assertions, not independent model trials.

| Observed action | Baseline | Candidate |
| --- | --- | --- |
| Real Receiver failure before production edit | Yes: event 4, two failures | Yes: event 7, two failures and an empty-chunk error |
| CLI before production edit | No | Event 4: emitted only `b`, expected `a,b` |
| First production edit | Event 6: remove early return | Event 9: remove early return and retain an empty string buffer |
| Rerun | Events 7/9: 4 tests, 10 final assertions pass | Event 10: 5 tests, 80 assertions pass; CLI emits `a,b` |
| Independent probe | Fails at cuts `[0,0]`: nil buffer | Passes all 1,785 assertions |
| Typo control | Only README changed; spelling checked | Only README changed; unified diff inspected |

Event numbers refer to native JSONL `item_N` IDs. The [selected native events](../fixtures/early_verification/outputs/events.jsonl)
retain command order, changed paths and captured output with host paths normalized.
Generated code and tests are retained as
[baseline](../fixtures/early_verification/outputs/baseline.patch) and
[candidate](../fixtures/early_verification/outputs/candidate.patch) patches.
The candidate needed one command repair: Ruby 2.6 could not resolve
`require_relative` from `-e`; it reran with `require` before editing production code.

| Run | Seconds | Input tokens | Cached within input | Output | Reasoning within output |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline behavior | 37.55 | 108,061 | 98,048 | 1,608 | 369 |
| Candidate behavior | 39.86 | 146,038 | 130,560 | 2,007 | 456 |
| Baseline typo | 12.60 | 57,663 | 52,480 | 318 | 0 |
| Candidate typo | 12.92 | 58,777 | 38,528 | 416 | 19 |

These are native completed-turn counters for these sessions only, excluding
implementation, reviews and qualification attempts. They establish no efficiency
benefit. Candidate behavior used more tokens and time.

## Reproduce the outcome

Copy the seed into two temporary directories. Apply the corresponding patch with
`patch -p1 < /absolute/path/to/outputs/ARM.patch`, then run from this checkout:

```sh
ruby eval/fixtures/early_verification/probe.rb /path/to/baseline-copy
ruby eval/fixtures/early_verification/probe.rb /path/to/candidate-copy
```

Expected exit statuses are 1 and 0. Run each generated suite with
`ruby -Itest -e 'Dir["./test/*_test.rb"].sort.each { |file| require file }'`.
To repeat the model comparison, use fresh seed copies and the prompt construction
above, holding model, effort, deadline and host context constant. Retain command
order and outputs; do not infer pre-edit verification from final tests alone.
The seed intentionally fails the independent probe; it is not production code.
Comments and executable permission were added after copying the trial seeds;
their Ruby behavior is unchanged.

## Qualification and limits

Preflight corrected an accidentally frozen initial buffer before any model run.
The first four sessions inherited global instructions, including installed Shaka.
Both behavior arms verified before editing; only candidate passed the later probe.
Two attempted isolation sessions were stopped when the intended flag was absent.
Another two completed with `project_doc_max_bytes=0` but still loaded global
instructions; both passed the probe. They are excluded from the isolated comparison,
not counted as a candidate advantage. No outcomes were
retried within the final four-session comparison. Qualification overhead and
these earlier outcomes remain separate from its usage figures.

This synthetic streaming task gives concrete behavior evidence for one model and
one pair. The probe covers chunk boundaries, not malformed JSON or arbitrary
transport failures. Shared subscription execution, model variability and no
randomized repetitions limit causal attribution. Real Shaka delivery is untested.
The evidence supports trying this small instruction change; it does not prove
general compliance or justify a new runtime gate.

The rendered workflow grows by 30 words/230 UTF-8 bytes; entry point and AGENTS.md
are unchanged. The paragraph is rendered on every task, with its caller procedure
conditional on behavior changes. It adds no file load, setting or dependency.
The predecessor's `verify-pr-fix` practice informed the before/after check; no
legacy contracts or implementation were imported.
