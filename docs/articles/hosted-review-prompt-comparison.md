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
- Local reviews ran a stronger model, `claude-opus-5-5`, on most commits. The hosted
  review never set a thinking level, and most local reviews didn't either.

I'm keeping the current prompt for now. Testing more models doesn't look worth it, and
I explain why below.

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
- Two were in the canary code from #901. A failed comment skipped closing old canary
  PRs, and a `diff` error gave an empty diff.
  [#1030](https://github.com/shakacode/shaka/pull/1030) fixed both.
- The other three were on #901 too. The Cursor installer ran from `curl | bash` with
  secrets in its environment. The throttle counted unrelated canary runs. Spend amounts
  with commas read as unknown.

Loosening the prompt would bring back about 1 finding per review, roughly 3 in 10 of
them real. Most hosted findings didn't lead to a push even before #640: about 87% before #446 and
about 73% from #446 to #640, according to
[the CI and hosted review study](ci-and-hosted-review-repairs.md). I'm not loosening it yet.

### The local reviews ran a stronger model

The hosted review and the local reviews didn't use the same model. The hosted job never
set a thinking level. Local reviews set one in about 1 of 8 Claude rounds. Every other
review used Claude Code's default. The counts below come from public Actions logs and
the local review tables on the 442 PRs from October:

| Reviewer | Model | Thinking level | Reviews | Findings per review | Cost per review |
| --- | --- | --- | ---: | ---: | ---: |
| Hosted Claude, before #446 | `claude-sonnet-5` | not set | 152 | 0.8 inline comments | about $0.90 |
| Hosted Claude, #446 to #640 | `claude-sonnet-5-5` | not set | 192 | 0.03 inline comments | about $0.10 |
| Hosted Claude, after #640 | `claude-sonnet-5-5` | not set | 448 | 0 | about $0.11 |
| Local Claude | `claude-opus-5-5` in 1,370 of 1,478 | not recorded in 1,283; medium in 187 | 1,478 | 2.2 | $0.33 |
| Local Codex | not recorded in 1,452 of 1,514 | not recorded in 1,358; medium in 153 | 1,514 | 0.24 | $0.10 |
| This replay | `claude-sonnet-5-5` | not set | 138 | see above | $0.11 |

Hosted costs are means of sampled runs. Local costs are medians of the largest group of
rounds: Opus with no thinking level recorded, and Codex with no model recorded.

- The hosted counts and the switch at #446 are covered in more detail in
  [the CI and hosted review study](ci-and-hosted-review-repairs.md). Hosted turn and cost
  figures come from sampled runs: 9 before #446, 6 between #446 and #640, and 15 after
  #640.
- Local Claude ran Opus for most reviews, at about three times the hosted cost per
  review. Local reviews also used a different prompt, so their findings per review
  don't compare directly with the hosted ones.
- [#507](https://github.com/shakacode/shaka/pull/507), on 2026-10-14, changed how the
  hosted report ends, to a fixed finding-count line. The review instructions stayed
  the same, but some findings could have moved from inline comments into the summary.

### Is it worth testing other models?

I don't think so. The CI study proposed rerunning both prompts under both models. Here
are the two tests I considered.

**The older model, `claude-sonnet-5`.** A replay would show whether #446 caused most of
the drop. One run per commit with both prompts costs about $31. If it found more, the
fix would be pinning an older model. A review would then cost about 8 times as much,
and we'd have to move the pin when that model retires. The test answers a history
question, and its fix is one I wouldn't adopt.

**The stronger model, `claude-opus-5-5`.** Moving hosted review to Opus is a change we
could actually make. Local Opus reviews cost about three times what hosted Sonnet reviews did, so a
replay of both prompts on these commits would cost about $11. On 12 of these commits, local Opus
reviewed the same commit before CodeRabbit commented. Its rounds named 1 of the 13 bug
threads there, going by a keyword search with each match read. The local Opus and Codex
reports together named 4. A hosted Opus review would get a different prompt, and most
local rounds ran at the default thinking level. Still, I'd expect it to miss most of the
same bugs.

CodeRabbit is a different reviewer, and it caught bugs that both Claude reviews missed.
If we want more of those catches, the lever is CodeRabbit's review limit. The limit left
249 of October's 442 PRs without a CodeRabbit review.

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
- Each planted decoy repeated a bug's text word for word, so the 34 of 34 shows the
  scorer matches exact restatements. The decoys say less about paraphrased findings.
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
