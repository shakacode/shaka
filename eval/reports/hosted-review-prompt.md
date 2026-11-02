# Hosted Claude review prompts on missed bugs

[The article](../../docs/articles/hosted-review-prompt-comparison.md) states the results,
limits, and recommendation. This report keeps the evidence behind them.

## Pins

- Prompt before #640: `.github/workflows/claude-code-review.yml` at `889364ff^`.
- Current prompt: the same file at `84525c74`.
- Reviews: `claude-sonnet-5-5`, CLI default effort, Claude Code 2.1.312, 2026-11-01.
- Scorer: `claude-opus-5-5`, one packet per commit, read-only tools.
- Bars: [preregistration](../hosted-review-prompt/prereg.md), including the deviation
  it records after unblinding.

## Evidence

Files are under [`eval/hosted-review-prompt/`](../hosted-review-prompt/).

| File | Contents |
| --- | --- |
| `prereg.md` | Question, bars, arms, decoys, stop rules, limits, deviation |
| `targets.jsonl` | The 22 CodeRabbit threads and their flags. This is `gold.json` in the preregistration, without the thread text |
| `runs.jsonl` | All 138 reviews: comments, turns, cost. Local paths are replaced with `<path>` or `<tree>` |
| `findings.jsonl` | The scorer's 62 findings after unblinding |
| `decoys.jsonl` | How the scorer scored each of the 34 decoys |
| `hosted-runs-sample.jsonl` | 30 sampled hosted runs, seed 640, plus the 2 runs either side of #446 |
| `replay/*.rb.txt` | The replay and scoring scripts, stored as text |

## Results against the bars

| Bar | Needed | Result | Met |
| --- | --- | ---: | --- |
| Replay validity | Current prompt at `FINDINGS 0` on at least 50% of runs | 50 of 51 | Yes |
| Replay cost match | Within 3x of 5.3 turns and $0.11 | 5.5 turns, $0.11 | Yes |
| Scorer accuracy | At least 90% on decoys | 34 of 34 | Yes |
| Loosen the criteria | Old prompt at least 5 bugs ahead, and at least 3 to 1 on bugs only one found | 3 bugs ahead, 3 to 0 | No |
| Change the short pass | Current at full depth at least 5 bugs ahead of current at its own depth | 0 ahead | No |

## Scoring passes

The first pass used the defective cleanup the deviation describes. Its totals for the old
prompt were 50 findings: 8 match, 3 near, 39 other, 16 real, 11 unconfirmed, 23 nit. It
counted 1 finding for the current prompt. Results come from the second pass only.

## Hosted findings by period

Counts come from `claude[bot]` report comments and inline threads on the 442 PRs created
from 2026-10-02 to 2026-10-31, read on 2026-11-01.

| Period | Reports | Inline threads | Reports with a count line | Nonzero | Findings counted |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before #446, merged 2026-10-11T19:53:19Z | 152 | 119 | 0 | - | - |
| #446 to #640, merged 2026-10-18T05:13:24Z | 192 | 5 | 127 | 20 | 32 |
| After #640 | 448 | 0 | 448 | 0 | 0 |

## Rerun

`replay/prep.rb.txt` takes a commit list and saved PR history, and freezes each commit's
tree, diff, PR view, and prompts. `replay/run.rb.txt` runs the reviews with
`replay/gh.rb.txt` first on `PATH` and `replay/inline.rb.txt` as the inline comment tool, so
nothing reaches GitHub. `replay/score.rb.txt` scores blind, and `replay/tally.rb.txt`
unblinds. Building the commit list needs the CodeRabbit thread classes from
[PR #1016](https://github.com/shakacode/shaka/pull/1016).
