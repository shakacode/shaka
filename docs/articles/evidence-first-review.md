# Review the evidence, not the code? A talk tested against Shaka

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, on 2026-11-15.
The maintainer asked it to evaluate Lauren Tan's talk and its advice to review
verification evidence instead of code. The agent read the talk's transcript, compared
each idea with Shaka's documentation and earlier studies, and drafted the text. No new
experiment ran. No person has rechecked the comparison.*

Lauren Tan's AI Engineer talk,
[All Code Is Slop (Except Mine)](https://www.youtube.com/watch?v=O_zcc6Xl12g)
([post](https://x.com/poteto/status/2121673563489140863)), describes how the Grok bot
team at SpaceXSI ships agent-written pull requests (PRs) at high volume. Timestamps
below point into the video.

## Conclusions

1. **Evidence review comes last in the talk, after the code is constrained.** Tan
   turns each correction into a lint rule, an architecture boundary, or a test. Code
   review then has less to look for. Only then does review shrink to screenshots,
   videos, diagrams, and formal checks (9:10 to 10:00). Skipping the first step would
   speed up approval of the same code.
2. **Shaka already leads with evidence.** A Shaka PR puts its summary, risk, and
   verification results above the code links. Shaka's commands record which commit the validation and review results
   cover. The agent is asked to add screenshots and speed comparisons when they apply.
   A checkpoint grades whether the evidence is adequate.
3. **Shaka's data does not support dropping AI code review yet.** In an earlier Shaka
   study, AI review often found inputs the tests had missed. Review was producing
   missing verification, which fits the talk's goal. The study did not measure human
   review.
4. **Shaka's own rules sit mostly at the top of Tan's pyramid.** In the current
   enforcement audit, 89 of 100 workflow rules depend on the agent following prose.
5. **The talk's quality number is weak evidence.** A 0.5% revert rate counts rolled-back
   changes. Bugs fixed by a later PR do not appear in it.

## Why this ran

- Tan's post linking the talk had about 451,000 views on the day it went up.
- pstack, her skill pack, already works alongside Shaka
  ([Use pstack with Shaka](../pstack.md)).
- An earlier Shaka study tested her claim that adversarial review mostly wastes tokens
  ([What AI code review is worth](review-signal-study.md)). The talk goes further: most
  product code no longer needs deep human review (16:44).
- Shaka asks maintainers to judge PRs from an evidence packet
  ([Review the PR](../pr-verification.md)). The maintainer wanted to know where Shaka
  stands relative to the talk.

## What the talk says

- **A trust pyramid (2:03).** The base is code-level constraints: API design,
  architecture, lint rules, types, and tests. Above that comes runtime and formal
  verification. Prose sits at the narrow top: rules, skills, and AGENTS.md files.
- **Corrections become checks (3:08, 9:10).** Tan turns each correction of an agent
  into a deterministic check where possible. A line of instructions is the last resort.
- **Examples from their framework, Dune.** Product code cannot use React's `useEffect`.
  Lint rules forbid imports between the Electron main and renderer directories. About
  99% of code comments are banned, because agents used comments to justify workarounds.
- **Review shifts to artifacts (9:48).** Agents run the app themselves using a "feature
  map" of what users can do. Reviewers look at videos, screenshots, diagrams, TLA+ model
  checks, and Lean proofs. Tan built pstack's
  [statechart skill](https://github.com/cursor/plugins/blob/bf0c7cd80a/pstack/skills/statechart/SKILL.md)
  to make state machines easier to review (13:01).
- **Most tokens go to verification (12:13).** Tan cites another engineer who spends 70%
  of daily tokens on verification and says her own usage looks similar.
- **Results (13:32 to 14:30).** Tan shipped about 3,000 PRs in one month. The team
  shipped 11,000 in a month, with 227 contributors in October. About 0.5% of PRs get
  reverted. The app's startup and chat switching got faster.
- **Foundations before automation (15:11).** A loop that produces slop produces more
  slop when automated. Fix the codebase first.

## How strong the talk's numbers are

- **Revert rate is not a defect rate.** A team that fixes forward can keep reverts low
  while bugs rise. The talk gives no count of escaped bugs or incidents.
- **PR counts depend on PR size.** The talk does not say how large the PRs were.
- **One team, favorable conditions.** The team controls its own framework, and an
  Electron UI is easy to capture on video. Tan says the setup took six months. How
  well the approach carries to other teams is unknown.
- **No method for checking coverage.** The talk does not explain how a reviewer
  confirms that the artifacts cover the change. Shaka's earlier study suggests coverage
  is where review found its defects.

## The ideas, tested

### 1. Turn each correction into a deterministic check

- **Idea:** encode a lesson as a lint rule, type, test, or script. pstack states the same
  rule in its
  [encode-lessons-in-structure skill](https://github.com/cursor/plugins/blob/bf0c7cd80a/pstack/skills/principle-encode-lessons-in-structure/SKILL.md).
- **In Shaka:** the repository's agent instructions already ask for deterministic
  parsing, state changes, and evidence checks in small Ruby modules with tests.
  `shaka enforcement` prints which workflow rules any code enforces
  ([what is enforced](../workflow.md#what-is-enforced)).
- **Result:** the audit lists 100 workflow rules. Shaka commands refuse 8 and report 2.
  GitHub settings refuse 1. The other 89 depend on the agent.
- **Limit:** many of those 89 rules need judgment, such as whether a paraphrase leaks
  private facts. No code could enforce them. The audit counts rules in Shaka's own
  workflow. It says nothing about the projects Shaka delivers to, where Tan's advice
  applies to the user's codebase.

### 2. Review the evidence instead of the code

- **Idea:** once the code is constrained, reviewers look at verification artifacts.
- **In Shaka:** the PR description puts Summary, Risk, and Verification first. Code
  Review and the Code Walkthrough are links for closer reading. The agent is asked to
  capture before-and-after screenshots for visible changes
  ([visual evidence](../reference/pr-record.md#visual-evidence)). The agent is also asked
  to compare speed for a speed claim
  ([performance](../reference/pr-record.md#performance-and-blocked-work)). The checkpoint
  grades verification as adequate, inadequate, or cannot judge
  ([checkpoint](../reference/pr-record.md#checkpoint)). Under `auto`, an inadequate or
  cannot-judge grade stops the merge until the maintainer approves that commit.
- **Result:** Shaka's commands record which commit the validation and review results
  cover. The merge command checks that a review covers the commit being merged. Nothing
  checks that a screenshot shows that commit. The talk does not say how its team checks
  that either. Shaka also keeps two AI code reviewers on every commit of this
  repository.
- **Limit:** Shaka cannot make a user's codebase safe for evidence-only review. The
  base of the pyramid belongs to each project.

### 3. Review mostly finds missing verification

- **Idea:** Tan argued earlier that review tokens would do more as runtime and formal
  verification.
- **In Shaka:** the review-signal study checked 70 fixed review findings across Shaka
  and React on Rails.
- **Result:** all 70 were real problems. On Shaka, the fix's own test failed on the
  reviewed commit for 18 sampled fixes and passed after the fix. On React on Rails, 23
  of 30 behaved the same way. The tests had not covered those inputs until a reviewer
  named them.
- **Limit:** the study sampled only findings a reviewer named. It cannot show what
  run-based verification alone would have found, or at what cost. Shaka has not
  measured what share of its tokens goes to verification.

### 4. Agents can merge their own PRs

- **Idea:** with strong foundations, agent PRs are good by default. The Grok bot team's
  release fuzzer opens bug-fix PRs that merge themselves (16:21).
- **In Shaka:** each repository chooses Ask or `auto`
  ([merge approval](../reference/pr-record.md#merge-approval)). Under `auto`, the agent
  merges after required checks, independent review, and the checkpoint pass. The
  checkpoint's risk rating must also be at or below
  [`merge.auto_merge_max_risk`](../settings.md#mergeauto_merge_max_risk), which defaults
  to low.
- **Result:** Shaka supports agent merging but keeps code review among its gates.
- **Limit:** Shaka does not track reverts or follow-up fixes after merge. No Shaka
  number compares with the talk's 0.5%.

## Recommendation

| Option | Evidence | Verdict |
| --- | --- | --- |
| Keep the evidence-first PR layout and the adequacy grade | Matches the talk's strongest idea. | Proceed |
| Drop or shrink AI code review in favor of evidence | AI review found inputs the tests missed in 18 sampled Shaka fixes. What evidence alone would catch is unknown. | Evaluate first |
| Turn repeated corrections into checks in the user's repository | Matches the talk and pstack. How often review findings repeat is unknown. | Evaluate first |
| Track revert rate after merge | Easy to count, but blind to forward fixes. | Defer until paired with a count of follow-up fixes |

The
[preregistered review-scope trial](https://github.com/shakacode/shaka/blob/main/eval/reports/review-scope-preregistration.md)
is the natural place to test the second row. Its paid pilot still awaits the
maintainer's approval.

## Sources and limits

- The talk was read from YouTube's automatic transcript on 2026-11-14. Transcript errors
  in names were corrected against the video description.
- Shaka facts come from this repository's documentation at the article's commit and from
  `shaka enforcement` output on 2026-11-14.
- Study numbers come from [What AI code review is worth](review-signal-study.md).
- The comparison is the agent's reading. No experiment ran for this article.
