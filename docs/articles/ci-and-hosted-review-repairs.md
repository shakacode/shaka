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

- CI had 88 failed attempts. The window held 4,291 Actions runs, counting cancelled and
  skipped ones. The change on the branch caused 30 of those
  failures: 14 on 10 regular PRs, 9 on a Windows port, and 7 on Dependabot bumps.
  Flaky tests caused 15, and the hosted review job itself failed 32 times.
- Hosted Claude review led to 10 code bug fixes on 8 PRs. All 10 came in the
  first 16 days. The review also led to 10 docs or instruction fixes and 7
  cleanups.
- Hosted Claude findings fell in two steps. [#446](https://github.com/shakacode/shaka/pull/446) bumped the review action on
  2026-10-11, and the logged model changed from `claude-sonnet-5` to
  `claude-sonnet-5-5`. Findings per report fell from 0.80 to 0.21. Then
  [#640](https://github.com/shakacode/shaka/pull/640) changed the prompt on 2026-10-18,
  and all 446 later reports found nothing. Local review was running throughout.
- Back-and-forth continued. CodeRabbit, another hosted reviewer, led to 55 fixes on
  30 PRs after #640 merged, including 23 code bug threads. Hosted Claude had reported
  zero findings on the same commit for 21 of those 23 code bug threads, across 17
  commits. The strict prompt excludes many docs and cleanup findings by design.
- CodeRabbit's counts run low. Its free review limit left 249 of the 442 PRs with no
  review from it, including 151 of the 243 PRs created after #640 merged.
- Pushes per PR did not follow findings to zero. PRs got a mean of 1.33 pushes after
  their first hosted Claude report before #446, 0.74 from #446 to #640, and 0.96 after
  #640.
- On `react_on_rails`, CodeRabbit led to a fix on 46% of its threads, Greptile 34%, and
  Claude 25%. Claude there kept the older model and a generic prompt. Each reviewer found bugs the others did not.
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
  same window, classed by the same second agent, which left no per-thread reasons. Review
  of this article corrected one of its calls, a Greptile thread declined and then fixed.
  The hand counts of separate bugs are approximate.
- Local review counts come from published `Finding details` lines, deduplicated by
  PR, class, and title. Reviewers chose the class, and implementing agents recorded
  the outcome.
- Pushes are distinct commits that ran `Validate` on a PR. They include rebases and
  changes people asked for, so they measure total back-and-forth, not review alone.
- Model names and turn counts come from job logs: 7 sampled runs before #446, 7 from
  #446 to #640, 8 after #640, and 12 on `react_on_rails`. The other runs were not read.
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

| | Before #446 (10 days) | #446 to #640 (6 days) | After #640 (14 days) |
| ---: | ---: | ---: | ---: |
| Logged model | `claude-sonnet-5` | `claude-sonnet-5-5` | `claude-sonnet-5-5` |
| Prompt | Generic | Generic | Strict |
| Turns per review, sampled | 22 to 59 | 5 to 11 | 3 to 9 |
| Reports | 152 on 73 PRs | 192 on 117 PRs | 446 on 234 PRs |
| Findings | about 122 | about 41 | 0 |
| Findings per report | 0.80 | 0.21 | 0 |
| Inline threads | 119 | 5 | 0 |
| Code bugs fixed by a push | 6 on 5 PRs | 4 on 3 PRs | 0 |
| Docs or instruction fixes | 4 on 4 PRs | 6 on 3 PRs | 0 |
| Cleanups fixed by a push | 6 on 4 PRs | 1 on 1 PR | 0 |
| Findings with no push | about 106 | about 30 | 0 |
| Mean pushes after the first report | 1.33 | 0.74 | 0.96 |
| PRs with no push after the first report | 45% | 61% | 58% |

The generic prompt asks for code quality, bugs, security, and performance. The strict
prompt flags only code that fails to run, wrong results in a named state, and quoted
rule violations. It also skips the rule audit and makes a short pass when a local Claude
review of that commit exists. A full review is the run without that short pass.

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

Thread and fix rows split by when the thread opened.

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
those PRs with only a limit notice. The Claude row uses `claude-sonnet-5` and a generic
prompt, so it does not describe the model or prompt reviewing `shaka` now.

| Reviewer | Threads | Answered | Led to a fix | Code bugs | Docs | Cleanups | Already fixed | Declined |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| CodeRabbit on `react_on_rails` | 52 | 47 | 24 | 15 | 9 | 0 | 5 | 18 |
| Greptile on `react_on_rails` | 44 | 30 | 15 | 7 | 3 | 5 | 1 | 12 |
| Claude on `react_on_rails` | 182 | 137 | 45 | 23 | 12 | 10 | 9 | 83 |
| CodeRabbit on `shaka` | 146 | 124 | 75 | 29 | 33 | 13 | 0 | 49 |

- Of all threads, including unanswered ones, these shares led to a fix on
  `react_on_rails`: CodeRabbit 46%, Greptile 34%, and Claude 25%. CodeRabbit on `shaka`
  reached 51%.
- Claude repeats itself. Its 23 code bug threads hold about 12 separate bugs by hand
  count, and 11 of those threads sit on
  [#5224](https://github.com/shakacode/react_on_rails/pull/5224).
- Each reviewer found bugs the others did not. By hand count, these were not also fixed
  from another reviewer's thread: about 12 of CodeRabbit's 15 threads, 9 of Claude's 12
  separate bugs, and 3 of Greptile's 7 threads.
- Greptile's three are a password left in a URL on
  [#5218](https://github.com/shakacode/react_on_rails/pull/5218), plus invalid `--jobs`
  values and ignored npm version pins on
  [#5262](https://github.com/shakacode/react_on_rails/pull/5262).
- Bugs cluster. [#5262](https://github.com/shakacode/react_on_rails/pull/5262) holds 7
  of CodeRabbit's 15, so one month says little about any single reviewer.
- The class columns cover answered threads only. Two answered Greptile threads fit no
  class. Findings listed only in summary comments and 98 Codex connector threads on
  `react_on_rails` are not counted.

## How much CI time repairs used

| Workflow | Median minutes | Total hours |
| --- | ---: | ---: |
| `Validate` | 7.0 | 150.6 |
| `Windows` | 1.8 | 50.9 |
| Hosted Claude review | 1.1 | 31.3 |
| CodeQL | 1.1 | 30.3 |
| Docs rebuild and canary | 0.2 | 2.0 |
| All workflows | | 265.1 |

- A push uses about 11 minutes of workflow time, at median run times, when every
  workflow runs.
- The 27 hosted Claude fixes came in 22 commits. Measured runs on the 14 of those
  commits that were pushed as a PR head add up to 3.1 hours, about 1% of the total. The
  others landed inside a later push or could not be traced to a run.
- The 14 failures on regular PRs were on 14 distinct commits, and each led to a new
  push. Measured runs on those next heads add up to 2.4 hours, about 1%.
- Repairs used little of `shaka`'s CI time in this window. The window has
  no period without local review to compare against.

## Findings

### 1. Local review recorded most of the fixed defects

- **Observed:** 328 local defects were recorded as fixed, against 27 hosted Claude
  fixes of any class.
- **Evidence:** the two tables above. Local reviewers ran on 407 of the 442 PRs.
- **Limit:** reviewers class their own local findings, while this report classed the
  hosted ones. Some local fixes came after a PR was public.

### 2. Findings fell in two steps: a model change, then a prompt change

- **Observed, first step:** [#446](https://github.com/shakacode/shaka/pull/446) bumped `claude-code-action` from 1.0.235 to 1.0.241
  on 2026-10-11 and left the prompt alone. All 7 sampled runs before it logged
  `claude-sonnet-5`, and all 7 sampled runs from it to #640 logged `claude-sonnet-5-5`.
  Findings per report fell from 0.80 to 0.21. Fixed code bugs fell less, from 3.9 to 2.1
  per 100 reports, so the drop was mostly in findings that led to no change.
- **Observed, second step:** the last hosted Claude finding came at 05:07 UTC on
  2026-10-18. [#640](https://github.com/shakacode/shaka/pull/640) merged at 05:13 UTC.
  Sampled runs at 11:30 UTC on 2026-10-17 and 05:50 UTC on 2026-10-18 logged the same
  action commit and model. All 446 later reports found nothing. The workflow runs a full review when it finds no local
  Claude review of that commit. All 96 full reviews found nothing. On 78 of them, the
  commit never got a published local Claude review. Those commits span 39 PRs with a
  median of 503 changed lines. The other 18 got one the job did not find when it ran.
- **Action timeline:** later bumps reached 1.0.248 on 2026-10-15, 1.0.250 at 09:45 UTC
  on 2026-10-17, 1.0.252 on 2026-10-21, and 1.0.262 on 2026-10-29. A sampled run after
  the last bump still logged `claude-sonnet-5-5`.
- **Counting method:** [#507](https://github.com/shakacode/shaka/pull/507) added a
  self-reported finding count to each report on 2026-10-14. It changed the report
  format and left the review instructions alone. Splitting the middle period there
  gives 0.14 findings per report by hand count, then 0.25 by self-report. The drop from
  0.80 therefore appears before the counting method changed.
- **Limit:** the timing does not prove either change caused its step. Each period
  reviewed different PRs, and earlier commits on those 39 PRs may have had local
  review. The action bump may also have changed more than the default model. The
  [earlier review study](review-process-study.md) named local review as a likely reason
  for zero-finding reports. Local review ran through all three periods, so it does not
  explain either step by itself.
- **Why `react_on_rails` cannot separate them:** it kept a
  [generic Claude review prompt](https://github.com/shakacode/react_on_rails/blob/c5353f46c1a8d9f08e9dfa8f2e0447a85c65d618/.github/workflows/claude-code-review.yml)
  through this window, and all 12 sampled runs there logged `claude-sonnet-5`. Claude
  opened 87 threads there before #640 merged and 95 after. Only 8 of its 239 later
  reports said it found no issues. Those counts fit an effect from the prompt or the
  model. `react_on_rails` is also a different codebase, and 11 of its bug threads sit on
  one PR.
- **Proposed change:** take the 17 commits where hosted Claude reported zero findings
  and CodeRabbit later led to a code bug fix. Rerun both prompts under both models. Change the prompt or pin the model only if the
  rerun shows which one loses bugs its rules include.
- **Guarantee at risk:** more findings bring back nits. About 87% of findings before
  #446 led to no push, and about 73% from #446 to #640.
- **Maintenance:** a prompt edit or a model pin, plus one measured rerun.

### 3. CodeRabbit fixes rose while hosted Claude fell to zero

- **Observed:** CodeRabbit fixes rose from 20 to 55, and its code bugs from 6 to 23,
  while hosted Claude fell to zero, counting threads by when they opened. CodeRabbit
  reviewed fewer PRs created in the later period, 92 against 101. Pushes per PR after the first hosted report did not fall to zero with
  hosted findings.
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
- **Proposed change:** none for the workflow, which already labels these failures
  `Claude review UNAVAILABLE`. A later count of failing code should leave them out.
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
  fixed from another reviewer's thread. Greptile added about 3 bugs the others did not
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
