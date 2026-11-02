# CI errors and hosted review repairs over 30 days

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-11-01. The maintainer asked how often CI failed and how often the hosted
Claude review found a bug that needed another push. The question tests a claim:
running code reviews locally first removes most back-and-forth with reviews on
GitHub. The agent collected the data, classified the CI failures and hosted Claude
findings, and drafted the text. A second agent classified the CodeRabbit, Greptile, and
`react_on_rails` Claude threads.*

Two terms recur below:

- Local review is the review an agent runs through Shaka before pushing a commit.
- Hosted Claude review is the GitHub Actions job that reviews pushed commits on
  ready PRs from the same repository, except Dependabot's.

CI and repair counts cover `shakacode/shaka`. One section compares hosted reviewers on
`shakacode/react_on_rails`, because Greptile does not run on `shaka`. All sources are
public GitHub data: Actions runs and logs, PR comments, and review threads. The window
is 2026-10-02 to 2026-10-31 UTC.

## Main results

- CI failed 88 times in 4,291 runs. The change on the branch caused 30 of those
  failures: 14 on 10 regular PRs, 9 on a Windows port, and 7 on Dependabot bumps.
  Flaky tests caused 15, and the hosted review job itself failed 32 times.
- Hosted Claude review led to 10 code bug fixes on 8 PRs. All 10 came in the
  first 16 days. The review also led to 10 docs or instruction fixes and 7
  cleanups.
