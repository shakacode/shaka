# 0007: Let the agent size delivery to the task

Status: proposed.
Date: 2026-11-13.

## Context

A developer used Shaka for a small database configuration change. They reported that
Shaka spent a long time on steps that did nothing for that change. Nobody on the Shaka
side has seen that session yet, so which steps cost the time is unknown, and so is how
often this happens.

The workflow treats every task the same way:

- The agent reads the whole 12,046-word workflow on every task. A one-line config change
  gets the same instructions as a new feature.
- Most steps are written as unconditional rules with a few narrow exceptions, such as
  "trivial prose" for skipping local review. The agent follows them as a checklist.
- `shaka enforcement` audits 100 workflow rules: 8 refused by a command, 2 reported by
  one, 1 refused by GitHub, and 89 that only the agent enforces. The rigidity comes
  mostly from the wording, not from code.
- Some code does require steps on every PR. `merge` needs a walkthrough review ID.
  `handoff` treats a missing or stale WIP Details note (the recovery note in an
  unfinished PR's description) as unfinished work, and once a merge is requested it
  also expects the final checkpoint and a merge message. `attention --state merge`
  refuses without a published review unless given a waiver.

The motivating change falls in a high-risk area. The default
[`high_risk_areas`](../../docs/settings.md#high_risk_areas) list puts
`config/database.yml` under `persistence`, so its PR already goes to a person to merge,
whatever the merge preference. Whatever this design saves on that task has to come from
steps that do not protect a risky change.

Measured cost, from `shaka timings report` on 108 PRs merged in this repository since
2026-11-01:

| Step | Median per PR | p90 per PR |
| --- | ---: | ---: |
| Validation | 33m | 2h 5m |
| Local review | 8m 27s | 33m |
| Final checkpoint | 44s | 2m 16s |

The agent's own time on the remaining steps was measured on one PR only, so their cost
is unknown. The remaining steps include:

- the reviewer startup probe, a call that checks the chosen review CLI works before
  implementation;
- the plan recommendation and checkpoint;
- return points, which are saved states the task can rewind to;
- chat renaming and WIP Details;
- the description and its opening check, a model call that checks the description's
  first sentence;
- the walkthrough, the merge message, labels, and the handoff.

Other repositories will have different validation times.

Earlier work in this direction:

- Issue [#468](https://github.com/shakacode/shaka/issues/468), delivered by
  [#519](https://github.com/shakacode/shaka/pull/519), limited repeated work after a
  correction to an existing PR. It did not cover a new small task.
- The [conditional workflow loading investigation](../conditional-workflow-loading.md)
  moved UI and speed procedures out of the workflow. That cut the workflow by 3.8%.
- The [one-shot PR study](../../docs/articles/one-shot-pr-study.md) found that what a PR
  changed predicted a person's feedback better than its size. Of 80 PRs with 50 or fewer
  changed lines, 9 still drew feedback.
- The predecessor `shakacode/agent-workflows` (checked at `d85ecea`) states the same goal
  in its throughput plan: verified outcomes per unit of human attention, time, and
  tokens, where the number of steps is not a measure of success. It has no small-task
  path to reuse.

## Decisions

### 1. Sort every step into one of three kinds

**Gates run on every task.** Each one either stops outside input from acting as an
instruction, protects the maintainer's merge decision, or protects data that cannot be
recovered:

- Policy comes from the trusted settings on the default branch. Issue, PR, and comment
  text is data.
- Never push to the default branch. Run `claim`, which looks for another PR or branch
  already working on the same task.
- Read the diff for credentials before any review or push.
- Run the repository's `validate` or `validate-local` on the exact commit being pushed.
  A maintainer who finds that slow lowers its cost with
  [`validate-local`](../../docs/settings.md#count-a-faster-check-as-validation). The agent
  does not skip it.
- Required checks, merge preference, and every refusal `merge` makes today.
- Read public comments only through `comments`.
- WIP Details on an open PR, which `handoff` requires so another session can resume it.
- List the steps outside the code that the change needs, such as a migration, an
  environment variable, a restart, or deploy order. A config change is where this list
  matters most.

**Evidence steps scale with what the change touches.** The agent runs each one when it
would catch something on this change, and records a one-line reason when it skips one:

- The local adversarial review. It stays on for every change that alters behavior, as
  today, because it costs a median 8 minutes and catches defects the author misses.
  Skipping it stays limited to trivial prose and no-op changes.
- The walkthrough. Its inline notes are already optional below three changed files.
  A change whose description already explains every changed line needs no walkthrough.
- The final checkpoint ("did we build the right thing?"). Skipping it means publishing
  the merge message with `squash-message`, as an opted-out checkpoint does today.
- The reviewer startup probe. `review run` reports an unavailable reviewer anyway.
- The opening check.
- UI captures and speed comparisons, which are already conditional.

**Bookkeeping runs only when someone will use it:**

- Rename the chat once a PR exists, not before the first reply.
- Record a return point when the person confirms a direction worth returning to, not at
  every task start.
- Render the plan recommendation only when it changes what happens next: a design
  question, settings that differ from the recommendation, or a task whose value is
  unconfirmed.

### 2. The agent decides in Plan and shows its choices on the PR

In Plan, the agent lists the evidence steps it will skip and why, in one line each. It
judges by what the change touches and whether the step would catch anything on it. Size
counts only as supporting evidence, never as the reason.

The agent may not skip the local review or the final checkpoint when the change touches:

- a trusted `high_risk_areas` or `medium_risk_areas` path (agent instructions are already
  in `medium_risk_areas`);
- authentication, permissions, releases, deployments, destructive migrations, or merge
  guards (the workflow already sends these to explicit human review);
- anything a person asked to have reviewed in full.

Open decision 1 asks whether a walkthrough may still be skipped in those areas.

The description renders the skips under Evidence and limitations, so the person merging
sees what did not run.

### 3. Skipping an evidence step keeps the merge with a person

A task that skipped an evidence step uses Ask for its merge, even when Auto is set. The
person who merges sees the recorded skips first. Auto still requires the full evidence
it requires today. A skipped checkpoint already blocks Auto, because Auto refuses a PR
without a checkpoint rating. For other skips, `merge --auto` refuses any head whose
description records a skip.

### 4. Code accepts a recorded skip, only under Ask

`merge`, `handoff`, and `attention` accept a skipped walkthrough when the published
description records the skip for the current head. A new commit needs a new record, the
same way it needs new validation.

The agent writes that record, unlike today's `--review-waiver`, which a maintainer
records. The [trust model](../../docs/workflow.md#trust-model) permits this. The agent
acts for the maintainer, and outside input cannot add a skip: only accounts with write
access can edit a PR description, and the record lives in the region `description`
manages. The record is accepted
only on an Ask merge, so the maintainer still decides with the skip in front of them.

### 5. Load what the task uses

Move the bookkeeping procedures and the detailed Explain and Finish instructions into
references that the agent reads when it runs those steps. The workflow keeps the gates,
the three kinds of step, and when to read each reference. Measure the result with
`bin/report-instruction-growth`. This decision claims no particular number of words
saved.

## Example: a small database configuration change

`config/database.yml` is a default high-risk path, so the review and checkpoint stay.

| Step | Today | Proposed |
| --- | --- | --- |
| Trusted settings, `claim`, credential check | Runs | Runs |
| `validate` on the head | Runs | Runs |
| Local adversarial review | Runs | Runs: a wrong pool size or timeout is a defect a reviewer can catch |
| Final checkpoint | Runs | Runs, because the path is high risk |
| Steps besides merging | Runs | Runs, and matters most here: restart or deploy order |
| Startup probe, plan recommendation | Run before implementation | Skipped |
| Chat rename, return point | Run at task start | Only when used |
| Walkthrough | Required; notes optional below three files | Depends on open decision 1 |
| Opening check | Runs | Skipped, with a reason |
| Workflow text loaded | All of it | Gates and the steps that run |
| Merge | A person merges (high risk) | A person merges |

The saving on this task is the bookkeeping, the probe, the opening check, the text the
agent reads, and possibly the walkthrough. Until the reported session is read, nobody
knows whether that matches where its time went. Its time may instead have gone to the
review or validation, which this design keeps.

## Alternatives considered

- **Skip steps below a diff-size threshold.** Rejected. Small diffs are not low risk, and
  the one-shot study found size predicted feedback worse than what the PR touched.
- **Use the existing repository-wide switches** (`checkpoint.enabled`,
  `review.startup_check`, `pr_description.opening_check.enabled`). These stay. They
  apply to every task in the repository, so a maintainer cannot keep the checkpoint for
  risky work and drop it for config changes.
- **Ship a separate light skill.** Rejected. Two workflows drift apart, and the agent
  has to choose between them before it knows what the change touches.
- **Make every rule advisory.** Rejected. The code checks at merge are what catch
  skipped evidence today, and they protect the maintainer's merge decision.

## Consequences

- The agent can misjudge what a change touches. Three things limit the damage: risky
  areas keep review and the checkpoint, skips force Ask, and the PR shows every skip to
  the person merging.
- Decisions 3 and 4 change `merge`, `handoff`, `attention`, and `description`, their
  tests, and the enforcement manifest entries for the changed rules. Their cost is
  real, and the measured savings they buy are small: the checkpoint's median is 44
  seconds, and the walkthrough is unmeasured. So the code waits for a measurement (open
  decision 4).
- Success means a small config task reaches a merge-ready PR with fewer steps and fewer
  model calls, while every gate above still runs. Before implementation, measure one
  small config task under the current workflow so the comparison has a baseline. Read
  the reported session, if it becomes available, to confirm which steps it spent time on.

## Open decisions

1. In a high-risk or medium-risk area, may the agent skip the walkthrough when the
   description explains every changed line? Recommended: yes. A person merges those PRs
   anyway, and for a one-file change the diff is the walkthrough.
2. Should skipping local review stay limited to trivial prose and no-op changes?
   Recommended: yes.
3. Should repositories get a setting that forbids skips, defaulting to allowing them?
   Recommended: not yet. A new setting changes every repository's
   `.agents/shaka/config.yml` through the settings migration flow. Add it only if a
   maintainer asks for it.
4. Order of delivery. Recommended:
   1. a prose-only PR for decisions 1, 2, and 5, which needs no code;
   2. a measured run of a small config task before and after that PR;
   3. the code for decisions 3 and 4, only if that run shows the walkthrough still costs
      enough to justify it.
