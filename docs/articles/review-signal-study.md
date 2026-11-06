# Are Shaka's review fixes real? A check of 40 findings

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, on 2026-11-06.
The agent checked 40 review findings that Shaka's agents had fixed, using review data
already published on this repository's pull requests (PRs), and drafted the text. No
person has rechecked the verdicts. The
[full report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-signal.md)
lists every finding and how it was checked.*

## Why this ran

Before Shaka pushes a PR, two AI reviewers read every commit: Codex and Claude. Each
finding is a defect, a risk, or a nit. The agent fixes defects and clear risks in new
commits, and both reviewers read the new commit. The loop ends when no fixable finding
remains. Each reviewed commit is one *cycle*.

Two people questioned review loops like this one in recent posts:

- Lauren Tan, who works on pstack, called adversarial reviews
  "mostly a waste of tokens" ([post](https://x.com/poteto/status/2117437607940681849)).
  In a [follow-up](https://x.com/poteto/status/2117445316043825393), she said repeated
  rounds "overcook" a PR.
- Addy Osmani described how the Claude Code team reviews code
  ([post](https://x.com/addyosmani/status/2114604912520921136)). About 59% of what their
  repeated review flagged was code there since the PR's first pass.

Shaka had not checked whether its own fixes were real. An October
[study of review on 350 PRs](review-process-study.md) counted findings by the
disposition the agent recorded, such as `fixed`, without checking that a fixed finding
was real. One PR, [#985](https://github.com/shakacode/shaka/pull/985), ran 41 reviewer
runs. The study below checks whether the fixes were real, and what the repeated cycles
cost.

## Main results

- All 40 sampled fixes, 30 defects and 10 risks, were real problems.
- Every one came from its own PR. None was already in the base branch. One was older
  docs text that the PR's code change made wrong.
- Half were proven by a run. For 20, the fix's own test or a short probe failed on
  the reviewed commit and passed after the fix. The rest, mostly docs and design
  findings, were checked by reading.
- 4 of the 30 defects need an input nobody is likely to produce. One example is a
  directory named like a Markdown link, such as `cache([1](2)`.
- Just over half of fixed defects (54%) are found in the first cycle. Later cycles
  mostly catch bugs in code written during the loop, often by the previous fix.
- Reviewer spend is $2.38 per fixed defect.
- Recommendation: keep the two-reviewer loop as it is.

| Cycle | Fixed defects found | Reviewer spend |
| --- | ---: | ---: |
| 1 | 160 (54%) | $243.52 (33%) |
| 2 | 51 | $167.45 |
| 3 | 35 | $123.21 |
| 4 | 16 | $85.82 |
| 5 | 12 | $48.80 |
| 6 or later | 21 | $59.66 |

The defect counts cover the 295 fixed defects whose cycle is known. Spend covers the
2,310 runs with a cost estimate.

## The ideas, tested

### 1. Adversarial review is mostly a waste of tokens

- **Idea:** Tan argued that tokens spent on review would do more on empirical and formal
  verification. Agents doing abstract review, in her view, get lost in nitpicks.
- **In Shaka:** two reviewers on every commit. A ledger stops after 5 reviewed commits
  unless the maintainer extends it.
- **Result:** the fixes the loop produced were real, and each reviewer found defects the
  other missed. Of 345 fixed defects, Codex alone reported 154, Claude alone 113, and
  both 78. The nitpicking is real too: nits are 49% of all findings, almost all from
  Claude.
- **Limit:** the study checked only findings the agent chose to fix. The 1,221 nits and
  362 dismissed defects and risks were not verified.

### 2. Repeated rounds overcook a PR

- **Idea:** reviewers have no context on the goal, steer the author toward things that
  don't matter, and the author accepts all feedback.
- **In Shaka:** the workflow tells the agent to give every reviewer the task's goal
  file. The agent records a disposition for each finding.
- **Result:** the author agent did not accept everything. The agent dismissed 362
  defects and risks with a reason, 15% of all findings. No sampled fix left the merged change worse.
  Two fixes introduced the next defect, and the following cycle caught each one.
- **Limit:** the data cannot show whether a reviewer read the goal file. Long ledgers did
  chase unlikely inputs. On [#850](https://github.com/shakacode/shaka/pull/850), seven
  findings concerned how one path check reads Markdown links. The two sampled ones need a
  directory name shaped like a link.

### 3. Repeat review mostly re-finds old code

- **Idea:** Osmani's team ran `git blame` on what repeated review flagged. About 59% was
  code there since the first pass. Their review now re-reads only the diff after the
  first cycles and asks the author to rethink after three.
- **In Shaka:** each cycle reviews the whole PR diff against its base.
- **Result:** 17 sampled findings came from cycle 2 or later. 11 sat in code written
  during the loop, and 6 (35%) in code the first cycle had already seen.
- **Limit:** 17 findings is a small sample. A diff-only re-review might still reach some
  of the 6, when a later commit touched nearby lines.

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

## Recommendation

**Keep the two-reviewer loop as it is.** The study compared three options:

| Option | Evidence | Verdict |
| --- | --- | --- |
| Keep the two-reviewer loop as it is | Every sampled fix was real. Each reviewer finds defects the other misses. Reviewer spend is $2.38 per fixed defect. | Recommended |
| Re-review only new commits after the first full round, and label findings already in the base | No sampled fix was already in the base, so the label would mark almost nothing. Diff-only re-review could miss up to about 16% of fixed defects, to save part of the $485 that later cycles cost over three weeks. | Not supported |
| Review less, and spend those tokens on run-based verification | The repository's tests did not cover these inputs. Each regression test came after a reviewer named the input. | Not supported |

Two measurements could change the verdict:

- The implementing agent's cost for each extra cycle, for triage, fixes, and validation,
  is unmeasured. A large cost would make a diff-only trial worthwhile.
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
- **Scope:** one repository, one maintainer, three weeks. Review prompts changed during
  that time.

## Rerun it

The [report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-signal.md)
gives the sampling rule and the 40 findings, so the same data gives the same sample. To
run the study on your own repository, ask your agent:

```text
$shaka Check whether this repository's fixed local review findings were real. Sample
about 30 fixed defects from the published review comments and test each one against
its reviewed commit and fix.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
