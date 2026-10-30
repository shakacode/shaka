# How Shaka PR descriptions came to show intent and proof

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-10-30 (UTC). The maintainer asked for an account of the work under
[#421](https://github.com/shakacode/shaka/issues/421) that changed what a Shaka
pull request (PR) description shows. The agent read the PRs, issues, and outside
sources, recounted the adoption numbers, and drafted the text. Codex and a fresh
Claude session reviewed it before publication.*

In October 2026 the maintainer gave a PR description two jobs. It shows what the
PR is trying to do. It shows that the verification is adequate for that goal.
With both, the maintainer can decide whether to trust the merge. The
[#421 plan comment](https://github.com/shakacode/shaka/issues/421#issuecomment-6205960445)
records the principle. Ten PRs merged from 2026-10-16 to 2026-10-22 built it
into Shaka.

## Main results

- Every Shaka description now has an Intent block and a Verification section. Before [#553](https://github.com/shakacode/shaka/pull/553), only a
  summary was required.
- Shaka writes the first Verification line from the recorded validation and
  review results ([#740](https://github.com/shakacode/shaka/pull/740)). Before
  that, 11 of 12 PRs spent two of their three checks restating those results.
  From 2026-10-22 to 2026-10-29, 32 of the 101 PRs that list checks spent one,
  mostly to add test totals.
- Review effort can't be rated below a floor that Shaka computes from the changed
  files. The description names the file that set it
  ([#757](https://github.com/shakacode/shaka/pull/757)).
- The checkpoint reviewer judges whether the proof is enough. Under Auto, a head
  judged inadequate, or one it cannot judge, waits for a person
  ([#742](https://github.com/shakacode/shaka/pull/742)).
- Of 115 PRs merged 2026-10-22 to 2026-10-29 (UTC), 110 have an Intent block
  and a validation-and-review line, and 106 name the floor behind their review
  effort.
  The other 5 are 4 Dependabot PRs and one PR that Shaka did not publish.
- The new lines show gaps as well as passes. 14 descriptions report their
  validation and review results as UNKNOWN. 8 report that only 1 of 2 configured
  reviewers completed.
- A 30-run evaluation found that one checkpoint prompt sentence changed what
  reviewers reported about blast radius
  ([#743](https://github.com/shakacode/shaka/pull/743)).

![Before and after. #543, merged 2026-10-15, shows a summary, a checkpoint status, and a free-form table of areas and results; nothing states the problem, what was left out, or what went untested. #974, merged 2026-10-29, shows a recommendation with links, a summary, an Intent block with Why, Task, Root cause, Safe because, Review effort 2 of 5 with its floor, and Scope, then Verification with a Shaka-written validation and review line and a Setup gaps line saying 1 of 2 configured reviewers completed. Its checks and Not verified line are folded under Evidence and limitations.](../img/pr-description-before-after.svg)

## Data and limits

- Sources: public PR descriptions and comments in this repository, issues #421,
  #777, #780, and #976, Lauren Tan's
  [pstack](https://github.com/cursor/plugins/tree/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack)
  at `c742dd6`, and Addy Osmani's
  [factory](https://github.com/addyosmani/factory/tree/8af116567166a0a16588b7ab1b9934ece0b775bc)
  at `8af1165`.
- The adoption count covers PRs merged from 2026-10-22 through 2026-10-29 UTC.
  It was run on 2026-10-30 at 03:00 UTC, after the window closed:
  `gh pr list --repo shakacode/shaka --state merged --search "merged:2026-10-22..2026-10-29" --limit 300 --json number,author,mergedAt,body`.
- Each description was matched by its text:
  - an `## Intent` heading, or `## Change and review`, its name from #860 until
    #888 restored Intent;
  - a `**Validation and review:**` line;
  - `Floor N:` in the Review effort line;
  - a `**Setup gaps:**` line naming configured reviewers.
- Restated checks were found by a keyword search for a validation or review pass
  in the Verification bullets, then read by eye. A few matches also prove
  something about the change.
- Descriptions are read as they are now. An agent may have republished one after
  merge.
- 111 of the 115 PRs came from the maintainer's account, and agents wrote all
  111 descriptions. The count has no comparison group from another repository.
- The count shows that descriptions carry the fields. Whether the fields are
  true, and whether maintainers decide faster, was not measured.
- Visible size did not shrink. The text outside collapsed sections is about 1,500
  characters in #543 and 2,000 in #974, near an eighth of each body.

## Timeline

Merge dates are UTC.

| Merged | PR | What changed | Why |
| --- | --- | --- | --- |
| 10-16 | [#547](https://github.com/shakacode/shaka/pull/547) | The packaged checkpoint prompt asks whether testing fits what a failure would reach and whether a revert undoes it. | [#543](https://github.com/shakacode/shaka/pull/543)'s checkpoint recommended Merge without saying what a failure would reach. |
| 10-16 | [#549](https://github.com/shakacode/shaka/pull/549) | This repository's checkpoint prompt asks the same question. | The repository prompt replaces the packaged one entirely. |
| 10-16 | [#553](https://github.com/shakacode/shaka/pull/553) | Every description gets Intent and Verification. Shaka refuses a missing field or a check with no link or command. | A description required only a summary. The maintainer rebuilt the goal and the gaps from the walkthrough and checkpoint. |
| 10-20 | [#743](https://github.com/shakacode/shaka/pull/743) | A 30-run evaluation of the #547/#549 sentence, with an [article](checkpoint-sentence-eval.md). | The plan required evidence before building on the sentence. |
| 10-20 | [#759](https://github.com/shakacode/shaka/pull/759) | While decisions are open, the checkpoint link points at them and the walkthrough waits. | Maintainer feedback on #742: a walkthrough is for the merge. |
| 10-21 | [#740](https://github.com/shakacode/shaka/pull/740) | Shaka writes the validation-and-review line from recorded results. Any exit code other than 0 shows as failed. | 11 of the 12 PRs merged after #553 spent two of three checks restating those results. |
| 10-21 | [#757](https://github.com/shakacode/shaka/pull/757) | A review-effort floor computed from changed paths, set per repository in `pr_description.human_review_floors`. | [#690](https://github.com/shakacode/shaka/pull/690), [#694](https://github.com/shakacode/shaka/pull/694), and [#704](https://github.com/shakacode/shaka/pull/704) changed workflow text or Ruby and rated effort 1. |
| 10-21 | [#810](https://github.com/shakacode/shaka/pull/810) | Routine passes fold under a summary. Not verified is left out when nothing went unproven. | A new user's field report, [#777](https://github.com/shakacode/shaka/issues/777). |
| 10-21 | [#812](https://github.com/shakacode/shaka/pull/812) | `merge.auto_max_review_floor`: Auto merges only PRs at or below a chosen floor. | Auto merged every ready PR within size limits ([#780](https://github.com/shakacode/shaka/issues/780)). |
| 10-22 | [#742](https://github.com/shakacode/shaka/pull/742) | The checkpoint reads Intent and Verification and returns a verdict. Under Auto, `merge` stops on inadequate or cannot judge. | Agents wrote the goal twice, and nobody judged whether the proof was enough. |

Related changes outside those ten:

- [#576](https://github.com/shakacode/shaka/pull/576) (10-17) asks the agent to
  reproduce through the real caller before editing and to check the fact the
  fix's safety depends on. It covers the plan's first two steps.
- [#633](https://github.com/shakacode/shaka/pull/633) (10-17) adds **Root cause**
  to Intent for bug fixes.
- [#827](https://github.com/shakacode/shaka/pull/827) (10-26) sets this
  repository's Auto floor to 2 while it stays on Ask. Each ready checkpoint
  previews whether Auto would merge.
- [#888](https://github.com/shakacode/shaka/pull/888) (10-26) puts Why first in
  Intent and ends it with scope and size.
- [#923](https://github.com/shakacode/shaka/pull/923) (10-28) adds the **Setup
  gaps** line when fewer reviewers completed than configured.
- [#885](https://github.com/shakacode/shaka/pull/885) and
  [#922](https://github.com/shakacode/shaka/pull/922) (10-29) add the **Task**
  line and a **Closer reading** list of files that need more care.

## Findings

### 1. A required shape changed what agents wrote

- **Observed:** Before #553, a description needed only a summary. The #421 plan
  found collapsed usage data at 65 to 70% of the body in #539, #542, and #543.
  The visible decision content was 8 to 14%.
- **Change:** #553 made `intent` and `verification` required content. Shaka
  refused to publish without Why, Scope, Leaves out, Safe because, a review effort
  of 1 to 5, and a Not verified line. Each of the one to three checks had to cite
  a link or a command. Leaves out became optional in #860. Since #810, a Not
  verified answer of `Nothing.` is hidden.
- **Result:** 110 of 115 PRs in the window carry the Intent block.
- **Limit:** Shaka checks presence and form. Whether a Why line is true is left
  to the agent, the reviewers, and the checkpoint.

### 2. A Shaka-written line cut restated passes from two checks to one

- **Observed:** #553 allowed up to three checks. In 11 of the next 12 PRs, two
  of them restated that validation passed and local review was clean.
- **Change:** #740 renders that line from the validation and review results
  already bound to the head. The agent's checks are kept for proof about the
  change itself.
- **Result:** 110 of 115 PRs carry the line. 96 report recorded results. 14
  report UNKNOWN because no current results were supplied.
- **Result:** 32 of the 101 PRs that list checks still spend one on a validation
  pass. Most add the test and RuboCop totals, which #740's line leaves out. None
  spends two.
- **Limit:** UNKNOWN marks missing evidence for that head. The causes are listed
  under [dead ends](#limits-and-dead-ends).

### 3. Agents under-rated review effort until Shaka computed a floor

- **Observed:** #690, #694, and #704 changed always-loaded workflow text or Ruby.
  Each rated review effort 1, the level meant for docs.
- **Change:** #757 computes a minimum from the changed paths and names the file
  that set it. This repository puts `docs/**` at 5. The maintainer reviews docs
  for external users most closely
  ([review comment](https://github.com/shakacode/shaka/pull/757#discussion_r4331436333)).
- **Result:** 106 of 115 PRs name a floor. The 4 other PRs with an Intent block
  changed only design records under `internal/`, which no floor covers.
  Across all 110 PRs with Intent, ratings were 2 in 9 PRs, 3 in 30,
  4 in 24, and 5 in 47. Of the 47 at 5, the docs floor set 45 and the Shaka
  settings floor set 2. 20 PRs rated above their floor, and 86 rated at it.
- **Limit:** A path floor misses one risky line inside a low-floor file. #922 added
  Closer reading for that case.

### 4. One prompt sentence changed what the checkpoint reported

- **Observed:** #547's own checkpoint called the effect of its sentence unknown.
- **Evidence:** #743 ran 30 checkpoints on three merged PRs, with and without the
  sentence. Reports were scored under shuffled IDs.
  - With it, every run on the two code PRs said whether a revert undoes the
    change. Without it, none did.
  - 2 of 5 runs with it missed a real gap in #695. All 5 runs without it found
    that gap.
- **Change:** Shaka kept the sentence and deferred the fixed verification table
  the plan had proposed.
- **Limit:** One model and one scorer, who also wrote the criteria. Two or three
  runs per cell show a direction, not a rate. Details are in the
  [evaluation article](checkpoint-sentence-eval.md).

### 5. The checkpoint judges adequacy, and Auto follows the verdict

- **Observed:** Agents wrote the problem, outcome, and validation twice: once for
  the checkpoint and once for the description.
- **Change:** #742 has the checkpoint read the description's Intent and
  Verification. It returns one verdict: adequate, adequate with accepted gaps,
  inadequate, or cannot judge. Under Auto, `merge` refuses an inadequate or
  unjudged head until a person confirms it. Ask is unchanged.
- **Decision:** The maintainer kept that stop fixed, with no setting for now.
- **Limit:** This repository still runs Ask, so the Auto stop has not fired here.

### 6. A field report trimmed the noise

- **Observed:** A new Shaka user found the evidence the most useful part of their
  description, [shakacode/shakaperf#243](https://github.com/shakacode/shakaperf/pull/243).
  Routine passes and a Not verified line about work nobody asked for got in the
  way.
- **Change:** #810 folds the validation-and-review line when validation passed
  and every review ran through Shaka. Not verified is limited to claims the PR
  makes, and left out when there are none. Since #923, the line also stays
  unfolded when a configured reviewer did not finish. The
  [verification guide](../pr-verification.md#answers-for-your-next-decision)
  has the current rules.
- **Limit:** One reader and one PR. How often the noise mattered elsewhere is
  unknown.

## Outside influences

The work drew on two public agent setups.

**Lauren Tan's pstack (`cursor/plugins`) and posts.** The #421 plan cited them
directly.

- **Taken:** the
  [opening-a-pr playbook](https://github.com/cursor/plugins/blob/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack/skills/poteto-mode/playbooks/opening-a-pr.md)
  treats the body as a short briefing for a reviewer who has the diff. Scope is
  always present, and each Verification bullet is a real run path with its
  outcome. #553's Intent and Verification follow that shape.
- **Taken:** her post
  [Loops You Can Trust](https://x.com/poteto/article/2069824386283319343), as the
  plan summarizes it, prefers artifacts to plausible explanations. Each Shaka
  check has to cite a link or a command.
- **Taken:** the
  [`correct` skill](https://github.com/cursor/plugins/blob/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack/skills/correct/SKILL.md)
  fixes a repeated mistake in the repository itself: architecture, then types or
  lint, then tests, with docs last. Shaka enforced the description shape in Ruby,
  wrote the validation line itself, and computed the floor.
- **Left:** pstack's Tradeoffs and Blast Radius sections. Shaka keeps
  alternatives in the code walkthrough and asks the checkpoint about blast
  radius.

**Addy Osmani's factory (`addyosmani/factory`).** The research for this work read
it. No Shaka PR or issue cites it.

- **Similar:** its contract requires the PR body to quote the gates script's
  final `FACTORY_GATES:` line verbatim. Its verifier reruns the gates instead of
  trusting that line. In Shaka, the helper writes the line from bound results
  (#740). No agent copies it.
- **Similar:** its charter lists load-bearing paths. A change to one gets the
  deepest gates and a human read, and is never auto-merged. Shaka's floors
  (#757) and `merge.auto_max_review_floor` (#812) map paths to a review level and
  hold PRs above a chosen level back from Auto.
- **Not taken:** its fixed verification table, its standing bias to reject when
  uncertain, and its ban on unattended edits to existing tests. Shaka deferred
  the fixed table after #743. Its checkpoint can answer `cannot judge`, which
  stops Auto but not Ask.

## Limits and dead ends

- **Boilerplate checks.** Required checks first filled up with restated passes.
  A Shaka-written line cut them from two checks to one (#740).
- **Self-rated effort.** Agents rated workflow and Ruby changes at 1. Computed
  floors now refuse that (#757).
- **Lost review evidence.** Shaka already told agents to keep review ledgers out
  of temporary directories, and warned when one sat there
  ([#479](https://github.com/shakacode/shaka/pull/479)). On #742 and #743, a
  restart still wiped a ledger kept in the session scratchpad. #742 lacks the
  usage for two lost rounds, and #743's published ledger starts after them.
  [#976](https://github.com/shakacode/shaka/issues/976) tracks durable usage
  records across host handoffs.
- **The installed Shaka moved mid-task.** Recorded evidence binds to the
  installed Shaka's revision. When the installation updated during a task, that
  evidence was superseded.
  - #812 reviewed and validated its last head again.
  - [#960](https://github.com/shakacode/shaka/pull/960),
    [#961](https://github.com/shakacode/shaka/pull/961), and
    [#973](https://github.com/shakacode/shaka/pull/973) published UNKNOWN results
    and relied on hosted CI.
- **Machine load.** On [#868](https://github.com/shakacode/shaka/pull/868),
  [#881](https://github.com/shakacode/shaka/pull/881),
  [#927](https://github.com/shakacode/shaka/pull/927), and
  [#942](https://github.com/shakacode/shaka/pull/942), local validation hit
  timing failures under heavy load. Hosted validation was the gate.
- **Reviewers that did not finish.** 8 PRs show 1 of 2 configured reviewers
  completed: Anthropic's in 6 and OpenAI's in 2. All merged after #923 added the
  line. The cause is still open.
- **PRs that change the renderer can't show themselves.** #740, #757, and #810
  note that the installed, older Shaka rendered their own descriptions. Their new
  sections appeared only in preview comments.

## Open items

- [#780](https://github.com/shakacode/shaka/issues/780): this repository previews
  Auto at floor 2 but still runs Ask. A later settings PR switches
  `merge.preference` to `auto`.
- [#421](https://github.com/shakacode/shaka/issues/421) stays open. #742 left out
  the plan-time restatement of the goal and an evaluation of how implementing
  agents verify.
- Reviewer completion: the Setup gaps line shows the shortfall. Its cause is not
  known yet.
- [#976](https://github.com/shakacode/shaka/issues/976): usage records that
  survive model switches, restarts, and host handoffs.

## What other teams can reuse

- Give the description two jobs, intent and adequate proof, and enforce its shape
  in code. Refuse to publish when a required field is missing.
- Let the tool write every line it can compute, such as the validation result
  and which reviewers ran. Keep the author's checks for claims about the change.
- Compute a review-effort floor from the changed paths. Let authors rate higher,
  never lower, and name the file that set the floor.
- Limit "not verified" to claims the PR makes. Fold routine passes and keep
  failures and gaps visible.
- Measure a prompt change before building on it. #743 shows one way to do it in
  30 runs for about $1.78.

To check the same fields on your repository, ask your agent:

```text
$shaka For PRs merged in this repository last week, count how many
descriptions have an Intent block, Shaka's validation and review line, and a
named review-effort floor. List the ones that don't.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
