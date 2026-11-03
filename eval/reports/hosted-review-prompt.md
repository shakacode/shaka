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
| `hosted-runs-sample.jsonl` | 15 random successful hosted runs on each side of #640, seed 640, plus the 2 runs either side of #446 |
| `hosted-reports-by-period.jsonl` | Hosted reports, inline threads, and count lines per period, from `replay/periods.rb.txt` |
| `replay/*.rb.txt` | The replay and scoring scripts, stored as text |

## Results against the bars

| Bar | Needed | Result | Met |
| --- | --- | ---: | --- |
| Replay validity | Current prompt at `FINDINGS 0` on at least 50% of runs | 50 of 51 | Yes |
| Replay cost match | Within 3x of 5.3 turns and $0.11 | 5.5 turns, $0.11 | Yes |
| Scorer accuracy | At least 90% on decoys | 34 of 34 | Yes |
| Loosen the criteria | Old prompt at least 5 bugs ahead, and at least 3 to 1 on bugs only one found | 3 bugs ahead, 3 to 0 | No |
| Change the short pass | Current at full depth at least 5 bugs ahead of current at its own depth | 0 ahead | No |

## Results by prompt

Every run used `claude-sonnet-5-5` with the CLI's default effort.

| | Old prompt | Current prompt, depth the commit got | Current prompt, forced full |
| --- | ---: | ---: | ---: |
| Commits | 17 | 17 | 12 |
| Runs | 51 | 51 | 36 |
| CodeRabbit bugs found, any of 3 runs | 3 of 21 | 0 of 21 | 0 of 13 on these commits |
| Runs with a finding, by the scorer | 26 | 1 | 0 |
| Runs with a nonzero count line | 18 | 1 | 0 |
| Findings in the reviews' own count lines | 44 | 1 | 0 |
| Findings the scorer counted | 61 | 1 | 0 |
| Matched a CodeRabbit bug | 6 | 0 | 0 |
| Same place, different failure | 10 | 0 | 0 |
| Other findings | 45 | 1 | 0 |
| Scored real | 18 | 1 | 0 |
| Scored unconfirmed | 15 | 0 | 0 |
| Scored nit | 28 | 0 | 0 |
| Mean turns | 6.4 | 5.5 | 5.6 |
| Mean cost | $0.127 | $0.112 | $0.101 |

Totals with the harder bugs removed:

- **Named in the local report:** 4 threads were already there, and the current prompt
  says not to repeat those. Removing them drops 3 bugs, because the other #902 thread
  stays. Without them, the old prompt found 3 of 18.
- **Needs an outside fact:** 2 bugs depend on a fact the repository does not hold.
  Without them, the old prompt found 2 of 19.
- **Both removed:** the old prompt found 2 of 16.

## Results by bug

Each cell counts the runs that reported the bug. "Near" means the same place with a
different failure. A dash means the commit already got a full review, so no forced
run was needed.

| PR | Bug CodeRabbit raised | Old | Current | Forced full |
| --- | --- | ---: | ---: | ---: |
| [#746](https://github.com/shakacode/shaka/pull/746#discussion_r4318478516) | A bot login could get a second `[bot]` suffix | 0/3 | 0/3 | 0/3 |
| [#742](https://github.com/shakacode/shaka/pull/742#discussion_r4321718491) | A size check refused a description whose reviewer packet would fit | 0/3 | 0/3 | 0/3 |
| [#710](https://github.com/shakacode/shaka/pull/710#discussion_r4331938319) | An `ssh://` username was treated as a credential | 0/3 | 0/3 | - |
| [#710](https://github.com/shakacode/shaka/pull/710#discussion_r4331938341) | A partly failed `rm` left a host without its link | 2/3, 2 near | 0/3 | - |
| [#751](https://github.com/shakacode/shaka/pull/751#discussion_r4320141258) | OpenCode 2 reports left out compaction tokens (outside fact) | 0/3 | 0/3 | 0/3 |
| [#827](https://github.com/shakacode/shaka/pull/827#discussion_r4343165577) | Agent instruction files fell below the automatic-merge floor | 0/3, 3 near | 0/3 | 0/3 |
| [#816](https://github.com/shakacode/shaka/pull/816#discussion_r4342198902) | A file system error could stop description publishing | 0/3 | 0/3 | 0/3 |
| [#792](https://github.com/shakacode/shaka/pull/792#discussion_r4332786363) | A CRLF closing fence stayed open | 0/3 | 0/3 | 0/3 |
| [#860](https://github.com/shakacode/shaka/pull/860#discussion_r4357873521) | A usage refresh kept a stale preview marker | 0/3 | 0/3 | - |
| [#860](https://github.com/shakacode/shaka/pull/860#discussion_r4357873537) | Renderer changes outside one directory needed no preview | 1/3, 1 near | 0/3 | - |
| [#902](https://github.com/shakacode/shaka/pull/902#discussion_r4382251483) | `pushedDate` returns null (outside fact) | 2/3, 1 near | 0/3 | - |
| [#902](https://github.com/shakacode/shaka/pull/902#discussion_r4382953400) | The same `pushedDate` bug on a later commit (in local report, outside fact) | 1/3, 1 near | 0/3 | 0/3 |
| [#901](https://github.com/shakacode/shaka/pull/901#discussion_r4382031732) | Canary checks ran after a failed checkout | 0/3 | 0/3 | - |
| [#901](https://github.com/shakacode/shaka/pull/901#discussion_r4382031750) | A failed `gh pr list` read as no pull requests | 0/3 | 0/3 | - |
| [#901](https://github.com/shakacode/shaka/pull/901#discussion_r4382031758) | A body diff rendered as Markdown with no code fence | 0/3 | 0/3 | - |
| [#898](https://github.com/shakacode/shaka/pull/898#discussion_r4386784581) | A padded `--reviewer` value reported the reviewer missing (in local report) | 0/3, 2 near | 0/3 | 0/3 |
| [#912](https://github.com/shakacode/shaka/pull/912#discussion_r4386113273) | A truncated WIP marker raised `TypeError` | 0/3 | 0/3 | - |
| [#926](https://github.com/shakacode/shaka/pull/926#discussion_r4407332600) | `CONTRIBUTING.md` fell below the merge floor | 0/3 | 0/3 | 0/3 |
| [#961](https://github.com/shakacode/shaka/pull/961#discussion_r4410175388) | A later extglob in a `case` line went undetected (in local report) | 0/3 | 0/3 | 0/3 |
| [#961](https://github.com/shakacode/shaka/pull/961#discussion_r4410175420) | A moved command path split across strings stopped blocking (in local report) | 0/3 | 0/3 | 0/3 |
| [#952](https://github.com/shakacode/shaka/pull/952#discussion_r4409155563) | A later run with no commands hid a sandbox gap | 0/3 | 0/3 | 0/3 |
| [#951](https://github.com/shakacode/shaka/pull/951#discussion_r4408828900) | The kept-installed note was missing when a preview was owed | 0/3 | 0/3 | 0/3 |

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
[PR #1016](https://github.com/shakacode/shaka/pull/1016). Scoring also needs each thread's
text and fix note, which `targets.jsonl` links through its `url` field.

`run.rb.txt` did not stop on a usage-limit error, as the preregistration required. It
stops at its spend cap only. All 138 reviews succeeded on their first attempt, so the rule
never came into play. The scripts stay as they ran.
