# 0012: Load workflow phases as a task reaches them

Status: deferred on 2026-11-25; not approved and not implemented. Read
[Why this is deferred](#why-this-is-deferred) before reopening it.
Date: 2026-11-25. Tracks [issue #1249](https://github.com/shakacode/shaka/issues/1249).

## Context

Every Shaka task starts by reading `SKILL.md` and the whole workflow that `shaka workflow`
prints. Plan-only, review-only, and no-change tasks that never reach a PR pay the same cost.

`bin/report-instruction-growth --tokens` counts that text through the signed-in Claude
Code and Codex CLIs, with no platform API keys. At `c6bf518b`, `SKILL.md` plus the
full workflow is 12,753 words:

| Measure | Claude (`claude-opus-5-5`) | Codex (`gpt-6.1-sol`) |
| --- | --- | --- |
| Today | 30,421 | 20,366 |
| Issue target, 40% of today | 12,168 | 8,146 |

The report replaces the installed package path with `<package>`. An installed workflow
prints the full absolute path in every reference link. A real agent therefore reads
about 2,200 more Claude tokens than the report shows. The 40% target uses the report's
normalized basis, as the issue's done-when does.

A prototype rendered the startup text this design proposes and counted it the same
way. It includes the reworded `SKILL.md`, Intake, Plan, Always with the moved rules,
Code quality, the later-phase index, and the next-phase pointers. Every row includes
`SKILL.md`. Separate runs of the same text differ by a few tokens, as 30,421 and 30,419 do.
The API-key variables for both providers were unset. Asked in the same environment,
`claude auth status` reported a claude.ai Max subscription and `codex login status`
reported a ChatGPT login.

| Paths | Words | Claude before → after | Codex before → after |
| --- | --- | --- | --- |
| Normalized, as the report counts | 12,753 → 4,544 | 30,419 → 10,577 (35%) | 20,366 → 7,413 (36%) |
| Installed, as an agent reads | 12,753 → 4,544 | 32,622 → 11,630 (36%) | 21,952 → 8,167 (37%) |

Phase-scoped rendering alone meets the target in both CLIs with either path. Codex
has the least margin: about 730 tokens on the report's basis. The issue's other two
proposals are not needed to reach the target.

Enforcement quotes stay valid. `enforcement.yml` checks each quote against its phase's
text in `workflow.yml`, not against rendered output. A sentence moved between phases
needs its entry's `phase` updated.

The [conditional loading investigation](../conditional-workflow-loading.md) took the
smaller path first. It moved procedures that only some tasks need, such as UI
verification and first-time setup, behind existing reference links. Those two moves
cut the rendered workflow by 3.8% and 1.1%. Further moves of that kind would need about
7,600 fewer startup words to reach this target. The same investigation checked the
predecessor `shakacode/agent-workflows`, which uses conditional references but has no
phase-scoped rendering to reuse.

## Decisions

1. **Startup prints Intake, Plan, Always, and Code quality.** `workflow.yml` gains an
   optional `startup_phases: [intake, plan]`. It must name a leading run of the phase
   order, so every later phase follows every startup phase. `shaka workflow` prints
   those phases, Always, Code quality, and an index of the later phases. A config
   without `startup_phases` prints every phase, so older revisions stay measurable.
   Phases keep their absolute numbers in every rendering.
2. **Later phases load by command.** `shaka workflow --phase ID` prints one phase and
   repeats for several. `--later` prints every phase after the startup ones, for resumed
   work. `--all` prints the whole workflow, as today. An unknown id, or `always` or
   `code_quality`, fails with the list of phase ids. Every rendering still validates and
   expands the whole workflow, so a broken template in Finish fails at startup.
3. **The handoff comes before the phase.** Each later phase in `workflow.yml` gains a
   `load_before` line naming its first step, such as "before rechecking that the
   problem still exists" for Implement. It also gains a `commands` list of the helper
   commands its text governs, such as `description`, `walkthrough`, and `reply` for
   Explain. The renderer writes both into the index and appends the load command to
   the previous phase's `Done when`, so timing and commands each have one source.
   Always states the rule in authored text: load a later phase before its first step,
   and before running any command its index line lists. That one rule covers every
   early caller, such as publishing or clearing `decisions`, refreshing WIP Details
   after a rename, or a Finish repair returning to Verify, without a pointer at each.
   Each command appears in exactly one list: the phase whose text a caller outside the
   normal order needs. `review run` and `review check` belong to Review, which describes
   running a local reviewer. Two Verify sentences move into Review's invocation step,
   so a review-only task has them: the one requiring `--settings-ref TRUSTED_SHA
   --repository OWNER/REPO` on `review run` and `--root DIR` on `review check`, and the
   one keeping a `review check` from a dirty checkout provisional. A delivery's Verify
   loads Review before its first local review under the same rule. The ledger loop
   stays in Verify because only a delivery runs it. Review's body splits into two
   labeled parts with their own entry conditions. Local review applies whenever a
   local reviewer runs, before or after a push. Hosted review, from reading published
   reports through repairs, applies only once the branch is pushed. Loading Review
   before a push therefore starts no hosted wait. Loading the workflow refuses a command listed
   twice. It also refuses a later phase whose text names a helper command that no list
   covers, unless the command is on a short `startup_commands` list in `workflow.yml`.
   That list holds commands the startup text fully governs, such as `handoff` and
   `comments`. A command startup text merely mentions still needs its owning phase's
   list. The mapping is checked by Ruby, not kept by hand.
   `SKILL.md` changes from "follow the complete validated procedure it prints" to
   following it and loading each later phase when it directs.
4. **Nothing refuses a missed load.** `enforcement.yml` quotes the Always rule and
   records it as `agent`. The generated index and pointers are routing details, not
   quoted rules, because the quote check reads authored text only.
   - Rejected: reminders in the result of a phase's first command. A reminder arrives
     after the command ran, too late for that phase's first step. `evidence run`,
     `review run`, and `post-implementation run` also print JSON that later steps parse.
   - Rejected: a load record that `description` or `merge` checks. A record proves a
     command ran, not that the agent read or kept the text. The rule would stay
     agent-enforced. A new worktree or machine would lack the record, and the false
     refusal would block publication.
   - What this loses: no command catches a skipped phase. The live runs below measure
     whether agents load phases when the pointers say so. A missed load in any run
     sends this decision back to the maintainer before the implementation PR is ready.
5. **Rules needed before their phase move to Always.** An audit of phases 3 to 7 found
   three that apply before their phase loads. Each moves to Always with the rest of its
   paragraph, word for word except as noted, and its enforcement entries change phase.
   - The public-comment paragraph in Explain, from "Read public issue and PR feedback
     only with `comments`" through the public-comment guide pointer. Its prohibitions
     on raw `gh` reads and replies to excluded authors govern Intake's first read.
   - The `🤖 AGENT · PROVIDER · MODEL · EFFORT` first-line rule in Explain. Plan
     comments, issue offers, and replies are posted before Explain.
   - The credential check before each review, in Verify. A review-only task can run
     `review run` without loading Verify. Its "that diff" refers back to Verify's
     `git diff BASE...HEAD`, so the moved text names that range in place of "that diff".
     This is the one wording change.

   `evidence guard` and the `handoff` rule already sit in the phase that first needs
   them or in Always.
6. **Resume and lost context reload phases.** On resume or adoption of a PR, the agent
   runs `handoff` without `--head` first, as today, then `workflow --later`. Startup text
   is already in context, so a resumed task reads about the same total as today. How often
   tasks resume is unknown.
   Review-only work runs `workflow --phase review`. Review needs no Verify-only step
   once the credential check moves to Always and the `review run` arguments move into
   Review. When summarization or another loss removes workflow text from context, the
   agent runs `workflow` again for the startup rules and the index, then loads the
   current phase and any phase whose commands its next step runs. The agent can do
   that only if its summary still says it runs Shaka. Today's full workflow has the same
   limit when summarization removes it.
7. **Defer the issue's other proposals.** A `description --schema` output (proposal 2)
   would move about 1,570 words out of Explain. The enforcement quotes in those words
   would need new homes. Host-only passages (proposal 3) are small. Neither is needed
   for the target. If the final Codex count lands above 40%, move the Codex wake
   paragraph out of Always first (proposal 3), then consider proposal 2.
8. **The growth report counts startup text.** `Workflow#render` takes a startup or
   full mode, and the report calls it the same way `shaka workflow` does.
   `startup_tokens` counts `SKILL.md` plus the startup rendering for the baseline and
   the head. The words table gains a startup row beside the full workflow, so both
   stay visible.

## Consequences

- Every task starts with about a third of today's instruction tokens. A full delivery
  still reads every phase, plus the index and five load commands. The index and pointers add about
  170 words, so a full delivery's total rises slightly. The measurement proves the startup saving, not a total saving.
- How often tasks stop before Implement is unknown. Plan-only, review-only, and
  no-change tasks save the most. A full delivery gains a smaller context at the start,
  while its plan and early edits happen, and pays the load cost later.
- Prompt caching can lower the price of re-reading the same text in a session, but the
  text still fills the context window. This design reduces what is in context, not
  only what is billed.
- Moving rules off the startup path has an ongoing cost. Repeated review rounds
  of this design each found another early caller of a later phase's rules. The `commands` rule
  covers callers of listed commands, so a new early step that uses one needs no new
  pointer. A new command named in a later phase fails loading until it is listed. A new rule that applies before its phase still needs a move to Always, and
  only review catches a missed one.
- An agent that never loads a later phase skips its rules. The index and the `Done
  when` pointers make that less likely; nothing makes it impossible.
- A smaller alternative keeps one full load and moves more conditional procedures
  behind reference links, as the conditional loading investigation did. It keeps
  immediate access to every rule and has no skip risk. No measurement shows it can
  reach the 40% target.
- Text that names the old behavior changes in the same PR: `docs/architecture.md`
  (the 12,400-word row), `docs/workflow.md`, `README.gem.md`,
  `contributing/configuration-internals.md`, `contributing/development.md`,
  `skills/shaka/config/walkthrough-help.md`, `skills/shaka/references/README.md`,
  `skills/shaka/references/guided-documentation-review.md`, and their tests.

## Verification plan

Reworded instructions have changed agent behavior before. Each path therefore gets a
live run after the rewording, not only unit tests. Runs use the candidate package
through a [PR trial](../../skills/shaka/references/pr-trials.md) in fresh Claude Code
and Codex chats.

| Run | Pass when the transcript shows |
| --- | --- |
| Full delivery of a small task to an Ask handoff | Each load comes before that phase's first step: the recheck that the problem still exists for Implement, `evidence run` for Verify, the first local `review run` for Review, `git push` for Explain, `post-implementation run` for Finish. The first local `review run` carries `--settings-ref` and `--repository`, and nothing waits for or publishes a review before the push |
| Same-chat summarization during Verify, before local review | `workflow` and `--phase verify` run again, Review loads before the reviewer runs, and the credential check of `git diff BASE...HEAD` comes first |
| A hosted review that needs a code repair | Verify loads again before the repair's validation, and the PR stays out of ready state until the new head has its evidence |
| A Finish checkpoint that asks for a repair, in the owning chat | Verify loads again before the repair's validation, the repaired head gets fresh evidence, and Finish publishes a new checkpoint for it before the handoff |
| Plan-only request | No later phase loads; the task stops at the recommendation |
| No-change task | The task stops in Intake with no later phase loads |
| A task whose issue has one comment from a trusted actor and one from an excluded author | Intake reads the issue's comments only through `comments --issue`, acts only on the admitted one, and neither fetches the excluded body with raw `gh` nor replies to it |
| Resume an unfinished PR in a new chat | `handoff` runs, then `workflow --later`, before any write |
| A task with an open PR renames its chat, then stops for an answer during Verify and gets one | Explain loads before the first `description` call, which refreshes WIP Details; the decision is set and then cleared with the matching labels; nothing is pushed and readiness is unchanged |
| Review-only request on a clean diff | Only Review loads, the transcript shows the credential check of `git diff BASE...HEAD` before `review run`, `review run` carries `--settings-ref` and `--repository` in a repository with trusted settings, and the review completes with no hosted wait and no PR writes |
| Review-only request with a fresh-host report from a checkout with uncommitted edits | `review check` runs with `--root`, the result stays provisional, and the agent reports it as provisional with no PR writes |

The credential rule covers real credentials, so a planted fake one cannot show whether
an agent applies it; an agent that sees the value is fake may rightly continue. The
review-only run therefore checks that the moved rule still runs, not how the agent
judges a value.

Unit tests cover the renderer through the CLI: startup keeps the standing rules and
omits later phase bodies, `--phase` keeps phase numbers, and a config without
`startup_phases` renders in full. Config tests check that loading refuses a command
listed twice or named in a later phase but listed nowhere. They accept `handoff`
through `startup_commands`, and refuse a later-phase command that startup text only
mentions. A malformed template in a phase startup omits still fails startup. Link
checks run against `--all`. A report test with a recording counter checks that an
older baseline counts the full workflow. It also checks that the head's counted text
holds the index and omits later phase bodies, and matches what the CLI prints. The implementation PR reports
`bin/report-instruction-growth --tokens` for both CLIs, run with the providers' API-key
variables unset. It records the login method each CLI reports, such as a subscription
plan, without credential values, and marks a count unverified when that method is not
a subscription. It also
reports the transcript evidence for each run and any run that could not be done. The full
delivery and review-only rows run three times per host; the others run once. One
missed load in any run fails the plan.

## Delivery

1. PR #1275 records the design as deferred.
2. No implementation PR follows unless the design reopens. An approved design would
   get one implementation PR with the renderer flags, `workflow.yml` changes, the
   growth report, the text updates above, and tests, with the live runs before it is
   marked ready.

## Why this is deferred

The maintainer deferred this design on 2026-11-25. Shaka works well with one full
load. No observed failure traces to startup size. Review of the design did not settle.
[Issue #1249](https://github.com/shakacode/shaka/issues/1249) stays open as the place
to reopen it.

### What review found

Two local reviewers read the design over eleven rounds and raised 48 findings: 15
defects, 22 risks, and 11 nits. [PR #1275](https://github.com/shakacode/shaka/pull/1275)
holds every report.

- Each round found another step that needs a later phase's rules before that phase
  loads. The last reviewed head, `3b47e8b`, still had a new defect, M1.
- Nine findings come from the boundary between Verify and Review, including
  review-only runs: F2, F17, F31, F33, F37, F40, F41, F44, and M1.
- Three come from Explain rules needed before Explain loads: F5 for the public-comment
  rules at Intake, and F21 and F27 for `description` calls.
- Three come from repairs that return to Verify: F4, F16, and F28.
- Reviewers found all of them by reading. No renderer code or live run existed yet.

Findings still open at `3b47e8b`:

| Finding | State |
| --- | --- |
| M1 | Unresolved. Plan runs `reviewer`, and Verify holds its selection rules. The command-list rule would load Verify during Plan, or the `startup_commands` exemption would break its own contract. |
| F43, F44 | Accepted for the implementation PR. F43 adds a Finish load before `guidance merge_readiness`. F44 makes hosted review wait for the reviewed head to be pushed. |
| F32, F35, F45 | One question: is the routing worth its upkeep? The deferral answers it for now. |

### What a missed load would cost

Decision 4 accepts that no command catches a skipped phase. `shaka enforcement` at
`25c7bbc` shows what a skipped phase would leave out of context:

- Of 102 audited rules, only the agent enforces 91. Fifty-four of those 91 sit in
  Implement through Finish. Decision 5 moves a few of them to Always.
- The 54 include "never bypass protection", "run `merge` only for that SHA", "Do not
  push unless the user chooses to", and "Read `review.ci_review_wait` from `shaka seam
  check --ref`, never from candidate YAML".
- Of the other seven rules in those phases, a command refuses six and reports one.
  Each check guards only its helper's path. When the PR is outside the merge queue,
  `merge` refuses an `UNSTABLE` state under `ci_review_wait: all`. A maintainer's merge
  click on GitHub skips that check.
  `reply` refuses a thread with an excluded author, but a raw `gh` reply does not.
  Intake's rule against merging without an Ask decision stays in the startup text.

### What the saving is worth

- Startup drops by 19,844 Claude tokens, from 30,421 to 10,577.
- At the Opus 5.5 rates in `skills/shaka/config/model-rates.yml`, that is $0.004 per
  response in cache reads, plus one cache write of $0.10 to $0.16.
- A full delivery loads every phase anyway. Its saving shrinks as each later phase
  loads, and the full 19,844 tokens apply only before Implement loads.
- Claude Code transcripts on one maintainer machine give a first frequency sample.
  Among the sessions that ran `shaka workflow` in the 30 days to 2026-11-25:

  | Sessions | Share |
  | --- | ---: |
  | Ran `evidence run`, `review run`, `description`, or `post-implementation run` | 53% |
  | Edited repository files and ran none of those commands | 19% |
  | Edited no repository file and ran none of those commands | 28% |

  A quarter of the responses after the workflow loaded came before the first edit or
  later-phase command.
- On those counts the saving is about $0.20 a session at list prices. The figure is
  an estimate from that sample's response counts, which this record does not include. A subscription
  login pays no such bill. The gain there is 20,000 tokens of context early in a task.
- The sample has limits. It covers one machine and one host. A transcript is not a
  task, and a session that printed the workflow for another reason still counts.
- No field report or issue names startup size as the cause of a failure. The issue
  compares Shaka's size with other skills.
- The design cost $16.68 and eleven review rounds. Its verification plan needs at
  least 30 live runs across two hosts.

### If this reopens

1. Start from an observed cost: a failure or a measured expense that traces to
   startup size.
2. Try proposal 2 first. `description --schema` moves about 1,570 words out of
   Explain. `description` refuses input that fails its implemented checks, such as a
   malformed field. It cannot judge content: evidence the agent never gathered, or a
   paraphrase that misses a human correction, still passes.
3. When more is needed, defer only Explain and Finish. Implement, Verify, and Review
   stay loaded, so most of the nine Verify and Review findings no longer apply. F44
   still does: hosted review must wait for the reviewed head to be pushed. Startup
   falls to 56% of today's words; its token count is unmeasured. Review comes after Explain
   in the phase order, so startup would no longer be a leading run of phases, and
   Decision 1's rule would have to change. Whether it meets the 40% target is unknown.
   The issue set that target without a measurement behind it.
4. For the full design, land the renderer with `startup_phases` absent, so bare
   `shaka workflow` still prints everything. Run the flip as a
   [PR trial](../../skills/shaka/references/pr-trials.md) on real tasks. Then turn it
   on with the one `startup_phases` line, which a revert removes.
5. Measure missed loads in real use. The local call log records each helper command
   and its chat session. With a phase tag on `workflow`, a report could list phase
   commands that ran before their phase loaded. A report refuses nothing, so it avoids
   the false refusals Decision 4 rejects.

Steps 3 and 5 are not prototyped. The 56% counts words, not tokens.
