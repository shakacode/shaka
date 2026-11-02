# Did the strict hosted Claude prompt cause the missed bugs?

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on 2026-11-01.
[PR #1016](https://github.com/shakacode/shaka/pull/1016) proposed this comparison
after hosted Claude reported zero findings on every review following
[#640](https://github.com/shakacode/shaka/pull/640). The maintainer approved the
spend. The agent ran the reviews, read the results, and drafted the text. A separate
Opus scorer classified findings without knowing which prompt produced each review.*

Hosted Claude review is the GitHub Actions job that reviews pushed commits on PRs.
[#640](https://github.com/shakacode/shaka/pull/640) replaced its short, general
prompt with a strict one. The new prompt also adds a short pass for commits that
already have a local Claude review.

CodeRabbit later led to code bug fixes on 17 commits where hosted Claude had reported
zero findings. The study replayed both prompts on those commits, with the same model.

## Main results

- Restoring the old prompt would catch few of these bugs. The old prompt found 3 of
  the 21 bugs. The current prompt found none.
- Forcing a full review changed nothing on the 12 commits that got the short pass.
  The current prompt raised no findings in 36 full-review runs.
- The current prompt almost never reports anything: 1 finding in 87 runs, and that
  finding was real. The old prompt raised 61 findings in 51 runs.
- The largest drop came a week before #640.
  [#446](https://github.com/shakacode/shaka/pull/446) bumped the review action, and
  the logged model changed from `claude-sonnet-5` to `claude-sonnet-5-5`. Inline
  threads fell from 119 on 152 reports to 5 on 192 reports. The agent found this while
  pricing the run, outside the preregistered questions.
- Recommendation: keep the current prompt for now. Test the model next. The rule
  written before the runs called for keeping the prompt unless the old one found at
  least 5 more bugs.

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

## The model change

The workflow sets no model, so the review action chooses one. The preregistration did
not plan this analysis. Report and thread counts come from public PR comments, and the
[sampled runs](https://github.com/shakacode/shaka/blob/main/eval/hosted-review-prompt/hosted-runs-sample.jsonl)
come from public Actions logs.

| Period | Model logged | Prompt | Reports | Inline threads | Mean report size |
| --- | --- | --- | ---: | ---: | ---: |
| Before #446 | `claude-sonnet-5` | Old | 152 | 119 | 1,966 characters |
| #446 to #640 | `claude-sonnet-5-5` | Old | 192 | 5 | 679 characters |
| After #640 | `claude-sonnet-5-5` | Current | 448 | 0 | 265 characters |

Run logs sampled from each period show the same step:

| Period | Sampled runs | Mean turns | Mean cost |
| --- | ---: | ---: | ---: |
| Before #446 | 9 | 37.1 | $0.90 |
| #446 to #640 | 6 | 6.2 | $0.10 |
| After #640 | 15 | 5.7 | $0.11 |

- #446 merged at 19:53 UTC on 2026-10-11. The run at 10:32 UTC that day logged
  `claude-sonnet-5` and 51 turns. The next run, at 20:01 UTC, logged
  `claude-sonnet-5-5` and 7 turns.
- 127 reports between #446 and #640 carried a finding count. 20 of them reported
  findings, 32 in all.
- #640 did not change run length. Mean turns stayed near 6 on both sides of it.

## Data and limits

- **Commits:** the list holds 22 CodeRabbit threads, 21 bugs, 17 commits, and 16 PRs.
  PR #1016 said 15 PRs. One #902 bug spans two threads on two commits.
- **Same view for every run:**
  - Each run got the hosted job's own integration commit as a one-commit tree.
  - `gh pr diff` returned that commit's diff.
  - `gh pr view` returned the description and local review comments as they stood at
    the hosted report, read from GitHub's edit history.
  - CodeRabbit comments and earlier Claude reports were left out.
  - Comments went to files, and nothing reached GitHub.
- **Prompts:** both came byte for byte from
  `.github/workflows/claude-code-review.yml`, at the commit before #640 and at
  `84525c74`. Only workflow expressions were filled in.
- **The replay matches the hosted job:** the current prompt reported `FINDINGS 0` on
  50 of 51 runs. All 51 averaged 5.5 turns and $0.11, against 5.3 turns and $0.12 in the
  hosted logs for the same commits.
- **Selection:** these commits were chosen because the current prompt found nothing
  and CodeRabbit found a bug. Noise was measured only on commits with a known bug,
  so this study says nothing about clean commits.
- **Sample size:** three runs per commit show the spread but cannot show a small
  difference between prompts.
- **Not an exact copy of the job:** runs used the local Claude Code CLI 2.1.312, not the
  action. The action's CLI version does not appear in its logs.
- **Scoring:** a finding matched when it named the same file or function and the same
  failure. The scorer split notes into findings, so its counts run above the reviews' own
  count lines: 10 scored findings came from 8 runs whose count line said 0. The scorer got all 34 planted decoys right. Decoys did not pass through the
  text cleanup described below, so they could not catch that defect.
- **A correction to scoring:** the agent's audit found a cleanup step that removed
  every review line containing "review" or "preview". The agent fixed that step alone
  and rescored. The first pass counted 2 bugs for the old prompt and the second 3.
  The agent had seen the first results before the fix. The scorer had not.
- **Soft verdicts:** match results are firmer than real, nit, and unconfirmed. The same
  lost-update finding on #902 scored real on one commit and unconfirmed on the other.
  A verified `handoff` break on [#912](https://github.com/shakacode/shaka/pull/912)
  scored nit. The third `pushedDate` run scored near because it predicted a query
  error, not a null value.
- **Cost:** 138 reviews cost $15.78 at the CLI's reported prices, scoring $5.32, and
  setup checks $0.03. Runs drew on a Claude subscription, so these are API-equivalent
  figures.

The [report](https://github.com/shakacode/shaka/blob/main/eval/reports/hosted-review-prompt.md)
links the preregistration, every review, the scores, the decoys, and the replay scripts.

## Findings

### 1. The old prompt would not recover most of these bugs

- **Observed:** the old prompt found 3 of 21 bugs. The rule set in advance needed a
  gap of at least 5 bugs against the current prompt at full depth. The gap was 3.
- **Evidence:** on #710, both matching runs cited the open decision already written in
  the PR description. On #902, the matching runs named the `pushedDate` deprecation
  from memory and asked someone to check it.
- **Limit:** the current prompt also read those PR descriptions and stayed silent. Its
  rules exclude what a reviewer cannot confirm, and the #710 bug fits its rules.
- **Proposed change:** none to the criteria yet.
- **Guarantee at risk:** the current prompt keeps missing what the old one found here.

### 2. The short pass is not shown to be the cause

- **Observed:** the forced full review raised no findings in 36 runs on the 12 commits
  that got the short pass.
- **Limit:** 4 of the 13 threads on those commits were named in the local report. The
  forced runs could read that report through `gh pr view`.
- **Proposed change:** leave the short pass alone.

### 3. The current prompt also drops real findings outside this bug list

- **Observed:** the old prompt raised 45 findings beyond the CodeRabbit list. The scorer
  called 10 real, 10 unconfirmed, and 25 nits. The real ones cover 6 distinct issues.
- **Evidence:**
  - An old-prompt finding named a lost description edit on #902. `main` now checks before it writes.
  - The one current-prompt finding named a stats write error that aborted `pr watch` on
    #902. `main` now rescues that error.
  - Two old-prompt findings on #901 still apply to `main`. A failed comment skips
    closing old canary PRs in `skills/shaka/lib/shaka/canary/run.rb`. A `diff` error
    gives an empty diff in `skills/shaka/lib/shaka/canary/body.rb`.
- **Limit:** this measures one prompt's noise on selected commits. Most old-prompt
  findings led nowhere before #640 too. About 83% of them got no push, according to
  PR #1016.
- **Proposed change:** for the maintainer to decide. Loosening trades about 1 finding per
  run, about 3 in 10 of them real, against reviews that say almost nothing.

### 4. The model change is the next thing to test

- **Observed:** inline threads per report fell by about 30 times at #446. Run length
  fell by about 6 times at the same point.
- **Limit:** #446 changed the action version and the model together. Periods also differ
  in PR mix. Nothing here has tested the older model on these commits.
- **Proposed change:** replay these commits on `claude-sonnet-5`, which still answered
  on 2026-11-01. At about $0.90 per run, one run per commit for both prompts is about
  $31. Pin a model in the workflow if the older one finds more.
- **Guarantee at risk:** a longer review costs about 8 times more per run.
- **Maintenance:** one workflow setting, plus an update when the pinned model retires.

## Run the same study on your repository

```text
$shaka Replay our hosted review prompt before and after its last change on commits
where another reviewer later found a bug. Use one model, freeze each PR as it stood,
post nothing, and score without showing which prompt wrote each review. Show me the
estimated cost before any paid run.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
