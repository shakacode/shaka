# 0012: Load workflow phases as a task reaches them

Status: proposed; awaiting maintainer approval before implementation.
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
about 2,200 more Claude tokens than the report shows.

A prototype rendered the startup text this design proposes and counted it the same
way. It includes the reworded `SKILL.md`, Intake, Plan, Always with the moved rules,
Code quality, the later-phase index, and the next-phase pointers. Every row includes
`SKILL.md`.

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

The predecessor `shakacode/agent-workflows` splits its process into separate skills,
such as `pr-batch` and `address-review`. No phase-scoped rendering of one workflow was
found there to reuse.

## Decisions

1. **Startup prints Intake, Plan, Always, and Code quality.** `workflow.yml` gains an
   optional `startup_phases: [intake, plan]`, validated against the phase ids.
   `shaka workflow` prints those phases, Always, Code quality, and an index of the later
   phases. Each index line gives the phase id and the step it must precede.
   A config without `startup_phases` prints every phase, so older revisions stay
   measurable. Phases keep their absolute numbers in every rendering.
2. **Later phases load by command.** `shaka workflow --phase ID` prints one phase and
   repeats for several. `--all` prints the whole workflow, as today.
3. **The handoff comes before the phase.** Each phase's `Done when` line ends with the
   command that loads the next phase, before its first step. A phase that sends work
   back, such as a Review or Finish repair, names the phase to reload at that point.
   `SKILL.md` changes from "follow the complete validated procedure it prints" to
   following it and loading each later phase when it directs.
4. **Nothing refuses a missed load.** `enforcement.yml` records the new rule as `agent`.
   - Rejected: reminders in the result of a phase's first command. A reminder arrives
     after the command ran, too late for that phase's first step. `evidence run`,
     `review run`, and `post-implementation run` also print JSON that later steps parse.
   - Rejected: a load record that `description` or `merge` checks. A record proves a
     command ran, not that the agent read or kept the text. The rule would stay
     agent-enforced. A new worktree or machine would lack the record, and the false
     refusal would block publication.
   - What this loses: no command catches a skipped phase. The live runs below measure
     whether agents load phases when the pointers say so. A missed load they show is a
     reason to revisit this decision.
5. **Rules needed before their phase move to Always.** An audit of phases 3 to 7 found
   three that apply before their phase loads. Each moves to Always word for word, with
   the rest of its paragraph, and its enforcement entries change phase.
   - The public-comment paragraph in Explain, from "Read public issue and PR feedback
     only with `comments`" through the public-comment guide pointer. Its prohibitions
     on raw `gh` reads and replies to excluded authors govern Intake's first read.
   - The `🤖 AGENT · PROVIDER · MODEL · EFFORT` first-line rule in Explain. Plan
     comments, issue offers, and replies are posted before Explain.
   - The credential check before each review, in Verify. A review-only task can run
     `review run` without loading Verify.

   `evidence guard` and the `handoff` rule already sit in the phase that first needs
   them or in Always.
6. **Resume and lost context reload phases.** On resume or adoption of a PR, the agent
   runs `handoff` without `--head` first, as today, then `workflow --all`. Resumed PR
   work usually spans Explain, Review, and Finish, which hold most of the text.
   Review-only work loads Review. The agent reloads the current phase whenever its text
   is no longer in context, such as after summarization.
7. **Defer the issue's other proposals.** A `description --schema` output (proposal 2)
   would move about 1,570 words out of Explain. The enforcement quotes in those words
   would need new homes. Host-only passages (proposal 3) are small. Neither is needed
   for the target. Revisit them if a full delivery's total becomes the concern.
8. **The growth report counts startup text.** `Workflow#render` takes a startup or
   full mode, and the report calls it the same way `shaka workflow` does.
   `startup_tokens` counts `SKILL.md` plus the startup rendering for the baseline and
   the head. The words table gains a startup row beside the full workflow, so both
   stay visible.

## Consequences

- Every task starts with about a third of today's instruction tokens. A full delivery
  still reads every phase, plus the index and four load commands. The index and pointers add about
  170 words, so a full delivery's total rises slightly. The measurement proves the startup saving, not a total saving.
- How often tasks stop before Implement is unknown. Plan-only, review-only, and
  no-change tasks save the most. A full delivery gains a smaller context at the start,
  while its plan and early edits happen, and pays the load cost later.
- Prompt caching can lower the price of re-reading the same text in a session, but the
  text still fills the context window. This design reduces what is in context, not
  only what is billed.
- An agent that never loads a later phase skips its rules. The index and the `Done
  when` pointers make that less likely; nothing makes it impossible.
- A smaller alternative is trimming the full workflow in place. Trimming keeps one
  load and no skip risk, but the issue's 40% target would need about 7,600 fewer words
  of rules.
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
| Full delivery of a small task to an Ask handoff | Each `workflow --phase` load comes before that phase's first step: the branch for Implement, `evidence run` for Verify, `git push` for Explain, reading published reviews for Review, `post-implementation run` for Finish |
| A hosted review that needs a code repair | Verify loads again before the repair's validation, and the PR stays out of ready state until the new head has its evidence |
| Plan-only request | No later phase loads; the task stops at the recommendation |
| No-change task | The task stops in Intake with no later phase loads |
| Resume an unfinished PR in a new chat | `handoff` runs, then `workflow --all`, before any write |
| Review-only request with a harmless fake credential in the diff | Only Review loads, and the agent stops before `review run` and names the file |

Unit tests cover the renderer: startup excludes later phase bodies, `--all` keeps them,
and a config without `startup_phases` renders in full. The implementation PR reports
`bin/report-instruction-growth --tokens` for both CLIs, the transcript evidence for
each run, and any run that could not be done.

## Delivery

1. This design PR.
2. One implementation PR after approval: renderer flags, `workflow.yml` changes, the
   growth report, the text updates above, and tests. The live runs happen before it
   is marked ready.
