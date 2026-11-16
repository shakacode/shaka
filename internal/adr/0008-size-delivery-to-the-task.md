# 0008: Let the agent size delivery to the task

Status: accepted on 2026-11-15; not yet implemented.
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

- [ADR 0007](0007-walkthroughs-on-request.md), proposed at the same time, publishes
  walkthroughs only on request by default. This record leaves the walkthrough to it.
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
- The walkthrough. [ADR 0007](0007-walkthroughs-on-request.md) proposes publishing it
  only on request by default, so `merge`, `handoff`, and the checkpoint stop requiring
  it. This design leaves the walkthrough to ADR 0007 while that record is proposed. If
  ADR 0007 is rejected, the walkthrough joins the evidence steps decision 4 covers.
- The final checkpoint ("did we build the right thing?"). Code already accepts a
  skip: `post-implementation run --opt-out REASON` publishes an `opted_out` result, and
  `merge` and `squash-message` accept it for the head. Only prose limits who may opt
  out: trusted instructions or a direct user instruction. Letting the agent opt out on
  its own judgment changes that prose rule (decision 4).
- The opening check. It runs inside `description` whenever its setting is on, so
  skipping it needs a `description` change (decision 4).
- UI captures and speed comparisons. These already run only when the change touches UI
  or page speed. A step that does not apply is not a skip and needs no reason; waiving
  one that applies is a skip.

The opening check runs inside a command, so the agent can skip it only once decision 4's
code ships. The checkpoint skip also waits for
decision 4, because nothing in code yet keeps an opt-out out of the risky areas in
decision 2.

**Bookkeeping runs only when someone will use it.** None of these steps verifies the
change, and no command requires them:

- Run the reviewer startup probe only when the task has a reason to doubt a reviewer,
  such as a new machine. `review run` reports an unavailable reviewer anyway.
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

- a trusted `high_risk_areas` or `medium_risk_areas` path;
- agent instructions as [`review.required`](../../docs/settings.md#reviewrequired)
  defines them, which include every file under `skills/` and `.agents/`, so the
  workflow itself is covered;
- authentication, permissions, releases, deployments, destructive migrations, or merge
  guards (the workflow already sends these to explicit human review);
- anything a person asked to have reviewed in full.

ADR 0007 decides when a walkthrough is published, in these areas too.

The description renders the skips under Evidence and limitations, so the person merging
sees what did not run.

### 3. Skipping an evidence step keeps the merge with a person

A task that skipped an evidence step uses Ask for its merge, even when Auto is set. The
person who merges sees the recorded skips first. Auto still requires the full evidence
it requires today. A skipped checkpoint already blocks Auto, because Auto refuses a PR
without a checkpoint rating. For other skips, `merge --auto` refuses any head with a
skip record. This rule ships with decision 4, because before then the agent can skip
only bookkeeping, which needs no person to see it.

Code enforces Ask only where a skip leaves a trace: a missing or opted-out checkpoint,
or a skip record. Skipping the opening check leaves neither, so recording that skip, and
so taking the merge to Ask, is the agent's rule alone.

### 4. Code accepts a recorded skip, only under Ask

The agent records each skip in a PR comment for the exact head, published by the
account that will run `merge`. That is how `merge` and `squash-message` already read
the checkpoint: this account's latest one for the current head. A new commit needs a
new record, the same way it needs new validation. The description shows the skips, but
code never reads them from the description: a PR's author can edit its body, including
the author of a PR from a fork without write access.

With that record:

- `merge` and `squash-message` keep accepting the existing `opted_out` checkpoint, but
  refuse it for a head in the risky areas of decision 2 unless a person confirmed that
  head, the way `--limits-confirmed-head` works today. Without that refusal, `--opt-out`
  would bypass the limit. Code checks only the trusted path lists there:
  `high_risk_areas`, `medium_risk_areas`, and agent-instruction paths. The agent alone
  enforces the other areas and a person's request for a full review, because code cannot
  tell an authentication or release change from its paths. Ask keeps a person on those
  merges. Outside those areas, this widens today's opt-out authority, which allows only
  trusted instructions or a direct user instruction.
- `description` skips the opening check.

The agent already decides some skips: the workflow tells it to pass `--review-waiver` for
a nit-only follow-up, a prose-only exception, or a head a CI review covered. What is new
is skipping on the agent's judgment of what the change touches. The
[trust model](../../docs/workflow.md#trust-model) permits this: the agent acts for the
maintainer, outside input cannot write a comment as the merging account, and the record
is accepted only on an Ask merge, so the maintainer decides with the skip in front of
them.

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
| Walkthrough | Required; notes optional below three files | On request, if ADR 0007 ships |
| Opening check | Runs | Runs until decision 4 ships; then skipped, with a reason |
| Workflow text loaded | All of it | Gates and the steps that run |
| Merge | A person merges (high risk) | A person merges |

The first, prose-only PR saves the bookkeeping, the probe, and some of the text the agent
reads. The opening check waits for decision 4, and the walkthrough for ADR 0007. Until
the reported session is read, nobody knows whether that matches where its time went. Its time may instead have gone to the
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

- The agent can misjudge what a change touches. Once evidence steps can be skipped, three
  things limit the damage: risky areas keep review and the checkpoint, skips force Ask,
  and the PR shows every skip to the person merging. Before that, the agent skips only
  bookkeeping.
- Decisions 3 and 4 change `merge`, `squash-message`, and `description`, their tests, and the enforcement manifest entries for the changed
  rules. The checkpoint part is smaller than the rest, because it reuses the existing
  opt-out. The cost is still real, and the measured savings are small: the checkpoint's
  median is 44 seconds. So the code waits for a measurement (maintainer decision 4).
- Success means a small config task reaches a merge-ready PR with fewer steps and fewer
  model calls, while every gate above still runs. Before implementation, measure one
  small config task under the current workflow so the comparison has a baseline. Read
  the reported session, if it becomes available, to confirm which steps it spent time on.

## Maintainer decisions

The maintainer accepted every recommendation on 2026-11-15:

1. In a high-risk or medium-risk area, the agent may skip the walkthrough when the
   description explains every changed line. ADR 0007, proposed after this decision,
   would replace this answer: walkthroughs on request by default, and required where a
   repository sets `always`. This answer applies again if ADR 0007 is rejected.
2. Skipping local review stays limited to trivial prose and no-op changes.
3. No setting forbids skips yet. A new setting changes every repository's
   `.agents/shaka/config.yml` through the settings migration flow, so add one only if a
   maintainer asks for it.
4. Delivery order:
   1. a prose-only PR for the bookkeeping part of decision 1 and for decision 5. No
      command checks those steps, so prose alone can change them;
   2. a measured run of a small config task before and after that PR;
   3. the evidence skips, together: decision 2's limits, decision 3's Ask rule, and
      decision 4's code. Ship this only if that run shows the checkpoint and opening
      check still cost enough to justify it.

Still open, to settle before step 3: whether a speed change that finishes with a recorded
unmeasured gap, which the workflow allows today, counts as a skip and so loses Auto.
