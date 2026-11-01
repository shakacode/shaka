# Publication procedure

- Before publishing, read [the shared writing rules](writing.md) and use them
  alongside the instructions here.
- In replies, state the decision; use shared context without requiring private discussion.
- Self-edit the content JSON; do not rewrite the rendered GitHub body or invoke a
  separate rewriting skill for Shaka's publication step.
- No style schema or prose score is needed beyond the limits below.

## Write the description summary

- Write `summary` as one outcome sentence, a blank line, then at most four bullets, each
  one fact a maintainer needs to decide on merging. Omit the bullets when that sentence
  covers the change.
- Put a safety argument in `intent.safe_because` and issue history in `task_history`.
- Instead of: “It stays under Human comments, and reviewer-shortfall and sandbox gaps
  still appear under Setup gaps. `shaka resolve` still refuses to treat one as the
  agent’s answer, so it gains no authority.”
- Write:
  - “Your comments stay under Human comments.”
  - “Setup gaps still lists reviewer shortfalls and sandbox problems.”
  - “`shaka resolve` still won’t accept a raw `gh` reply as the agent’s answer.”

## Post-implementation comments

- The renderer supplies the order, labels, and the reviewer's evaluation and concerns.
  Write the owner's `reason` and `next_action` as
  [the checkpoint procedure](post-implementation-validation.md#recommend-the-next-action) describes.
- Use this example for content, not exact wording or claims:

  > ## Recommendation: {Merge, Merge after maintainer decision, Revise before merge, Reconsider approach, or Do not merge}
  >
  > {Affected users} can now {specific behavior}. {Main reason for the recommendation}.
  >
  > **Next:** {Action and applicable dependencies, checks, or approvals}.

- Replace every slot with concrete task facts and actual evidence.

## Review evidence

- Supply description `task_started_at` from the original task's initiating
  instruction timestamp in UTC. Omit it when unavailable or later than PR opening; the helper
  then uses the earliest `--all-turns` or `--since-time` implementation usage report.
  The helper retains it across updates; a resumed chat's start is not a new task start.
  Pass a recorded `--ci-review-wait` task override to `description` too.

- Verification opens with bound validation/review status and an optional linked `summary`.
  Put material merge-affecting gaps in `merge_limitations`; accepted gaps stay in `not_verified`.
  Checks, tables, and PR-specific `details` share one Evidence and limitations disclosure.
  Put the initiating request and useful decision history in optional `task_history`.
- Intent ends with `scope`, GitHub's file/line totals, and path-based file buckets.
  Count each current filename once: Tests, then Docs/instructions, Code, or Other.
  Inspect the expandable paths for ambiguous classifications; buckets describe paths, not effort.
  Supply `leaves_out` only for a deliberately deferred part readers would reasonably expect.
- Shaka metrics keeps estimated token costs visible, then folds usage, timings, execution,
  settings, skills, provenance history, and task history under Details, in that order.

- Put the current-head recommendation, main reason, and next action before analysis.
- Name model settings with their provenance; a configured model is not proof of a served model.
- Name the user benefit, scope, and unfinished verification when they affect the decision.
- Distinguish verified results, a recommendation to merge, and permission to merge.
  Keep unresolved blockers visible.
- State whether a simpler alternative revises this PR or replaces it.
- Supporting usage and history can remain collapsed.
- State a risk as who or what is affected and what they would see fail: “API
  clients get a 500 until the cache warms,” not “medium blast radius.”
- State what reverting a commit restores and what it leaves:
  - Reverting code does not restore deleted or rewritten stored data.
  - It does not undo outside effects such as sent email, charges, or published packages.
  - Name each such effect and how to recover from it, or that it cannot be recovered.

## Point readers to the code

- The diff already shows what changed. Say why, flag what needs a close look, and link to it.
- A description sends the reader to the walkthrough; a walkthrough links each step
  to the lines it explains.
- Describe the result at this head. Review rounds belong in the description's
  collapsed history, not in its visible sections.
- Keep prior-task outcomes in a PR description only when they help review this PR.
  When earlier work is a dependency, link it and briefly explain the relationship.
  Omit unrelated completion reports; retain useful verification and repair history
  for the current PR.
- `description` and `walkthrough` refuse text past the
  [prose limits](https://github.com/shakacode/shaka/blob/main/docs/settings.md#prose_limits):
  long sentences, long paragraphs, or more visible words than the change warrants.
- Split the text, collapse supporting detail into `details`, or link to the code,
  then publish again.
- Record each refusal in the description's review history details: what it reported,
  a quoted passage or the word count, and what you changed.
