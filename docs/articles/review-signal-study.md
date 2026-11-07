# What AI code review is worth: 70 checked fixes from two repositories

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, on 2026-11-06.
The agent checked 70 review findings that Shaka's agents had fixed, 40 on this
repository and 30 on React on Rails, using review data already published on their pull
requests (PRs), and drafted the text. No person has rechecked the verdicts. The
[Shaka report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-signal.md)
and the
[React on Rails report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-signal-react-on-rails.md)
list every finding and how it was checked.*

## Conclusions

1. **AI review finds real problems, mostly in code the tests had not covered.** All 70
   sampled fixes were real problems, and almost every one was introduced by its own PR.
   49 changed code, and 48 of those added or changed a test. On Shaka, 16 of the 30
   sampled defects were confirmed by running the fix's test or a probe on the reviewed
   commit. The React on Rails verdicts are readings only, because no test could run there.
2. **Being right is not enough. Much of what reviewers say is optional or wrong.** Nits
   are 49% of findings on Shaka and 56% on React on Rails. The agent dismissed 29% and 39% of
   defects and risks, and declined 61% of the threads that
   outside reviewers opened on commits both local reviewers had passed.
   Reading and answering all of that costs time this study did not price.
3. **The first round does most of the work. Later rounds mostly chase the loop's own
   fixes.** 58% and 50% of fixed defects were first reported in cycle 1. Most later
   findings sat in code an earlier fix had written: 11 of 17 sampled later-cycle findings
   on Shaka, and at least 9 of the 14 sampled findings last recorded in cycle 2 or later
   on React on Rails. The two studies measure the cycle differently. The longest
   chains came from one routine each, a path check on
   [#850](https://github.com/shakacode/shaka/pull/850) and a URL redactor on
   [#5218](https://github.com/shakacode/react_on_rails/pull/5218), where each fix exposed
   the next edge case.
4. **More reviewers keep finding real problems, but most of what the extra ones raise is
   declined.** Codex and Claude each catch defects the other misses. On React on Rails
   commits both had passed, four more AI reviewers on GitHub still led to 11 problems
   fixed on the PR and 3 elsewhere, on 7 of the 31 PRs they commented on. One was a bug
   that stopped Turbo Frame components from mounting. 9 of the 12 threads behind the
   on-PR fixes are timestamped after the local sign-off. The agent declined 39 of the 64
   threads those reviewers opened.
5. **Review cost about twice as much per real problem on React on Rails.** Reviewer spend
   was $5.72 per fixed defect against $2.38 on Shaka, and $2.05 per fixed defect or risk
   against $1.00, with the same two reviewers. Both reviewers' runs cost about 1.6 times
   as much there, and React on Rails labels more fixes as risks. The data cannot say which
   difference drove the gap.
   Measure your own repository before arguing that review is or is not worth it.
6. **This data cannot settle the larger questions.** It cannot show whether the same
   tokens would do more as run-based verification, how AI review compares with a human
   reviewer, how precise the unfixed findings were, or what each extra cycle costs the
   agent doing the fixes.

## Why this ran

Before Shaka pushes a PR, an AI reviewer reads every commit. Shaka's default is one
reviewer; this repository configures two, Codex and Claude. Each finding is a defect, a
risk, or a nit. The agent fixes defects and clear risks in new
commits, and both reviewers read the new commit. The loop ends when no fixable finding
remains. Each reviewed commit is one *cycle*.

Two people questioned review loops like this one in recent posts:

- Lauren Tan, who works on pstack, called adversarial reviews
  "mostly a waste of tokens" ([post](https://x.com/poteto/status/2117437607940681849)).
  A [follow-up post](https://x.com/poteto/status/2117445316043825393) says repeated
  rounds "overcook" a PR.
- Addy Osmani described how the Claude Code team reviews code
  ([post](https://x.com/addyosmani/status/2114604912520921136)). About 59% of what their
  repeated review flagged was code there since the PR's first pass.

Shaka had not checked whether its own fixes were real. An October
[study of review on 350 PRs](review-process-study.md) counted findings by the
disposition the agent recorded, such as `fixed`. One PR, [#985](https://github.com/shakacode/shaka/pull/985), ran 41 reviewer
runs. The study below checks whether the fixes were real, and what the repeated cycles
cost.

## Main results

- All 40 sampled fixes, 30 defects and 10 risks, were real problems.
- Every one came from its own PR. None was already in the base branch. One was older
  docs text that the PR's code change made wrong.
- Half were proven by a run. For 19, the fix's own test or a short probe failed on
  the reviewed commit and passed after the fix. One more probe reproduced the failure on
  the reviewed commit. The rest, mostly docs and design
  findings, were checked by reading.
- 4 of the 30 defects need an input nobody is likely to produce. One example is a
  directory whose name looks like a Markdown link.
- 58% of fixed defects with a known first cycle were first reported in cycle 1. In the sample, later
  cycles mostly caught bugs in code written during the loop, often by the previous fix.
- Reviewer spend is $2.38 per fixed defect, across the 443 ledgers with a cost on every
  run.
- Recommendation: keep the two-reviewer loop as it is.

| Cycle | Fixed defects first reported | Reviewer spend |
| --- | ---: | ---: |
| 1 | 159 (58%) | $243.52 (33%) |
| 2 | 42 | $167.45 |
| 3 | 27 | $123.21 |
| 4 | 16 | $85.82 |
| 5 | 13 | $48.80 |
| 6 or later | 17 | $59.66 |

The defect counts cover the 274 fixed defects whose first cycle is known. Spend covers
the 2,310 runs with a cost estimate.

## The ideas, tested

### 1. Adversarial review is mostly a waste of tokens

- **Idea:** Tan argued that tokens spent on review would do more on empirical and formal
  verification. Agents doing abstract review get lost in nitpicks, Tan wrote.
- **In this repository:** two reviewers on every commit. A ledger stops after 5
  reviewed commits unless the maintainer extends it.
- **Result:** the fixes the loop produced were real, and each reviewer reported defects
  the other did not. Of 345 fixed defects, Codex alone reported 154,
  Claude alone 113, and both 78. Whether either would have found the rest in a later
  cycle is unknown. The nitpicking is real too: nits are 49% of all findings, almost all from
  Claude.
- **Limit:** the study checked only findings the agent chose to fix. The 1,221 nits and
  362 dismissed defects and risks were not verified.

### 2. Repeated rounds overcook a PR

- **Idea:** reviewers have no context on the goal, steer the author toward things that
  don't matter, and the author accepts all feedback.
- **In Shaka:** the workflow tells the agent to give every reviewer the task's goal
  file. The agent records a disposition for each finding.
- **Result:** the author agent did not accept everything. The agent dismissed 362
  defects and risks with a reason, 15% of all findings. None of the 40 sampled fixes was
  undone or reported again after it landed, apart from a few chains in which a fix left
  or caused the next defect. The study did not compare merged PRs with their versions
  before review.
  Two fixes introduced the next defect, and the following cycle caught each one.
- **Limit:** the data cannot show whether a reviewer read the goal file. Long ledgers did
  chase unlikely inputs. On [#850](https://github.com/shakacode/shaka/pull/850), seven
  findings concerned how one path check reads Markdown links. The two sampled ones need a
  directory name shaped like a link.

### 3. Repeat review mostly re-finds old code

- **Idea:** the team in Osmani's post ran `git blame` on what repeated review flagged. About 59% was
  code there since the first pass. Their review now re-reads only the diff after the
  first cycles and asks the author to rethink after three.
- **In Shaka:** each cycle reviews the whole PR diff against its base.
- **Result:** 17 sampled findings were first reported in cycle 2 or later. 11 sat in
  code written during the loop, and 6 (35%) in code the first cycle had already seen.
- **Limit:** 17 findings is a small sample, drawn by reporter rather than by cycle, so
  35% is not a population rate. A diff-only re-review might still reach some of the 6,
  when a later commit touched nearby lines.

### 4. Only findings proven by a run should survive

- **Idea:** pstack's
  [interrogate skill](https://github.com/cursor/plugins/blob/ab1f702ce8/pstack/skills/interrogate/SKILL.md)
  keeps a finding only when the adversary proves it with a run, such as a failing test.
- **In Shaka:** reviewers cannot run tests. The agent that fixes a finding usually adds a
  regression test.
- **Result:** no reviewer proved a finding with a run. For 18 sampled fixes, the fix's
  own test failed on the reviewed commit and passed after the fix. The repository's tests
  had not covered those inputs before a reviewer named them.
- **Limit:** a run shows the code behaved as the finding said. A run cannot show how
  often users would reach that input.

## A second repository: React on Rails

Shaka's reviewers might suit Shaka's own code unusually well, so the same check ran on
[React on Rails](https://github.com/shakacode/react_on_rails), a public gem and npm
packages with outside users. Its PRs go through the same two-reviewer loop. After the
push, four more AI reviewers comment on GitHub: Claude in CI, CodeRabbit, the Codex
connector, and Greptile. The
[React on Rails report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-signal-react-on-rails.md)
lists every finding.

- All 30 sampled fixed defects read as real, and 3 need an
  unlikely input. Two were checked against the reviewed code; the other 28 rest on the
  finding and the fix diff. Every check was a reading: the agent's host refused to run another
  repository's code, so none was confirmed by a run.
- The loop costs more per fixed defect there. Reviewer spend is $5.72 per fixed defect,
  against $2.38 on Shaka. Codex reported nothing on 84% of its runs. Claude reported 316 of
  the 318 nits and 80 of the 83 fixed risks.
- Fixes chain the same way. At least 9 of the 14 sampled findings last recorded in
  cycle 2 or later sat in code an earlier fix had rewritten. Three of those came from one
  URL-redaction routine.
- More reviewers found more problems, and the agent declined most of what they raised.
  On 31 PRs, outside reviewers, plus GitHub code scanning, left 66 threads on a commit
  both local reviewers had passed. 50 of them came after the local sign-off by timestamp.
  The agent fixed 11 distinct problems on 7 of those PRs and 3 more in other PRs. It
  declined 40 threads with a reason, and 9 got no reply. On 7 more PRs only one local
  reviewer ran on the final commit; outside threads there led to 8 more fixes.

| Measure | Shaka | React on Rails |
| --- | ---: | ---: |
| Sampled fixed defects that were real | 30 of 30 | 30 of 30 |
| Confirmed by a run | 16 of 30 | 0 of 30 |
| Fixed defects first reported in cycle 1, of those with a known first cycle | 159 of 274 (58%) | 14 of 28 (50%) |
| Reviewer spend per fixed defect | $2.38 | $5.72 |
| Nits, share of findings | 49% | 56% |

The data has no independent human review: both maintainers' accounts post agent-written
replies here. It cannot say whether a person would have caught what the outside reviewers
did.

## Recommendation

**On Shaka's own repository, keep the two-reviewer loop as it is.** React on Rails pays
about twice as much per fixed defect or risk, so this verdict does not carry over to it
unchanged.
The Shaka study compared three options:

| Option | Evidence | Verdict |
| --- | --- | --- |
| Keep the two-reviewer loop as it is | Every sampled fix was real. Each reviewer reports defects the other did not. Reviewer spend is $2.38 per fixed defect. | Recommended |
| Re-review only new commits after the first full round, and label findings already in the base | Base findings are rare: no sampled fix, 1 of 15 sampled dismissals, and 0 of 10 sampled findings the maintainer accepted or has yet to decide. Diff-only re-review could miss defects like 4 of the 13 later-cycle sampled defects, to save part of the $485 that later cycles cost over three weeks. | Not shown to help |
| Review less, and spend those tokens on run-based verification | The sample holds only findings a reviewer named, so it cannot show what a run-proving adversary would find. The repository's tests had not covered these inputs. | Not tested by this data |

Two measurements could change the verdict:

- The implementing agent's cost for each extra cycle, for triage, fixes, and validation,
  is unmeasured. A large cost would make a diff-only trial worthwhile. A
  [preregistered comparison](https://github.com/shakacode/shaka/blob/main/eval/reports/review-scope-preregistration.md)
  designs that trial; its paid pilot awaits the maintainer's approval.
- Claude's nits are the largest share of findings that change nothing. The
  [October study](review-process-study.md#1-the-local-claude-reviewer-is-noisy-but-it-carries-most-of-the-fixes)
  already proposed capping them, a change outside these three options.

## Data and limits

- **Data:** Shaka's published review comments from 2026-10-15 to 2026-11-05: 500
  ledgers on 339 PRs, 2,574 reviewer runs, and 2,486 findings.
- **Sample:** 10 fixed defects reported only by Codex, 10 only by Claude, 10 by both, and
  10 fixed risks. Each group was sorted by a hash of the PR, finding ID, and title, and the
  first entries were taken. The rule was written down before any report was read.
- **Checking:** one agent, Claude Opus 5.5, judged every finding. Claude Opus 5.5 shares
  a model family with one of the reviewers. The 20 run checks do not depend on that judgment; the 20
  readings do.
- **Cost:** the review comments' own estimates, for reviewers only. 264 runs have none.
  The implementing agent's tokens and time are not included.
- **Scope:** for the Shaka study, one repository, one maintainer, three weeks. Review prompts changed during
  that time.

## Rerun it

The [report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-signal.md)
gives the sampling rule and the 40 findings with their commits, so each check can be
rerun. The comment snapshot is not published, and a fresh download may differ. To
run the study on your own repository, ask your agent:

```text
$shaka Check whether this repository's fixed local review findings were real. Sample
about 30 fixed defects from the published review comments and test each one against
its reviewed commit and fix.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
