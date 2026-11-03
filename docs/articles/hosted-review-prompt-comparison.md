# Did our strict review prompt cause the missed bugs?

*Written with AI. I'm Justin Gordon. I asked Claude Code, running Claude Opus 5.5, to
run this study and draft this article in my voice on 2026-11-02. A separate Opus scorer
graded the reviews without knowing which prompt wrote them.*

Every push to a PR in this repository gets a hosted Claude review from GitHub Actions.
On 2026-10-18, [#640](https://github.com/shakacode/shaka/pull/640) swapped that
review's short, general prompt for a strict one: report only problems you can prove
from the code. After that, hosted Claude said "no issues" on every review. CodeRabbit
kept finding real bugs on the same commits.

[PR #1016](https://github.com/shakacode/shaka/pull/1016) counted those misses. I wanted
to know whether the strict prompt caused them.

## The short answer

Not as far as this test can tell.

- I picked the 17 commits where hosted Claude said "no issues" and CodeRabbit later
  found a bug, 21 bugs in all. The old prompt caught 3 of them. The current prompt
  caught none.
- The current prompt does a short pass when a local Claude review already ran. Forcing
  a full review didn't help: 36 runs, zero findings.
- The bigger drop came a week earlier. [#446](https://github.com/shakacode/shaka/pull/446)
  bumped the review action, and the model changed from `claude-sonnet-5` to
  `claude-sonnet-5-5`. Inline review comments went from 119 on 152 reviews to 5 on 192.

I'm keeping the current prompt for now. The next thing to test is the model.

## What we ran

- Both prompts, copied exactly from `.github/workflows/claude-code-review.yml` before
  and after #640, on all 17 commits.
- A third version: the current prompt forced to a full review, on the 12 commits that
  got the short pass.
- Three runs of each, all on `claude-sonnet-5-5`, the model the hosted review uses now.
  138 reviews in all.
- Each review saw the PR as it stood when hosted Claude reviewed it. CodeRabbit's
  comments were hidden, and nothing was posted to GitHub.
- I set the decision rule before any run: loosen the prompt only if the old one caught
  at least 5 more bugs.

## Results

| | Old prompt | Current prompt | Current, full review |
| --- | ---: | ---: | ---: |
| Reviews | 51 | 51 | 36 |
| CodeRabbit bugs caught | 3 of 21 | 0 of 21 | 0 of 13 |
| Findings | 61 | 1 | 0 |
| Findings the scorer called real | 18 | 1 | 0 |
| Cost per review | $0.13 | $0.11 | $0.10 |

The old prompt caught these three:

- [#710](https://github.com/shakacode/shaka/pull/710#discussion_r4331938341): a
  partly failed `rm` left a host without its link. 2 of 3 runs caught it, and both
  pointed to the PR description, which already listed it as an open question.
- [#860](https://github.com/shakacode/shaka/pull/860#discussion_r4357873537): renderer
  changes outside one directory didn't require a preview. 1 of 3 runs.
- [#902](https://github.com/shakacode/shaka/pull/902#discussion_r4382251483): GitHub's
  `pushedDate` field comes back null. The runs remembered that GitHub had deprecated the
  field and asked someone to check.

The [eval report](https://github.com/shakacode/shaka/blob/main/eval/reports/hosted-review-prompt.md)
has every bug, every review, and the detailed counts.

## What I take from this

### Going back to the old prompt wouldn't fix this

Going back to the old prompt would catch 3 more of these 21 bugs, short of the 5 I
asked for. The full review caught nothing either, so the short pass isn't shown to be
the cause. The test doesn't clear the strict prompt, though. Both prompts ran on the
newer model, and the old prompt might do better on the old one.

### The current prompt is very quiet

The current prompt raised 1 finding in 87 runs, and that one was real: on #902, a stats
write error could stop `pr watch`. `main` now catches that error.

Besides the CodeRabbit bugs, the old prompt raised 45 findings. The scorer called 10 of
them real, covering 6 distinct problems:

- On #902, a description edit made during a stats write could be lost. `main` now
  re-reads the description before writing.
- Two are still on `main`, in the canary code from #901. A failed comment skips
  closing old canary PRs. A `diff` error gives an empty diff. A separate fix is in
  progress.
- The other three were on #901 too. The Cursor installer ran from `curl | bash` with
  secrets in its environment. The throttle counted unrelated canary runs. Spend amounts
  with commas read as unknown.

Loosening the prompt would bring back about 1 finding per review, roughly 3 in 10 of
them real. Before #640, about 83% of hosted findings didn't lead to a push, according
to #1016. I'd rather test the model before deciding.

### Test the model next

The workflow doesn't name a model, so the action picks one. The counts below come from
public PR comments and Actions logs:

| Period | Model | Reviews | Inline comments | Turns per review | Cost per review |
| --- | --- | ---: | ---: | ---: | ---: |
| Before #446 | `claude-sonnet-5` | 152 | 119 | about 37 | about $0.90 |
| #446 to #640 | `claude-sonnet-5-5` | 192 | 5 | about 6 | about $0.10 |
| After #640 | `claude-sonnet-5-5` | 448 | 0 | about 6 | about $0.11 |

Turns and cost come from sampled runs: 9 before #446, 6 between #446 and #640, and 15
after #640. #446 merged at 19:53 UTC on 2026-10-11.
The last successful run before it used `claude-sonnet-5` for 51 turns. The first one
after it used `claude-sonnet-5-5` for 7.

One more change landed in the middle period.
[#507](https://github.com/shakacode/shaka/pull/507), on 2026-10-14, changed how the
report ends, to a fixed finding-count line. The review instructions stayed the same, but
some findings could have moved from inline comments into the summary.

I didn't plan this part. The model change turned up while we priced the replay, and
nothing has tested it yet. #446 changed the action version and the model at the same time. The next step is
to replay these commits on `claude-sonnet-5`, which still responds. One run per commit
with both prompts costs about $31. If the older model finds more, we pin a model in the
workflow. A review would then cost about 8 times as much, and we'd have to update the pin
when that model retires.

## Limits

- The commits were picked because a bug was known, so this says nothing about clean
  commits.
- Three runs per commit can't show a small difference between prompts.
- The reviews ran on the local Claude Code CLI 2.1.312, not the GitHub action. They
  still matched the hosted job on these commits. 50 of 51 current-prompt runs said "no
  issues", at 5.5 turns and $0.11 per run, against 5.3 turns and $0.12 hosted.
- Each replay used a fresh one-commit repository, so its local commit SHA didn't match
  the one in the prompt. Both prompts ran that way.
- Claude's audit of the scorer found a bug: its cleanup step deleted every line with
  "review" or "preview" in it. Fixing that and rescoring moved the old prompt from 2
  bugs to 3. Claude had seen the first results by then; the scorer hadn't.
- The scorer's "caught" calls are firmer than its real, nit, and unconfirmed calls.
- 4 of the bug threads were already in the local review report the hosted job could
  read. The current prompt says not to repeat those. 3 need a fact from outside the
  repository. The report gives totals without them.
- PR #1016 counted 15 PRs. The list here has 16.
- The run cost $15.78 for reviews, $5.32 for scoring, and $0.03 for setup checks. These
  are API-equivalent prices; the runs used a Claude subscription.

## Run the same study on your repository

```text
$shaka Replay our hosted review prompt before and after its last change on commits
where another reviewer later found a bug. Use one model, freeze each PR as it stood,
post nothing, and score without showing which prompt wrote each review. Show me the
estimated cost before any paid run.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
