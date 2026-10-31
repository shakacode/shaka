# Showing intent and proof in PR descriptions: ideas from Lauren Tan and Addy Osmani

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-10-30 (UTC). The maintainer asked how Shaka pull request (PR) descriptions
came to show intent and proof, centered on Lauren Tan's and Addy Osmani's work. The agent read their public sources and this repository's
PRs, recounted the numbers, and drafted the text. Codex and a fresh Claude session
reviewed it before publication.*

Agents wrote 111 of the 115 PRs merged in this repository from 2026-10-22 to
2026-10-29. A maintainer still decides whether to trust each merge. In October
2026 the maintainer gave the PR description two jobs
([#421 plan](https://github.com/shakacode/shaka/issues/421#issuecomment-6205960445)).
It shows what the PR is trying to do. It shows that the verification is adequate
for that goal.

Two people's public work shaped how Shaka does those jobs. Lauren Tan's pstack and
posts treat proof as the limiting step of agent work. Addy Osmani's factory
defines what proof a human receives and where human attention goes. This report
takes nine of their ideas. Each one says what Shaka built, how it held up, and
where it fell short.

## Main results

- Tan's test for proof covers the same ground as the two jobs. An artifact should
  show the work is correct, matches the intent, and is quicker to review than the
  whole PR. The #421 plan cites that post. 110 of 115 PRs now carry Intent and
  Verification.
- Fixing the environment, as Tan advises, showed the largest before-and-after change.
  When agents chose all three checks, 11 of 12 PRs spent two restating passes. After
  Shaka wrote that line itself, 32 of 101 spent one and none spent two.
- By the orchestrating session's account, Osmani's load-bearing paths led to Shaka's
  review floors. They also fit this repository's data. In a study of 309 PRs, what a PR changed predicted a person's
  feedback better than its size. 106 PRs now name their floor.
- By the same account, factory's rule against paraphrasing a gate result led to the
  Shaka-written line. A tool-written line still depends on its inputs: 6 of the 8 lines reporting
  a missing reviewer were wrong. Both reviewers had run, and the agent passed Shaka
  one result file ([#984](https://github.com/shakacode/shaka/pull/984)).
- One prompt sentence changed what the checkpoint reviewer reported about blast
  radius, across 30 runs on three real PRs
  ([#743](https://github.com/shakacode/shaka/pull/743)).
- Not in Shaka: restating the goal before work starts, which both recommend, and
  factory's fixed verification table and script proving a new test fails without the
  fix.
- Not measured: whether maintainers now decide faster or better.

![Before and after. #543, merged 2026-10-15, shows a summary, a checkpoint status, and a free-form table of areas and results; nothing states the problem, what was left out, or what went untested. #974, merged 2026-10-29, shows a recommendation with links, a summary, an Intent block with Why, Task, Root cause, Safe because, Review effort 2 of 5 with its floor, and Scope, then Verification with a Shaka-written validation and review line and a Setup gaps line saying 1 of 2 configured reviewers completed. Its checks and Not verified line are folded under Evidence and limitations. A note says #984 later found the Setup gaps line wrong: both reviewers ran, and the agent passed one result. Tags name Tan as the source for Intent, and Osmani as the source for the review floor and validation line, by the orchestrating session's account.](../img/pr-description-before-after.svg)

## Data and limits

- **Sources:** this repository's public PRs and issues, Tan's posts,
  [pstack](https://github.com/cursor/plugins/tree/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack)
  at `c742dd6`, and Osmani's
  [factory](https://github.com/addyosmani/factory/tree/8af116567166a0a16588b7ab1b9934ece0b775bc)
  at `8af1165` and
  [agent-skills](https://github.com/addyosmani/agent-skills/tree/eb07f19f52c2669f2364897aaa293e2aaddd7b1c)
  at `eb07f19`, plus two Osmani posts named below.
- **Attribution:** the #421 plan cites Tan's work directly. No public Shaka record
  cites Osmani's. The agent session that orchestrated this work reports reading
  factory, agent-skills, and both posts on 2026-10-18. It then cited factory in its
  brief for #740 and #757. That account is first-hand and can't be checked on GitHub.
- **Count:** PRs merged from 2026-10-22 through 2026-10-29 UTC, run on 2026-10-30
  at 03:00 UTC, after the window closed:
  `gh pr list --repo shakacode/shaka --state merged --search "merged:2026-10-22..2026-10-29" --limit 300 --json number,author,mergedAt,body`.
- **Matching:** each description was matched by its text:
  - an `## Intent` heading, or `## Change and review`, its name from
    [#860](https://github.com/shakacode/shaka/pull/860) until
    [#888](https://github.com/shakacode/shaka/pull/888);
  - a `**Validation and review:**` line;
  - `Floor N:` in the Review effort line;
  - a `**Setup gaps:**` line naming configured reviewers.
- **Restated checks:** "11 of 12" is #740's own count of the PRs merged after #553.
  "32 of 101" comes from the window above, where 101 descriptions list check bullets
  under Verification. Those bullets were searched for terms such as `bin/validate`,
  `--command validate`, `0 failures`, and `RuboCop clean`, then read by eye. A few
  matches also prove something about the change.
- **Not in the count:** 5 of the 115 have no Intent block: 4 Dependabot PRs and one
  that Shaka did not publish. The count has no comparison group from another
  repository, and descriptions are read as they are now.
- **Not measured:** whether the fields are true, and whether maintainers decide
  faster.

## Lauren Tan: proof is the limiting step

[Loops You Can Trust](https://x.com/poteto/article/2069824386283319343) argues that
verification constrains an agent loop the way the slowest step constrains a
production line. pstack is Tan's public skill set in `cursor/plugins`.

### 1. Proof should show the work is right, intended, and quick to review

- **Idea:** give agents a way to verify their own work, then have them produce an
  artifact. It should show the work is correct, matches the intent, and is easier
  to review than the whole PR
  ([post, 2026-10-11](https://x.com/poteto/status/2109436202554372476)).
- **In Shaka:** the two jobs, set four days later.
  [#553](https://github.com/shakacode/shaka/pull/553) added Intent and Verification
  to every description.
- **Result:** 110 of 115 PRs carry both. Before #553, only a summary was required.
- **Limit:** Shaka checks that the fields exist. Whether a Why line is true is left
  to the agent, the reviewers, and the checkpoint.

### 2. A PR body is a short briefing for someone who has the diff

- **Idea:** the
  [opening-a-pr playbook](https://github.com/cursor/plugins/blob/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack/skills/poteto-mode/playbooks/opening-a-pr.md)
  gives a one-minute briefing with an always-present Scope. Each Verification bullet
  is a real run path and its outcome. Other detail goes to linked artifacts.
- **In Shaka:** Intent holds Why, Safe because, and Scope. Verification holds up to
  three checks. Audit detail is collapsed.
- **Result:** the visible text now names the problem, the scope, and the safety
  fact. On [#543](https://github.com/shakacode/shaka/pull/543), it named none of
  them.
- **Limit:** bodies stayed long. [#974](https://github.com/shakacode/shaka/pull/974)
  has about 15,900 characters, and about 2,000 are visible. That is near the same
  share as #543, at about 1,500 of 10,500.
- **Left out:** the playbook's Tradeoffs and Blast Radius sections. Shaka keeps
  alternatives in the code walkthrough and asks the checkpoint about blast radius.

### 3. An artifact beats an explanation, and any stage can stop the line

- **Idea:** in Loops You Can Trust, an artifact gives a reviewer something to inspect,
  where an explanation can sound right and be wrong. Failing to reproduce a bug, or judging a fix too
  risky, is a useful outcome that keeps bad work from moving on.
- **In Shaka:** each check must cite a link or a command (#553).
  [#742](https://github.com/shakacode/shaka/pull/742) has the checkpoint judge
  whether the proof is enough. Under Auto, `merge` refuses a head judged inadequate
  or unjudgeable until a person confirms it.
- **Result:** #743 tested the checkpoint's question about blast radius. With it,
  every run on the two code PRs said whether a revert undoes the change. Without it,
  none did. 2 of 5 runs with it missed a real gap that all 5 runs without it found.
  [Evaluation article](checkpoint-sentence-eval.md).
- **Limit:** Shaka can tell that a link or command is cited, not that it ran. This
  repository still runs Ask, so the Auto stop has not fired here. The evaluation
  used one model and one scorer, who also wrote the criteria.

### 4. Find the one fact a change is safe because of

- **Idea:** the
  [blast-radius skill](https://github.com/cursor/plugins/blob/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack/skills/blast-radius/SKILL.md)
  looks for the single fact a change's safety depends on, then proves it by running
  real code. It ranks evidence from an unsupported claim up to a reproduction in the
  running app.
- **In Shaka:** the Intent block's required Safe because line.
  [#576](https://github.com/shakacode/shaka/pull/576) also tells agents to reproduce
  through the real caller before editing, and to check the fix's safety assumption.
- **Result:** in #576's [comparison](https://github.com/shakacode/shaka/blob/main/eval/reports/early-verification.md),
  the revised guidance caught an empty-chunk crash the old guidance missed. Both
  agents reproduced before editing, so testing earlier was a tie.
- **Limit:** Safe because is a sentence, and Shaka does not rank its evidence. The
  comparison was one pair per wording.

### 5. Fix the environment instead of correcting the agent

- **Idea:** when agents repeat a mistake, change the repository so the mistake can't
  happen ([post](https://x.com/poteto/status/2106542593656111276)). The
  [`correct` skill](https://github.com/cursor/plugins/blob/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack/skills/correct/SKILL.md)
  tries architecture first, then types, lint, and tests, with docs last.
- **In Shaka:** three rules moved from prose into code.
  - #553 refuses a description with a missing field.
  - [#740](https://github.com/shakacode/shaka/pull/740) writes the validation and
    review line from recorded results.
  - [#757](https://github.com/shakacode/shaka/pull/757) refuses a review effort below
    a floor computed from the changed paths.
- **Result:** 11 of 12 PRs had spent two of three checks on restated passes. Now 32
  of 101 spend one, mostly to add test totals. #553 had asked only for what ran and
  its outcome. Ratings of 1 on workflow or Ruby changes
  ([#690](https://github.com/shakacode/shaka/pull/690),
  [#694](https://github.com/shakacode/shaka/pull/694),
  [#704](https://github.com/shakacode/shaka/pull/704)) can no longer publish.
- **Limit:** the windows differ, and nobody ran a controlled comparison. Shaka's
  [rule table](https://github.com/shakacode/shaka/pull/145), which records what
  enforces each workflow rule, predates this post.

### 6. Restate the goal before working

- **Idea:** [`/in-your-own-words`](https://x.com/poteto/status/2110047236369547621)
  has the agent say what it thinks the goal and problem are before it starts.
  Osmani's Agentic Verification recommends the same habit.
- **In Shaka:** not built. #742 left out this plan-time restatement.
- **Limit:** Intent is written at publication, after the work. It records a
  misunderstanding and cannot catch one early.

## Addy Osmani: what proof a human receives

factory is a reference setup for running agents on a GitHub repository. Humans keep
every merge and every load-bearing change. agent-skills is a general skill pack.

[The Code Nobody Reads](https://addyo.substack.com/p/the-code-nobody-reads)
(2026-09-28) argues that line-by-line reading is ending for much code, so checks must
replace the trust that reading gave.
[Agentic Verification](https://addyo.substack.com/p/agentic-verification)
(2026-10-14) names verification as the bottleneck and credits Tan on giving agents a
way to drive the real system.

By the orchestrating session's account, ideas 7 and 8 led to #740 and #757. Idea 9
predates this work.

### 7. Report the gate result in a form the agent can't soften

- **Idea:** factory's [implement skill](https://github.com/addyosmani/factory/blob/8af116567166a0a16588b7ab1b9934ece0b775bc/template/.claude/skills/factory-implement/SKILL.md)
  makes the agent quote the gate script's final `FACTORY_GATES:` line verbatim, and
  forbids restating it. A misconfigured gate or a skipped required gate doesn't count
  as green. Its verifier reruns the gates and treats a mismatch as a
  finding.
- **In Shaka:** by that account, this rule led to #740. The helper writes the line from results bound
  to the head, and no agent types it. Any exit code other than 0 shows as failed, and missing results
  show as UNKNOWN. Hosted `validate` reruns the suite on GitHub.
- **Result:** of 110 lines, 96 report recorded results and 14 report UNKNOWN. In 4
  of those, the installed Shaka updated during the run. In another 4, heavy machine
  load broke timing tests. The other 6 were not traced.
- **Limit:** [#923](https://github.com/shakacode/shaka/pull/923) added a line for
  missing reviewers, and it counted only the result files the agent passed. #984
  traced all 8 such lines: 6 were false, and on 2 the agent never ran the second
  reviewer. `description` now refuses results from one ledger batch that leave out a reviewer.
  A result rebuilt with `review check`, as on #974, still gets through.

### 8. Send human attention to load-bearing paths

- **Idea:** factory's [charter](https://github.com/addyosmani/factory/blob/8af116567166a0a16588b7ab1b9934ece0b775bc/template/docs/factory/CHARTER.md) lists paths that always
  get the deepest gates and a human read, and are never auto-merged. Its PR template
  has a Human read required section. The Code Nobody Reads sizes human attention to
  blast radius: a lighter pass for small changes to less sensitive code, and careful
  review for core paths.
- **In Shaka:** by that account, these led to #757, which computes a review floor from the changed
  paths. Agents may rate higher, never lower. Tan's `correct` ladder pointed the same
  way. Floors come from the default branch, so a PR can't lower its own. factory has
  the same rule against an agent rewriting its own constraints.
  [#812](https://github.com/shakacode/shaka/pull/812) later let Auto merge only PRs at
  or below a chosen floor. That came from #780 and the study below, not from factory.
- **Result:** a [study of 309 PRs](one-shot-pr-study.md) supports paths over size.
  A person gave feedback on 65, and 64 of those changed docs or agent instructions.
  Within the size limits, 0 of 73 PRs that left those files and Shaka's settings
  alone drew feedback.
  - Ratings here were 2 in 9 PRs, 3 in 30, 4 in 24, and 5 in 47, across the 110 PRs
    with Intent.
  - This repository's docs floor set 45 of the 47 at 5, by the
    [maintainer's choice](https://github.com/shakacode/shaka/pull/757#discussion_r4331436333).
  - [#827](https://github.com/shakacode/shaka/pull/827) replayed 60 PRs at floor 2,
    and 14 would have merged without a person.
- **Limit:** a path floor misses one risky line inside a low-floor file.
  [#922](https://github.com/shakacode/shaka/pull/922) added Closer reading for that.
  4 PRs with an Intent block name no floor, because they changed only design records
  under `internal/`.

### 9. The writer doesn't grade the work

- **Idea:** factory's contract says "The writer does not grade the work." A fresh
  verifier reads the diff cold. agent-skills'
  [doubt-driven-development](https://github.com/addyosmani/agent-skills/blob/eb07f19f52c2669f2364897aaa293e2aaddd7b1c/skills/doubt-driven-development/SKILL.md)
  asks a fresh-context reviewer to disprove a claim. The Code Nobody Reads adds that a
  second copy of the same model shares the first one's blind spots. Tan's skills also
  use a second model family.
- **In Shaka:** this predates the reading. Shaka prefers a reviewer from another provider, who reads
  each commit before push. The Verification line names who reviewed the head.
- **Result:** Codex reported 37 of the 102 defects that local review found, defects
  Claude did not report ([review process study](review-process-study.md)).
- **Limit:** #984 found 2 PRs where the agent ran one reviewer, because the helper's
  note named only the first. That note now names them all.

### Not in Shaka

- **Fixed verification table:** factory's verifier reports fixed rows. The #421 plan
  proposed a similar table, and #743 recommended deferring it.
- **Rejecting when uncertain:** factory's verifier leans toward rejecting. Shaka's
  checkpoint can answer `cannot judge`, which stops Auto but not Ask.
- **Unattended edits to existing tests:** factory bans them. Shaka has no such rule.
- **Agents never merge:** factory reserves every merge for a human. Shaka's Auto can
  merge within trusted limits.
- **Proving a new test fails:** factory's
  [`prove-test.sh`](https://github.com/addyosmani/factory/blob/8af116567166a0a16588b7ab1b9934ece0b775bc/template/.factory/scripts/prove-test.sh) removes the fix and confirms
  the new test fails. Shaka asks agents to observe the failure, and no script checks
  it.
- **A verifier kept from the writer's account:** factory's verifier ignores any
  narrative it receives. Shaka's reviewers receive the task's stated goal.
- **Stop rules:** factory halts a run when gates fail twice on one item. In Shaka, two
  repair rounds without convergence prompt a reassessment, and a cap limits reviewed
  commits.

## Where Tan and Osmani agree and differ

- **Agree on the constraint:** both name verification as the limit on agent work.
- **Agree on repeated mistakes:** Tan's `correct` skill and Osmani's Agentic
  Verification both put the fix in the repository: a check, a hook, or shared config.
- **Agree on checking the writer:** both use a fresh reviewer, ideally another model.
- **Agree on restating the goal:** both recommend it before coding. Shaka hasn't built
  it.
- **Differ on instruction length:** Tan
  [expects skills to compress](https://x.com/poteto/status/2110496830429839869) into
  short principles. Two pstack principle skills run 209 and 324 words. Three
  agent-skills skills run 2,474 to 3,334 words. The #421 plan chose the short form.
- **Also matches:** The Code Nobody Reads tells authors to say in the PR description
  what they did not review. #553's Not verified line predates Shaka's reading of that
  post.

## Other dead ends

- **Lost review evidence.** Shaka already told agents to keep review ledgers out of
  temporary directories, and warned when one sat there
  ([#479](https://github.com/shakacode/shaka/pull/479)). On #742 and #743, a restart
  still wiped a ledger kept in the session scratchpad.
  [#976](https://github.com/shakacode/shaka/issues/976) tracks durable usage records.
- **The installed Shaka moved mid-task.** Recorded evidence binds to the installed
  revision, and an update during a task supersedes it. #812 reran review and
  validation.
  [#960](https://github.com/shakacode/shaka/pull/960),
  [#961](https://github.com/shakacode/shaka/pull/961),
  [#973](https://github.com/shakacode/shaka/pull/973), and #922 published UNKNOWN
  results.
- **Machine load.** On [#868](https://github.com/shakacode/shaka/pull/868),
  [#881](https://github.com/shakacode/shaka/pull/881),
  [#927](https://github.com/shakacode/shaka/pull/927), and
  [#942](https://github.com/shakacode/shaka/pull/942), local validation hit timing
  failures. Hosted validation was the gate.
- **PRs that change the renderer can't show themselves.** The installed, older Shaka
  rendered the descriptions of #740, #757, and
  [#810](https://github.com/shakacode/shaka/pull/810).
- **Noise from the new fields.** A new user found the evidence the most useful part
  of [shakacode/shakaperf#243](https://github.com/shakacode/shakaperf/pull/243).
  Routine passes and a Not verified line about work nobody asked for got in the way
  ([#777](https://github.com/shakacode/shaka/issues/777)). #810 folds routine passes.
  The [verification guide](../pr-verification.md#answers-for-your-next-decision) has
  the current rules.

## Open items

- [#421](https://github.com/shakacode/shaka/issues/421) stays open. The plan-time
  restatement (idea 6) and an evaluation of how implementing agents verify are not
  done.
- [#780](https://github.com/shakacode/shaka/issues/780): this repository previews
  Auto at floor 2 and still runs Ask. A planned settings PR would switch
  `merge.preference` to `auto`.
- [#976](https://github.com/shakacode/shaka/issues/976): usage records that survive
  model switches, restarts, and host handoffs.

## What other teams can reuse

- Give the description two jobs, and refuse to publish it when a required field is
  missing (Tan, idea 5).
- Let the tool write every result it can compute. Check that the tool received all
  its inputs (Osmani, idea 7; #984).
- Rate review effort from the changed paths, and name the file that set the rating.
  Study your own PRs to choose the paths (Osmani, idea 8).
- Require a named fact behind "safe", and a link or command behind each check (Tan,
  ideas 3 and 4).
- Have someone other than the writer read the change (Osmani, idea 9).
- Measure a prompt change before building on it. #743 took 30 runs and about $1.78.

To check the same fields on your repository, ask your agent:

```text
$shaka For PRs merged in this repository last week, count how many
descriptions have an Intent block, Shaka's validation and review line, and a
named review-effort floor. List the ones that don't.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.

## The ten PRs

These ten built the two jobs and tested the prompt sentence. Later PRs cited above
refined the result. Merge dates are UTC.

| Merged | PR | What changed |
| --- | --- | --- |
| 10-16 | [#547](https://github.com/shakacode/shaka/pull/547) | The packaged checkpoint prompt asks whether testing fits what a failure would reach and whether a revert undoes it. |
| 10-16 | [#549](https://github.com/shakacode/shaka/pull/549) | This repository's checkpoint prompt asks the same question. |
| 10-16 | [#553](https://github.com/shakacode/shaka/pull/553) | Every description gets Intent and Verification. |
| 10-20 | [#743](https://github.com/shakacode/shaka/pull/743) | A 30-run evaluation of the #547/#549 sentence. |
| 10-20 | [#759](https://github.com/shakacode/shaka/pull/759) | While decisions are open, the walkthrough waits. |
| 10-21 | [#740](https://github.com/shakacode/shaka/pull/740) | Shaka writes the validation and review line. |
| 10-21 | [#757](https://github.com/shakacode/shaka/pull/757) | Review effort gets a floor computed from the changed paths. |
| 10-21 | [#810](https://github.com/shakacode/shaka/pull/810) | Routine passes fold, from field report #777. |
| 10-21 | [#812](https://github.com/shakacode/shaka/pull/812) | Auto merges only PRs at or below a chosen floor. |
| 10-22 | [#742](https://github.com/shakacode/shaka/pull/742) | The checkpoint judges whether the proof is enough. |
