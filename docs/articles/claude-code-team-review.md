# Shaka and the Claude Code team's code review

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, on 2026-11-14 (UTC).
Justin Gordon started it after a refresh of the
[pstack and agent-skills analysis](https://github.com/shakacode/shaka/pull/985) found
Addy Osmani's post and gave it one paragraph. The agent read Osmani's two posts on X and
Shaka's code, settings, and studies at
[`e13cc94`](https://github.com/shakacode/shaka/tree/e13cc94b4cdf). No experiment was run.
Codex and a fresh Claude session reviewed it before publication.*

Addy Osmani writes as a member of Anthropic's Claude Code team. His
[post](https://x.com/addyosmani/status/2114604912520921136) of 2026-10-25 describes how that
team reviews code now that Claude writes about 90% of it. From June to September, the team
more than doubled its merged pull requests (PRs). Over the same months, the share of PRs it
reverted fell by more than 40%. The post credits layers of checks before
each merge and fast rollback after it.

Shaka is a skill that takes one task to a reviewed PR. Nine of the post's practices apply to
that work. For each, this article lists what Shaka has, what it lacks, and the evidence in
Shaka's code, settings, and published studies. The post's later layers, such as feature flags,
staged rollouts, and fast rollback, come after the merge and fall outside Shaka.

Three earlier pieces cover nearby ground:

- [#1102](https://github.com/shakacode/shaka/pull/1102) compares Shaka with Osmani's post on
  agents making engineers into managers.
- [#985](https://github.com/shakacode/shaka/pull/985) compares Shaka with pstack and
  Osmani's agent-skills.
- The [review signal study](review-signal-study.md) tests the post's claim about repeated
  review on Shaka's own data.

## Main results

- Shaka has the core of two of the nine practices: checks and a fresh-context review before
  the PR, and a risk rating set by the change. Both still have the gaps the table names. Six
  more are partly there. Reviewer evals built from past incidents are missing.
- The largest gap is where review blocks. Osmani's team blocks every merge on any open
  finding and resolves every thread. Shaka blocks on open local review findings only in
  commands the agent runs. A merge you click on GitHub skips them.
- The post's reviewers vote on findings. Shaka's reviewers instead label each one a defect, a
  risk, or a nit. The agent never fixes a nit inside the review loop, though each nit still
  reaches the agent to read.
- A Shaka review loop stops after five reviewed commits by default. The post asks for a
  rethink after three. Each Shaka round still re-reviews the whole diff.
- Every finding gets a recorded outcome, much like the post's noise measure. The
  implementing agent records those outcomes. They measure the agent's judgment, where the
  post measures a person's.

| Practice in the post | Shaka | Main gap |
| --- | --- | --- |
| Checks and a fresh review before the PR | Has | No check that the reviewer followed the repository's criteria |
| AI review on every PR, voted and filtered | Partly | No vote; nits reach the agent |
| Review that blocks the merge | Partly | No security review; threads may stay open; a GitHub click skips it |
| Risk set by the change | Has | Rating quality is unmeasured |
| Approvals agents can't give, one commit each | Partly | GitHub can't tell the agent from you |
| Review that converges | Partly | No diff-only re-review |
| Reviewer evals from past incidents | Lacks | No standing set, no rescore after a change |
| Noise measured by people's responses | Partly | The agent, not a person, responds |
| A template asking for testing, risk, and revert | Partly | Not in the template; the revert note isn't checked |

## The practices, one by one

### 1. Checks and a fresh review before the PR

- **In the post:** before a PR exists, Claude runs tests, a build, or a screenshot
  comparison, and shows the result. A subagent with fresh context then reviews the diff. When
  the reviewer keeps flagging the same issue, the team fixes the cause. The fix goes into a
  skill, a lint rule, `CLAUDE.md`, or `REVIEW.md`, a file of guidance for the reviewer.
- **Shaka has:** the Verify step runs the repository's `validate` command through
  `shaka evidence run`, which records the result and the commit it tested. A reviewer in a
  separate session then reads the committed diff, preferably from another provider.
  [`review.custom_instructions_file`](../settings.md#reviewcustom_instructions_file) plays
  the part of `REVIEW.md`. Shaka's packaged review prompt already asks for two things the
  post wants in that file. Each finding names a file and line. A review that finds nothing
  says "no findings", and each report ends with a line giving the finding count.
- **Shaka lacks:** a check that the reviewer followed the repository's criteria. The reviewer
  states whether it received them, and nothing shows it applied them. Nothing gathers
  findings that recur across PRs. [#1077](https://github.com/shakacode/shaka/issues/1077)
  proposes reading them in a retrospective.
- **Evidence:** `merge` refuses without a posted review that covers the merged commit. The
  [`review.required`](../settings.md#reviewrequired) setting lists the exceptions, such as a
  maintainer's waiver or later commits that change only ordinary Markdown. #1102's section on
  checks covers the rest of this layer.

### 2. AI review on every PR, voted and filtered

- **In the post:** Claude reviews every PR before a person does. Several agents hunt for bugs
  in parallel. A vote keeps only findings with enough support. A filter drops findings that
  only concern style or cleanup, and the team A/B tested those filters on its own PRs. Since
  the research preview, the share of internal PRs with substantive comments rose from 16% to
  54%.
- **Shaka has:** a local review of every change except trivial prose, before the push. The
  default is one reviewer. Shaka's own repository runs Codex and Claude on each commit, in
  parallel, plus the hosted Claude review Shaka ships, after each push. Each local reviewer
  labels every finding a defect, a risk, or a nit. The hosted prompt drops style, lint, and
  pre-existing issues, and rechecks each candidate against the code before posting.
- **Shaka lacks:** a vote. The implementing agent sorts both reviewers' findings in one record
  and merges duplicates. The hosted prompt drops pre-existing problems that the post would
  label. Nits still reach the agent, which has to read each one.
- **Evidence:** `review record` refuses to mark a nit fixed, and a documented nit never
  holds the loop open. The classes are fixed rules in
  [`review_prompt.rb`](../../skills/shaka/lib/shaka/review_prompt.rb), and the hosted prompt is
  in [`claude-code-review.yml`](../../skills/shaka/config/claude-code-review.yml). Shaka tested
  its filter once, after the fact. In the
  [hosted prompt comparison](hosted-review-prompt-comparison.md), the strict prompt caught 0 of
  21 missed bugs and the looser one caught 3. The looser prompt fell short of the preset bar of
  5 more catches, and the strict one stayed. The study says that result doesn't clear the
  strict prompt either.

### 3. Review that blocks the merge

- **In the post:** an automated security review runs beside the code review. No PR merges
  while a finding from either one is open. The author fixes it or resolves the thread with a
  short reason.
- **Shaka has:** blocking in the commands the agent runs. `review run` refuses the next commit
  while a finding from the last round is still open, or a defect is only documented. A pending
  maintainer decision doesn't block it. `attention --state merge`, which marks a PR
  ready for your merge, and `merge --auto` both refuse while the published local review
  reports open findings. A finding closes as fixed with its commit, dismissed with evidence, or
  accepted by the maintainer. On GitHub, `handoff` lists every review thread the agent hasn't
  answered. `resolve` refuses to close a thread before the agent has replied in it.
- **Shaka lacks:** a separate security review. Security is one of five topics in the one
  review prompt. Files named for auth or secrets raise the risk rating instead, as practice 4
  describes. Nothing requires every thread to be resolved, and an answered thread may stay
  open. Every command above sits in the agent's path, and a merge you click on GitHub skips
  them. GitHub can require resolved threads. Shaka's docs don't suggest that rule, and this
  repository leaves it off.
- **Evidence:** the [enforcement map](../../skills/shaka/config/enforcement.yml) marks
  `resolve`'s rule as refused by code and `handoff`'s as reported.

### 4. Risk set by the change, not the author

- **In the post:** a docs fix and an auto-updater change need different review. A classifier
  rates each change's risk. A second classifier decides whether a change needs another
  approval anyway. Sensitive paths and any CI workflow file always need one. Authors on a
  trusted list get lighter requirements.
- **Shaka has:** the checkpoint, a final review of the finished PR, rates its risk low,
  medium, or high. The rating follows what a mistake would reach and whether a revert undoes
  it. Paths in [`high_risk_areas`](../settings.md#high_risk_areas), including GitHub
  workflows, always count as high. Under `auto`, the agent merges only up to
  [`merge.auto_merge_max_risk`](../settings.md#mergeauto_merge_max_risk), low by default.
  [#1081](https://github.com/shakacode/shaka/pull/1081) made this rating Shaka's only risk
  scale.
- **Shaka lacks:** a second classifier and any measure of rating quality. #1081 left measuring
  ratings on live PRs out of scope. [#975](https://github.com/shakacode/shaka/issues/975)
  proposes measuring them and replaying past PRs to compare rating prompts. Shaka has no
  trusted-author list for review. Its
  [trusted people](../workflow.md#trust-model) affect only whose input the agent reads.
- **Evidence:** `merge` refuses a head rated above the limit or changing a high-risk file. The
  [risk rubric](../../skills/shaka/config/post-implementation-risk.md) tells the checkpoint
  reviewer how to rate. #1102 covers who decides what ships.

### 5. Approvals agents can't give, one commit each

- **In the post:** an agent's approval never counts as a person's. When an agent writes a PR,
  the person running it is a required reviewer. An approval covers one commit. A new commit
  the team can't trust, such as an agent's push or a conflict fixed by hand, needs approval
  again.
- **Shaka has:** Ask, the default merge policy, which leaves every merge to a person. You
  click merge on GitHub or approve in chat. Someone you named as a merge approver can also
  approve on GitHub. The agent posts its walkthrough as a comment review, which GitHub
  doesn't count as an approval. Your approval covers one commit, and a later commit ends it.
  Under the workflow, a rebase that keeps the reviewed behavior carries your approval
  forward. An approval on GitHub still follows the repository's own dismissal
  rule.
- **Shaka lacks:** a way for GitHub to tell the agent from you. The agent posts and merges
  with your account, marked only by its 🤖 identity line. After a conflict fix, `merge` no
  longer accepts the earlier review, and the head needs a new review or a waiver. The agent
  alone decides whether the fix changed behavior, and carries your approval forward when it
  judges that nothing changed. No code checks that judgment. The post asks for a new approval
  instead. Shaka sets no GitHub approval rule. Its own repository requires no approving
  review, and dismisses stale approvals when new commits arrive.
- **Evidence:** `merge` refuses when GitHub's required review is unsatisfied, or when the head
  moved. Nothing records which commit you approved. Only the agent tracks it.

### 6. Review that converges

- **In the post:** one PR cycled more than fifty times overnight between an agent author and
  an agent reviewer. The team ran `git blame` on what repeated review flagged. About 59% was
  code there since the first pass. After three cycles, the review now asks the author to
  rethink the approach. Later cycles re-review only the new diff and skip findings already
  reported.
- **Shaka has:** a hard stop.
  [`review.local_max_rounds`](../settings.md#reviewlocal_max_rounds) ends a review loop after
  five reviewed commits by default. When the stop leaves a defect, the agent asks you before
  pushing. The workflow also tells the agent to reconsider the approach after two repair rounds
  that don't converge, though nothing checks it does. Each later round's prompt lists every
  earlier finding with its outcome and asks the reviewer to confirm each fix. When the agent
  records a finding again under its old ID, the PR's review comment flags it as returned
  after its fix.
- **Shaka lacks:** diff-only re-review. Every round reads the whole PR diff. A
  [preregistered comparison](https://github.com/shakacode/shaka/blob/main/eval/reports/review-scope-preregistration.md)
  ([#1072](https://github.com/shakacode/shaka/pull/1072)) designs that test. Its dry run found
  that Shaka's review loop currently refuses a round limited to new commits. The paid pilot
  awaits the maintainer's approval.
- **Evidence:** `review run` refuses the round past the limit. The review signal study
  compared Shaka's later cycles with the post's 59% figure. Most of Shaka's sampled later
  findings sat in code written during the loop, much of it by earlier fixes.

### 7. Reviewer evals from past incidents

- **In the post:** the team collected PRs that caused incidents, with their reverts and
  fix-forwards. Engineers who know the code confirmed each bug. The review system runs against
  that collection daily. Every change to its prompts, tools, or model is scored against all of
  it.
- **Shaka has:** one-off evals built from past misses. The hosted prompt comparison replayed
  17 commits where hosted Claude found nothing and CodeRabbit later found 21 bugs. The
  [eval index](https://github.com/shakacode/shaka/blob/main/eval/README.md) lists each such
  comparison.
- **Shaka lacks:** a standing collection and a rule to rescore. A model change in
  [#446](https://github.com/shakacode/shaka/pull/446) and a prompt change in
  [#640](https://github.com/shakacode/shaka/pull/640) shipped without a score against past
  misses. Hosted findings dropped, and [#1016](https://github.com/shakacode/shaka/pull/1016)
  counted the misses afterward. Shaka also keeps no list of reverted or incident-causing PRs.
  #975 proposes replaying past PRs for the risk rating, not for code review.
- **Evidence:** #640's tests cover only when the hosted review runs a short pass. No eval in
  the index reruns on its own.

### 8. Noise measured by people's responses

- **In the post:** the team sorts each review comment by how the person on the PR handled it:
  fixed, rejected, explained as intentional, or judged not to matter. The team also runs the
  reviewer on PRs known to be clean, to count false alarms. Real bugs come first, and fewer
  cycles second.
- **Shaka has:** a recorded outcome for every local finding: fixed, dismissed, accepted,
  documented, or awaiting your decision. Each PR's review comment publishes them. The review
  signal study counted those outcomes and found every sampled fix real.
- **Shaka lacks:** a person's response. The implementing agent records each outcome. Agents
  wrote about 97% of PR discussion in the
  [October review study](review-process-study.md). Shaka has no run on known-clean PRs, and no
  ongoing measure; the counts come from studies someone asks for. Shaka doesn't count
  reverts either, a gap #1102 also names.
- **Evidence:** `review record` refuses a fixed finding without its fix commit, and an accepted
  one without the maintainer's recorded decision.

### 9. A template asking for testing, risk, and revert

- **In the post:** the PR template asks how the change was tested, what the risk is, and how
  to revert it. Claude may draft the answers. The author is responsible for them.
- **Shaka has:** all three answers in its own PR record. The description's Verification
  section lists the checks that ran and names what went unverified. Its Risk and review
  section shows the checkpoint's rating and reasons. The walkthrough states what a revert would
  not undo, such as sent emails or changed data. The
  [PR record reference](../reference/pr-record.md) explains each field.
- **Shaka lacks:** the questions in the template itself. Shaka's own PR template asks only for
  settings changes and a changelog note. A PR written without Shaka gets no prompt. The
  revert note is an instruction the agent follows, and nothing checks the walkthrough for it.
- **Evidence:** `description` refuses a Verification check that cites neither a link nor a
  code span. The command cannot tell whether the check ran.

## Where the evidence disagrees

Lauren Tan, pstack's author, called adversarial reviews "mostly a waste of tokens"
([post](https://x.com/poteto/status/2117437607940681849), 2026-11-02). The Claude Code team's
numbers point the other way for review as a whole. Substantive comments reached 54% of PRs,
and reverts fell while merges doubled. The post credits all its layers together for that
result. Shaka's review signal study found every sampled fix real.

On repeated review, the post says its repeated cycles rarely found new bugs. In Shaka's
data, most fixed defects came from the first cycle. The two differ on what later cycles find,
as practice 6 describes. The review signal study weighs both sides, and the #1072 test would
settle the question for Shaka.

## From the companion post

Osmani's [second post](https://x.com/addyosmani/status/2117512471930167377) (2026-11-02) is
about keeping your own judgment when agents do the work. Five of its practices map to Shaka
steps:

| Practice | In Shaka |
| --- | --- |
| Define "verified" before you start | The agent restates the outcome and success criteria before coding. The PR shows them as Goal and Done when. |
| Ask what a passing check didn't prove | The Verification section's Not verified line names an unproven claim. |
| Have the agent list its decisions and assumptions | The restatement names risky assumptions. Open questions go under Decisions to make. |
| Read what ran before the summary | Each check names its command or link, and `evidence run` ties each result to a commit. |
| Quiz yourself on the change | An [interactive walkthrough](../pr-verification.md#walk-through-the-code-together) explains one concept at a time and waits for your questions. |

Code checks only the evidence links and commits. The rest depends on the agent writing it and
on you reading it.

## What Shaka could adopt

None of these ideas has shipped:

1. **Score reviewers against past misses before changing them.** Keep the 21 bugs from the
   hosted prompt comparison as a fixed set, and add each later miss. Rerun the set when a
   review prompt or model changes. #975 covers only the risk rating; no issue covers code
   review.
2. **Run the diff-only re-review test.** The #1072 preregistration is priced and waits for
   approval.
3. **Suggest the GitHub rules the post relies on.** Setup could offer required thread
   resolution and dismissal of stale approvals. A merge clicked on GitHub would then honor
   them too. No issue tracks this.
4. **Read finding outcomes across merged PRs.** #1077 proposes this for retrospectives. The
   same read would show which findings recur and belong in review instructions.

## Sources

- Addy Osmani,
  ["How the Claude Code team does code review"](https://x.com/addyosmani/status/2114604912520921136),
  X, 2026-10-25.
- Addy Osmani,
  ["Critical thinking when agents do the work"](https://x.com/addyosmani/status/2117512471930167377),
  X, 2026-11-02.
- Lauren Tan, [post on adversarial review](https://x.com/poteto/status/2117437607940681849), X,
  2026-11-02.
- Shaka at [`e13cc94`](https://github.com/shakacode/shaka/tree/e13cc94b4cdf): the
  [settings reference](../settings.md), the
  [enforcement map](../../skills/shaka/config/enforcement.yml), the review prompt and hosted
  review workflow linked above, and the studies linked above.
- The "Protect main" ruleset of `shakacode/shaka`, read through the GitHub API on
  2026-11-14 (UTC).
