# 0012: Load workflow phases as a task reaches them

Status: proposed; awaiting maintainer approval before implementation.
Date: 2026-11-25. Tracks [issue #1249](https://github.com/shakacode/shaka/issues/1249).

## Context

Every Shaka task starts by reading `SKILL.md` and the whole workflow that `shaka workflow`
prints. Plan-only, review-only, and no-change tasks that never reach a PR pay the same cost.

Measured at `c6bf518b` with `bin/report-instruction-growth --tokens`, which counts through
the signed-in Claude Code and Codex CLIs (no platform API keys):

| Startup text | Words | Claude (`claude-opus-5-5`) | Codex (`gpt-6.1-sol`) |
| --- | --- | --- | --- |
| `SKILL.md` plus the full workflow | 12,753 | 30,421 | 20,366 |
| Issue target, 40% of today | — | 12,168 | 8,146 |

The report replaces the installed package path with `<package>`. An installed workflow
prints the full absolute path in every reference link, so a real agent reads about 2,200
more Claude tokens than the report shows (32,615 in the prototype count below).

A prototype rendered only Intake, Plan, Always, and Code quality after `SKILL.md`, with
real paths, and counted both versions the same way:

| Startup text | Words | Claude | Codex |
| --- | --- | --- | --- |
| Full workflow | 12,753 | 32,615 | 21,952 |
| Intake, Plan, Always, Code quality | 4,125 | 10,661 (33%) | 7,542 (34%) |

Phase-scoped rendering alone meets the issue's target. The issue's other two proposals
are not needed to reach it.

Enforcement quotes stay valid: `enforcement.yml` checks each quote against its phase's
text in `workflow.yml`, not against rendered output, so printing fewer phases at startup
changes no quote. A sentence moved between phases needs its entry's `phase` updated.

## Decisions

1. **Startup prints Intake, Plan, Always, and Code quality.** `workflow.yml` gains
   `startup_phases: [intake, plan]`. `shaka workflow` prints those phases, Always, Code
   quality, and a short index of the later phases: each one's title, when to load it,
   and the command. A config without `startup_phases` prints every phase, which keeps
   older revisions measurable.
2. **Later phases load by command.** `shaka workflow --phase ID` prints one phase.
   `--from ID` prints that phase and every later one, for resumed or adopted work.
   `--all` prints everything, so the full workflow stays reachable in one command.
3. **Each phase names the next.** Each later phase's `Done when` line ends with the
   command for the next phase. `SKILL.md` changes from "follow the complete validated
   procedure it prints" to following it and loading each later phase as it directs.
4. **Load handoffs are reminders, not gates.** This is the choice the issue left open.
   - Recommended: the commands that begin a phase print its load command in their
     result: `evidence run` and `review run` for Verify, `description` for Explain,
     `post-implementation run` and `handoff` for Finish. They hold no state and cannot
     refuse wrongly. `enforcement.yml` records the new rule as `agent`, naming those reminders.
   - Rejected: `workflow --phase` writes a load record in the Git directory, and
     `description` or `merge` refuse without it. A record proves a command ran, not that
     the agent read or kept the text, so the rule would still be agent-enforced. It
     adds state that is wrong for a new worktree or machine, and false refusals would
     block publication. The [trust model](../../docs/workflow.md#trust-model) guards
     against untrusted input, not against the maintainer's own agent. A reminder in the
     command output reaches the agent when it needs the rule.
5. **Rules needed before their phase move to Always.** An audit of phases 3 to 7 found
   two that apply at Intake or Plan:
   - "Read public issue and PR feedback only with `comments`" (Explain) governs reading
     the issue at Intake and any resumed PR.
   - The `🤖 AGENT · PROVIDER · MODEL · EFFORT` first line (Explain) applies to plan
     comments, issue offers, and replies before Explain.

   Both move to Always word for word, and their enforcement entries change phase.
   Credential checks, `evidence guard`, and the `handoff` rule already sit in the phase
   that first needs them or in Always.
6. **Resume and lost context reload phases.** Always says: on resume or adoption, run
   `handoff` without `--head` first, as today, then `workflow --from` the phase the live
   state needs. Reload the current phase whenever its text is no longer in context, such
   as after summarization. Review-only work loads Review only.
7. **Defer the issue's other proposals.** A `description --schema` output (proposal 2)
   would move about 1,570 words out of Explain, and with them enforcement quotes that
   would need new homes. Host-only passages (proposal 3) are small. Neither is needed
   for the target; revisit them if a full delivery's total becomes the concern.
8. **The growth report counts startup text.** `startup_tokens` counts `SKILL.md` plus
   what `shaka workflow` prints with no flags, for the baseline and the head. The words
   table gains a startup row beside the full workflow, so both stay visible.

## Consequences

- Every task starts with about a third of today's instruction tokens. A full delivery
  still reads every phase, plus the index and up to five load commands, so its total
  rises slightly. The measurement proves the startup saving, not a total saving.
- An agent that never loads a later phase skips its rules. The index, the `Done when`
  pointers, and the command reminders make that less likely; nothing makes it impossible.
- Text that names the old behavior changes in the same PR: `docs/architecture.md`
  (the 12,400-word row), `docs/workflow.md`, `README.gem.md`,
  `contributing/configuration-internals.md`, `contributing/development.md`,
  `skills/shaka/config/walkthrough-help.md`, `skills/shaka/references/README.md`,
  `skills/shaka/references/guided-documentation-review.md`, and their tests.

## Verification plan

Reworded instructions have changed agent behavior before, so each path gets a live run
after the rewording, not only unit tests. Runs use the candidate package through a
[PR trial](../../skills/shaka/references/pr-trials.md) in fresh Claude Code and Codex chats.

| Run | Pass when the transcript shows |
| --- | --- |
| Full delivery of a small task to an Ask handoff | Each `workflow --phase` load comes before that phase's first command: the branch for Implement, `evidence run` for Verify, `description` for Explain, review intake for Review, `post-implementation run` for Finish |
| Plan-only request | No later phase loads; the task stops at the recommendation |
| No-change task | The task stops in Intake with no later phase loads |
| Resume an unfinished PR in a new chat | `handoff` runs first, then `workflow --from` the live phase, before any write |
| Review-only request | Only Review loads |

The implementation PR reports `bin/report-instruction-growth --tokens` for both CLIs,
the transcript evidence for each run, and any run that could not be done.

## Delivery

1. This design PR.
2. One implementation PR after approval: renderer flags, `workflow.yml` changes, command
   reminders, the growth report, the text updates above, and tests. The live runs happen
   before it is marked ready.