- Hosted Claude reported zero findings on all 446 reports after
  [#640](https://github.com/shakacode/shaka/pull/640) merged on 2026-10-18. That PR
  changed the review prompt. Local review was running before and after it.
- Back-and-forth continued. CodeRabbit, another hosted reviewer, led to 55 fixes on
  30 PRs after #640 merged, including 23 code bug threads. Hosted Claude had reported
  zero findings on the same commit for 53 of those fixes, across 33 commits.
- CodeRabbit's counts run low. Its free review limit left 249 of the 442 PRs with no
  review from it, including 151 of the 243 PRs created after #640 merged.
- Pushes per PR held steady. PRs got a mean of 0.97 pushes after their first
  hosted Claude report before #640, and 0.96 after.
- On `react_on_rails`, CodeRabbit led to a fix on 46% of its threads, Greptile 32%, and
  Claude 25%. Each reviewer found bugs the others did not.
- Local review recorded far more fixes. Local reviewers had 328 defects recorded as
  fixed. Hosted Claude led to 27 fixes of any class, 10 of them code bugs. The two
  counts use different standards.

After #640, hosted Claude asked for no changes. The data does not show local review
as the cause, and CodeRabbit kept asking for changes on GitHub.

## Data and limits

- The PR set is the 442 PRs created in the window. Activity in the window on older
  PRs is left out of the review counts.
- CI counts cover all 4,291 Actions runs created in the window, plus earlier
  attempts of rerun jobs.
- The agent read each hosted Claude finding and the reply to it, then chose the
  class. Nobody checked those classes separately.
- A "code bug" names wrong behavior the code can reach, and a fix commit followed
  it. The class excludes missing `require` lines and defensive changes with no
  reachable failure.
- Before 2026-10-14, hosted reports had no fixed finding count. The total of about
  163 findings comes from 124 inline threads and 39 findings listed only in report
  text.
- CodeRabbit counts come from a second agent, which read all 124 answered threads and
  used the same classes. It judged fixes from the reply text and did not check each
  commit. The two agents spot-checked about 100 of those calls and found none clearly
  wrong. Nobody else rechecked them, and one code bug on #902 spans two threads.
- On 249 PRs, CodeRabbit posted only "Review limit reached" and opened no thread. Its
  counts therefore understate what it would have found.
- The `react_on_rails` counts come from that repository's public PRs created in the
  same window, classed by the same second agent, which left no per-thread reasons. The
  hand counts of separate bugs are approximate.
- Local review counts come from published `Finding details` lines, deduplicated by
  PR, class, and title. Reviewers chose the class, and implementing agents recorded
  the outcome.
- Pushes are distinct commits that ran `Validate` on a PR. They include rebases and
  changes people asked for, so they measure total back-and-forth, not review alone.
- Workflow time is wall-clock time per run, which differs from billed time. This
  report makes no cost claim.

## What CI failed on

| Workflow | Failed attempts | Cause | Attempts | Where |
| --- | ---: | --- | ---: | --- |
| `Validate` on PRs | 42 | The change broke a test or lint | 14 | [#401](https://github.com/shakacode/shaka/pull/401), [#402](https://github.com/shakacode/shaka/pull/402), [#463](https://github.com/shakacode/shaka/pull/463), [#569](https://github.com/shakacode/shaka/pull/569), [#698](https://github.com/shakacode/shaka/pull/698), [#700](https://github.com/shakacode/shaka/pull/700) (4), [#710](https://github.com/shakacode/shaka/pull/710) (2), [#831](https://github.com/shakacode/shaka/pull/831), [#844](https://github.com/shakacode/shaka/pull/844), [#898](https://github.com/shakacode/shaka/pull/898) |
| | | Windows port from a Cursor cloud agent | 9 | 7 PRs, from [#747](https://github.com/shakacode/shaka/pull/747) to [#775](https://github.com/shakacode/shaka/pull/775) |
| | | Flaky test | 9 | 7 PRs |
| | | Dependency bump that needed a paired change | 5 | 5 Dependabot PRs |
| | | Runner image no longer offered Ruby 3.4.6 | 4 | [#853](https://github.com/shakacode/shaka/pull/853) (3), [#854](https://github.com/shakacode/shaka/pull/854) |
| | | Inherited a break from `main` | 1 | [#792](https://github.com/shakacode/shaka/pull/792) |
| `Validate` on `main` | 12 | Flaky test | 6 | 2026-10-15 and 2026-10-16 |
| | | Two merged PRs that failed only together | 5 | 2026-10-11 and 2026-10-22 |
| | | Runner image no longer offered Ruby 3.4.6 | 1 | 2026-10-22 |
| Hosted Claude review | 32 | Claude stopped within half a second with no model usage; the log gives no reason | 14 | 2026-10-05 and 2026-10-22 |
| | | Action produced no review; 10 of the 11 were on PRs editing that workflow | 11 | 7 branches |
| | | Action refused to run for the Cursor bot until [#805](https://github.com/shakacode/shaka/pull/805) | 7 | [#775](https://github.com/shakacode/shaka/pull/775) |
| CodeQL | 2 | Paired Dependabot action bumps ran mismatched versions | 2 | [#534](https://github.com/shakacode/shaka/pull/534), [#535](https://github.com/shakacode/shaka/pull/535) |

- `Validate` on PRs ran 878 times, and 36 runs ended failed (4.1%).
- None of the 32 hosted review failures said anything about the code.
- Cancelled runs are excluded. A new push on a branch cancels its older runs.
- The `Windows` workflow had no failed attempts. Its job continues on error, so a
  green run does not show that the Windows checks passed.

## What hosted Claude review led to

| | Before #640 (16 days) | After #640 (14 days) |
| ---: | ---: | ---: |
| Reports | 344 on 184 PRs | 446 on 234 PRs |
| Findings | about 163 | 0 |
| Code bugs fixed by a push | 10 on 8 PRs | 0 |
| Docs or instruction fixes | 10 on 7 PRs | 0 |
| Cleanups fixed by a push | 7 on 5 PRs | 0 |
| Findings with no push | about 136 | 0 |
| Mean pushes after the first report | 0.97 | 0.96 |
| PRs with no push after the first report | 55% | 58% |

The findings with no push were mostly declined with a reason. Others were already
fixed, or a description update answered them.

The 10 code bugs:

| PR | Bug | Fix |
| --- | --- | --- |
| [#381](https://github.com/shakacode/shaka/pull/381) | `shaka pr watch` still broke for private trials | [`9f014cc`](https://github.com/shakacode/shaka/commit/9f014cc6497a3ba6aa9cba7cf39a2e7bfba6d533) |
| [#398](https://github.com/shakacode/shaka/pull/398) | Review comments showed a collation mapping for solo reviews | [`58eb970`](https://github.com/shakacode/shaka/commit/58eb9709a54738218de02651150fe180155b322d) |
| [#398](https://github.com/shakacode/shaka/pull/398) | Reviewer text reached the visible comment without escaping | [`a217ed5`](https://github.com/shakacode/shaka/commit/a217ed5ab2e66b7b3aa0c6c5848192be97a626c6) |
| [#420](https://github.com/shakacode/shaka/pull/420) | Private settings could disable the checkpoint gate | [`8a2289c`](https://github.com/shakacode/shaka/commit/8a2289cc624637c73900de1bfe5a3c9a7dce6c97) |
| [#462](https://github.com/shakacode/shaka/pull/462) | A valid `ssh://` official origin was classed as custom | [`00e7946`](https://github.com/shakacode/shaka/commit/00e7946921b6ea813e47686f823fe1f2636f6b02) |
| [#463](https://github.com/shakacode/shaka/pull/463) | An `ssh://` origin password could reach the install record | [`a43ad7f`](https://github.com/shakacode/shaka/commit/a43ad7f32d009737ba592059d58846f628eb85cc) |
| [#577](https://github.com/shakacode/shaka/pull/577) | `handoff` could report answered threads as owed for app accounts | [`5b47a4d`](https://github.com/shakacode/shaka/commit/5b47a4d9b6c62607f35c0bed13343640c8ce4584) |
| [#634](https://github.com/shakacode/shaka/pull/634) | Unrelated refusals got an error naming the wrong cause | [`1059594`](https://github.com/shakacode/shaka/commit/1059594476a51a6eaf187184556d17e7a680dfdf) |
| [#634](https://github.com/shakacode/shaka/pull/634) | A maintainer's answered note could be resolved | [`1059594`](https://github.com/shakacode/shaka/commit/1059594476a51a6eaf187184556d17e7a680dfdf) |
| [#642](https://github.com/shakacode/shaka/pull/642) | `repos refresh` could drop a repository without shared settings | [#645](https://github.com/shakacode/shaka/pull/645) |

- [#642](https://github.com/shakacode/shaka/pull/642) merged 30 minutes after the
  report, and its fix went into a new PR. The other 9 fixes were pushes to the open
  PR.
- On [#463](https://github.com/shakacode/shaka/pull/463), `Validate` failed on the
  same head. The agent first dismissed the finding, then found CI used a different
  URI library version.

## The other reviewers on the same PRs

| | Before #640 | After #640 |
| ---: | ---: | ---: |
| PRs CodeRabbit skipped at its review limit, by PR creation date | 98 of 199 | 151 of 243 |
| CodeRabbit threads | 51 | 95 |
| CodeRabbit code bugs fixed | 6 | 23 |
| CodeRabbit docs or instruction fixes | 10 | 23 |
| CodeRabbit cleanups fixed | 4 | 9 |
| CodeRabbit threads declined | 24 | 25 |
| CodeRabbit threads with no reply | 7 | 15 |
| Local review findings | 1,100 | 1,495 |
| Local defects recorded as fixed | 124 | 204 |

Examples of CodeRabbit fixes on commits where hosted Claude reported zero findings:

- [#901](https://github.com/shakacode/shaka/pull/901#discussion_r4382031732):
  a failed canary checkout still ran its checks against the old clone and could
  report a pass.
- [#876](https://github.com/shakacode/shaka/pull/876#discussion_r4369408708):
  a release step could publish a replaced gem after approval.
- [#710](https://github.com/shakacode/shaka/pull/710#discussion_r4331938341):
  a partly failed `rm` left a host without its Shaka link.
- [#827](https://github.com/shakacode/shaka/pull/827#discussion_r4343165577):
  agent instruction files under some paths fell below the automatic-merge floor.

## Three hosted reviewers on `react_on_rails`

Greptile does not run on `shaka`: it appears on none of the 442 PRs. A fair comparison
of the three reviewers therefore needs another repository. `shakacode/react_on_rails`
runs all three, with 128 PRs created in the same window. The review limit left none of
those PRs with only a limit notice.

| Reviewer | Threads | Answered | Led to a fix | Code bugs | Docs | Cleanups | Already fixed | Declined |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| CodeRabbit on `react_on_rails` | 52 | 47 | 24 | 15 | 9 | 0 | 5 | 18 |
| Greptile on `react_on_rails` | 44 | 30 | 14 | 6 | 3 | 5 | 1 | 13 |
| Claude on `react_on_rails` | 182 | 137 | 45 | 23 | 12 | 10 | 9 | 83 |
| CodeRabbit on `shaka` | 146 | 124 | 75 | 29 | 33 | 13 | 0 | 49 |

- Threads led to a fix at these rates on `react_on_rails`: CodeRabbit 46%, Greptile
  32%, and Claude 25%. CodeRabbit on `shaka` reached 51%.
- Claude repeats itself. Its 23 code bug threads hold about 12 separate bugs by hand
  count, and 11 of those threads sit on
  [#5224](https://github.com/shakacode/react_on_rails/pull/5224).
- Each reviewer found bugs the others did not. By hand count, the bugs not also fixed
  from another reviewer's thread are about 12 of 15 for CodeRabbit, 9 of 12 for Claude,
  and 2 of 6 for Greptile.
- Greptile's two are a password left in a URL on
  [#5218](https://github.com/shakacode/react_on_rails/pull/5218) and invalid `--jobs`
  values on [#5262](https://github.com/shakacode/react_on_rails/pull/5262).
- Bugs cluster. [#5262](https://github.com/shakacode/react_on_rails/pull/5262) holds 7
  of CodeRabbit's 15, so one month says little about any single reviewer.
- These counts leave out unanswered threads, findings listed only in summary comments,
  and 98 Codex connector threads on `react_on_rails`. Two answered Greptile threads fit
  no class.

## How much CI time repairs used

| Workflow | Median minutes | Total hours |
| --- | ---: | ---: |
| `Validate` | 7.0 | 150.6 |
| `Windows` | 1.8 | 50.9 |
| Hosted Claude review | 1.1 | 31.3 |
| CodeQL | 1.1 | 30.3 |
| Docs rebuild and canary | 0.2 | 2.0 |
| All workflows | | 265.1 |

- A push costs about 11 minutes of workflow time when every workflow runs.
- The 27 hosted Claude fixes came in 22 commits. At most 22 pushes come to about
  4 hours, or 2% of the total.
- The 14 failures on regular PRs were on 14 distinct commits, and each led to a new
  push. Those pushes come to about 2.6 hours, or 1%.
- Repairs used little of `shaka`'s CI time in this window. The window has
  no period without local review to compare against.

## Findings

### 1. Local review recorded most of the fixed defects

- **Observed:** 328 local defects were recorded as fixed, against 27 hosted Claude
  fixes of any class.
- **Evidence:** the two tables above. Local reviewers ran on 407 of the 442 PRs.
- **Limit:** reviewers class their own local findings, while this report classed the
  hosted ones. Some local fixes came after a PR was public.

### 2. The drop to zero lines up with the prompt change

- **Observed:** the last hosted Claude finding came at 05:07 UTC on 2026-10-18.
  [#640](https://github.com/shakacode/shaka/pull/640) merged at 05:13 UTC. All 446
  later reports found nothing. The workflow runs a full review when it finds no local
  Claude review of that commit. All 96 full reviews found nothing. On 78 of them, the
  commit never got a published local Claude review. Those commits span 39 PRs with a
  median of 503 changed lines.
- **Limit:** the timing does not prove the prompt caused the drop. The two periods
  reviewed different PRs, and earlier commits on those 39 PRs may have had local
  review. The [earlier review study](review-process-study.md) named local review as a
  likely reason for zero-finding reports. These full reviews make the prompt the
  stronger candidate.
- **Evidence:** `react_on_rails` kept a
  [generic Claude review prompt](https://github.com/shakacode/react_on_rails/blob/c5353f46c1a8d9f08e9dfa8f2e0447a85c65d618/.github/workflows/claude-code-review.yml)
  through this window. Claude opened 87 threads there before #640 merged and 95 after.
  Of its 23 fixed code bug threads, 22 came after. Only 8 of its 239 later reports said
  it found no issues.
- **Limit on that evidence:** `react_on_rails` is a different codebase. Its prompt also
  allows findings the `shaka` prompt excludes, and 11 of those bug threads sit on one
  PR.
- **Proposed change:** rerun the current prompt and the old prompt on the 17 commits
  where CodeRabbit later led to a code bug fix. Loosen the current prompt if it misses
  problems its rules include.
- **Guarantee at risk:** a looser prompt brings back nits. Before #640, about 83% of
  findings led to no push.
- **Maintenance:** a prompt edit and one measured rerun.

### 3. CodeRabbit fixes rose while hosted Claude fell to zero

- **Observed:** CodeRabbit fixes rose from 20 to 55, and its code bugs from 6 to 23,
  while hosted Claude fell to zero. CodeRabbit reviewed fewer PRs in the later period,
  92 against 101. Pushes per PR stayed flat.
- **Limit:** the two periods differ in length and PR mix. The counts cannot show that
  one reviewer replaced the other.
- **Proposed change:** for the maintainer to decide. Raising CodeRabbit's review limit
  would cover the 249 PRs it skipped. The price is unknown. A reviewer that finds real
  bugs after local review is worth keeping until a replacement finds the same ones.

### 4. Most CI errors were not defects in the change

- **Observed:** 58 of 88 failed attempts had another cause. Flaky tests caused 15,
  the hosted review job 32, the runner image 5, and merged PRs that failed only
  together 6, counting one PR that inherited the break.
- **Evidence:** the most frequent flaky tests stopped failing after
  [#553](https://github.com/shakacode/shaka/pull/553) merged on 2026-10-16. Pinning
  the runner in [#854](https://github.com/shakacode/shaka/pull/854) ended the Ruby
  failures.
- **Proposed change:** leave hosted review job failures out of counts of failing
  code. The workflow already labels them `Claude review UNAVAILABLE`.
- **Maintenance:** none for the fixes already merged.

### 5. PRs that passed alone still broke `main`

- **Observed:** 5 of 12 `main` failures came from PRs that passed alone and failed
  together. On 2026-10-22,
  [#836](https://github.com/shakacode/shaka/pull/836) and
  [#842](https://github.com/shakacode/shaka/pull/842) broke `main` for 26 minutes
  until [#845](https://github.com/shakacode/shaka/pull/845) merged.
- **Proposed change:** for the maintainer to decide. Requiring an up-to-date branch
  or a merge queue would catch these failures. Each option adds a wait to every
  merge. `Validate` already runs on `merge_group`, so a merge queue needs no workflow
  change.
- **Expected benefit:** about 2 fewer `main` breaks a month, going by this window.

### 6. No hosted reviewer covered the others

- **Observed:** on `react_on_rails`, most CodeRabbit and Claude code bugs were not also
  fixed from another reviewer's thread. Greptile added about 2 bugs the others did not
  lead to.
- **Limit:** one month, one repository, and bugs that cluster on a few PRs. Greptile's
  own analytics were not available to this study.
- **Proposed change:** none yet. Dropping a reviewer needs more months of data than
  this window gives.

## Run the same study on your repository

Shaka has no built-in command for this count. Ask your agent for it as an ordinary
task:

```text
$shaka Count CI failures and hosted review findings that needed a push over the
last 30 days. Read the logs and replies to separate real bugs from nits and flaky
failures.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
