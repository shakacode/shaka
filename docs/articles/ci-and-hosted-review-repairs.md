# CI errors and hosted review repairs: shakacode/shaka, 30 days

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-11-01. The maintainer asked how often CI failed and how often the hosted
Claude review found a bug that needed another push. The question tests a claim:
running code reviews locally first removes most back-and-forth with reviews on
GitHub. The agent collected the data, classified each record, and drafted the
text.*

All sources are public GitHub data: Actions runs and logs, PR comments, and
review threads. The window is 2026-10-02 to 2026-10-31 UTC.

## Main results

- CI failed 88 times in 4,291 runs. The change itself caused 14 of those
  failures, on 10 of 442 PRs.
- Hosted Claude review led to 10 code bug fixes on 8 PRs. All 10 came in the
  first 16 days. The review also led to 10 docs or instruction fixes and 7
  cleanups.
- Hosted Claude reported zero findings on all 446 reports after 2026-10-18.
  The count fell to zero when [#640](https://github.com/shakacode/shaka/pull/640)
  changed the review prompt. Local review had been running before and after that
  change.
- Back-and-forth continued. CodeRabbit, another hosted reviewer, led to 49
  fix replies on 26 PRs after 2026-10-18. Hosted Claude had reported zero findings
  on the same commit for 47 of them.
- Pushes per PR held steady. PRs got a mean of 0.97 pushes after their first
  hosted Claude report before #640, and 0.96 after.
- Local review carried the most fixes. Local reviewers had 328 defects recorded
  as fixed, compared with 10 hosted Claude code bugs. The two counts use different
  standards.

The claim holds for hosted Claude alone. The data does not show local review
causing the drop, and it does not show that hosted review stopped asking for
changes.

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
- CodeRabbit counts are a keyword search for "Fixed" in the reply, excluding
  "Declined". The agent read 8 of the Major ones and all 8 were real problems.
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
| CodeQL | 2 | Paired action bumps ran mismatched versions | 2 | [#534](https://github.com/shakacode/shaka/pull/534), [#535](https://github.com/shakacode/shaka/pull/535) |

- `Validate` on PRs ran 878 times, and 36 runs ended failed (4.1%).
- Every head in the "change broke a test" row was followed by a new push.
- None of the 32 hosted review failures said anything about the code.
- Cancelled runs are excluded. A new push on a branch cancels its older runs.

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
| [#398](https://github.com/shakacode/shaka/pull/398) | Review comments showed a collation mapping for solo reviews | [`58eb970`](https://github.com/shakacode/shaka/commit/58eb970) |
| [#398](https://github.com/shakacode/shaka/pull/398) | Reviewer text reached the visible comment without escaping | [`a217ed5`](https://github.com/shakacode/shaka/commit/a217ed5) |
| [#420](https://github.com/shakacode/shaka/pull/420) | Private settings could disable the checkpoint gate | [`8a2289c`](https://github.com/shakacode/shaka/commit/8a2289cc) |
| [#462](https://github.com/shakacode/shaka/pull/462) | A valid `ssh://` official origin was classed as custom | [`00e7946`](https://github.com/shakacode/shaka/commit/00e79469) |
| [#463](https://github.com/shakacode/shaka/pull/463) | An `ssh://` origin password could reach the install record | [`a43ad7f`](https://github.com/shakacode/shaka/commit/a43ad7f32d009737ba592059d58846f628eb85cc) |
| [#577](https://github.com/shakacode/shaka/pull/577) | `handoff` could report answered threads as owed for app accounts | [`5b47a4d`](https://github.com/shakacode/shaka/commit/5b47a4d9) |
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
| CodeRabbit threads | 51 | 95 |
| CodeRabbit threads with a fix reply | 17 | 49 |
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
- The 27 pushes after hosted Claude findings come to about 5 hours, or 2% of the
  total.
- The 14 pushes after change-caused CI failures come to about 2.6 hours, or 1%.
- Repairs used little of this repository's CI time in this window. The window has
  no period without local review to compare against.

## Findings

### 1. Local review finds most defects first

- **Observed:** 328 local defects were recorded as fixed, against 10 hosted Claude
  code bugs.
- **Evidence:** the two tables above. Local reviewers ran on 407 of the 442 PRs.
- **Limit:** reviewers class their own local findings, while this report classed the
  hosted ones. Some local fixes came after a PR was public.

### 2. The prompt change explains the drop to zero

- **Observed:** the last hosted Claude finding came at 05:07 UTC on 2026-10-18.
  [#640](https://github.com/shakacode/shaka/pull/640) merged at 05:13 UTC. All 446
  later reports found nothing, including 96 full reviews where no local Claude
  review had run.
- **Proposed change:** rerun the current prompt on the 47 commits above, then loosen
  it if it misses problems its rules include.
- **Guarantee at risk:** a looser prompt brings back nits. Before #640, about 83% of
  findings led to no push.
- **Maintenance:** a prompt edit and one measured rerun.

### 3. Hosted review back-and-forth moved to CodeRabbit

- **Observed:** CodeRabbit fix replies rose from 17 to 49 while hosted Claude fell to
  zero. Pushes per PR stayed flat.
- **Limit:** the two periods differ in length, PR mix, and CodeRabbit settings. The
  counts cannot show that one reviewer replaced the other.
- **Proposed change:** none yet. A reviewer that finds real bugs after local review
  is worth keeping until a replacement finds the same ones.

### 4. Most CI errors were not defects in the change

- **Observed:** 14 of 88 failed attempts came from a change breaking a test or lint.
  Flaky tests caused 15, and 32 came from the hosted review job itself.
- **Evidence:** the most frequent flaky tests stopped failing after
  [#553](https://github.com/shakacode/shaka/pull/553) merged on 2026-10-16. Pinning
  the runner in [#854](https://github.com/shakacode/shaka/pull/854) ended the Ruby
  failures.
- **Proposed change:** report a hosted review job failure as "review unavailable"
  and keep it out of counts of failing code.
- **Maintenance:** none for the fixes already merged.

### 5. PRs that passed alone still broke `main`

- **Observed:** 5 of 12 `main` failures came from PRs that passed alone and failed
  together. On 2026-10-22,
  [#836](https://github.com/shakacode/shaka/pull/836) and
  [#842](https://github.com/shakacode/shaka/pull/842) broke `main` for 26 minutes
  until [#845](https://github.com/shakacode/shaka/pull/845) merged.
- **Proposed change:** for the maintainer to decide. Requiring an up-to-date branch
  or a merge queue would catch these failures. Each option adds a wait to every
  merge.
- **Expected benefit:** about 2 fewer `main` breaks a month, going by this window.

## Run the same study on your repository

Shaka has no built-in command for this count. Ask your agent for it as an ordinary
task:

```text
/shaka Count CI failures and hosted review findings that needed a push over the
last 30 days. Read the logs and replies to separate real bugs from nits and flaky
failures.
```

In Codex, start the prompt with `$shaka` instead of `/shaka`.
