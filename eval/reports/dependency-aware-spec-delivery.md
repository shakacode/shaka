# Dependency-aware spec delivery evaluation

Issue [#457](https://github.com/shakacode/shaka/issues/457) asks whether a small part of
AI Hero's `implement-spec` skill would improve Shaka delivery. This report holds the
evaluation specification, the fixture, the evidence that needs no model run, and the
decision. No comparison run happened: the issue allows one only after its task, model and
effort, budget, isolation, and delegated work are each authorized, and none was.

## Decision

- **Reject adopting `implement-spec` as shipped.** Three of its steps contradict rules the
  trusted workflow already states. [Where the two disagree](#where-the-two-disagree) lists
  them. This conclusion compares instructions; it needs no run.
- **Inconclusive on the smaller adaptation**, the
  [dependency-aware handoff](#the-smallest-adaptation) described below. Every run
  measurement is UNKNOWN.
- **Recommended next step: do not schedule the run yet.** Record one observation on the
  next real task that arrives with native ticket dependencies: how many tickets could
  start at once, and whether ordering or overlap cost the maintainer attention. In this
  repository that workload is rare. Six of 129 issues carry a native sub-issue or
  blocked-by relationship. The only graph of three or more tickets is
  [#155](https://github.com/shakacode/shaka/issues/155), a chain of three tickets and one
  independent ticket, so at most two tickets could ever start together.

Nothing here adopts, builds, or wires in a dispatcher. No file under `skills/shaka/` changes.

## Pinned revisions

| Subject | Revision |
| --- | --- |
| Upstream skill | [`skills/engineering/implement-spec/SKILL.md`](https://github.com/mattpocock/skills/blob/c612defa9e5cf9372262d0279eb124993ba77b71/skills/engineering/implement-spec/SKILL.md) at `mattpocock/skills` commit `c612defa9e5cf9372262d0279eb124993ba77b71`, blob `183923797ab58f1b3ef09e03bc1f1f203c309f37`; [its guide](https://github.com/mattpocock/skills/blob/f3fc5632f401156837ee3872f14fe33ccf1024ea/docs/engineering/implement-spec.md) at `f3fc5632f401156837ee3872f14fe33ccf1024ea` |
| Shaka baseline | `ce651aabdd1f382a1957ac4bdff451a436c0e7d3`, including its `workflow.yml` and trusted settings |
| Candidate | None exists. The adaptation is a design in this report, not a revision. A run needs it written as a pinned commit first. |
| Predecessor reference | `shakacode/agent-workflows` at `d85eceaecac1b8c4d55a7889a806bd89a612a493` |
| Fixture | [`eval/fixtures/dependency_delivery`](../fixtures/dependency_delivery/fixture.yml) at the commit that adds this report |

## Where the two disagree

| Responsibility | `implement-spec` | Shaka baseline |
| --- | --- | --- |
| Shape of the delivery | Every ticket lands on one integration branch, reviewed at the end | One PR per useful outcome; dependent work waits for its prerequisite to merge; native stacks are out of scope |
| Who integrates | A merger subagent merges each finished worker branch | One owner integrates, verifies, and publishes; workers never publish or merge |
| Review | `code-review` runs once over the integration branch and one subagent fixes its findings | An independent reviewer that did not produce the change reviews each PR head |
| Closing tickets | Tickets are resolved when the run ends | The tracker keeps requirements; a merged PR closes its issue |
| A worker on the wrong base | The worker resets its branch onto the integration branch | Never reset work; rebase or merge and keep every commit |
| Cleanup | Remove every worker worktree at the end | Preserve user work; no cleanup step is defined for delegated worktrees |
| Starting more work | The orchestrator starts every ticket whose blockers have landed | Delegation happens only when the maintainer authorizes it |

The first four rows are the rejection. A combined branch replaces three reviewable
outcomes with one. A merger subagent and a worker-run review remove the single owner and
the independent review. Closing tickets at the end of a run treats a worker's report as
completion.

The upstream guide reports the same weak points itself. Worktrees postpone collisions to
merge time. GitHub's blocked-by count drops only when a blocker closes. The closing review
and fix loop has no stopping rule.

## The smallest adaptation

Shaka already lets an owner delegate to workers in their own worktrees when the maintainer
authorizes it. What it lacks is a rule for choosing which tickets may run together. The
adaptation is one conditional procedure, loaded only when a task's tickets carry native
dependency relationships and delegation is authorized:

1. Read the blocked-by relationships from the tracker. Do not copy them into a new file.
2. A ticket may start when every blocker's PR has merged into the task's base.
3. Before starting two tickets together, compare the files and shared names each is likely
   to touch. If they overlap or the answer is unknown, run them one after the other.
4. Each ticket still ends as its own ordinary PR through the unchanged workflow.

It adds no integration branch, merger, scheduler, ledger, or automatic launch.

## The case

The [fixture](../fixtures/dependency_delivery/fixture.yml) is a Ruby library that prices a
parcel, with three tickets. `insurance` and `customs` are independent. `itemize` is blocked
by both. An operator seeds an evaluation repository from `seed/`, creates the three issues,
and records the two blocked-by relationships with GitHub's own dependency feature.

Both independent tickets need the worth of a parcel's contents, and neither ticket names
the key or its unit. Both also register a rule in the same constant. That produces the two
failures the issue asks for, reproduced by hand at seed revision
`ce651aabdd1f382a1957ac4bdff451a436c0e7d3` plus this fixture:

| Variant | Each ticket alone | Merge | Combined tests | Dependent ticket's example (expects 1500) |
| --- | --- | --- | --- | --- |
| Both edit the shared registry | Passes | Conflict in `lib/parcel_quote.rb` | Not reached | Not reached |
| Each registers from its own file, with different keys for worth | Passes | Clean, exit 0 | Pass | 700 with one key, 1300 with the other |

In the second variant Git, both workers, and the seed's tests all report success. Only the
dependent ticket's requirement that a caller describes a parcel once exposes the collision.
These edits were written by hand to show the collision exists. They are not agent output
and say nothing about how either arm would behave.

### Expected handling

Both arms are graded against the same expectations.

- **A worker fails.** Its branch and worktree stay as they are. The ticket stays open, its
  dependents do not start, and an independent ticket continues. The owner counts the retry
  or takeover as repair work.
- **The base changes under a worker.** The owner fetches the base, rebases or merges the
  worker's branch while keeping every commit, and validates the result. Validation from
  the old base is reused only when one side changed nothing that can affect behavior.
  Overlapping paths, or code changes on both sides, need a fresh run.
- **Cleanup is interrupted.** A worktree is removed only after its commits are reachable
  from a pushed branch or a merged PR. One holding uncommitted or unpushed work is left
  and reported. Running cleanup again finishes the rest. It never forces removal and never
  touches a worktree the task did not create.

The base-change rule borrows test ideas from the predecessor's
[`current-integration-evidence-test.rb`](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/skills/pr-batch/bin/current-integration-evidence-test.rb):
`test_overlapping_paths_require_fresh_integration`,
`test_disjoint_code_on_both_sides_requires_fresh_integration`, and
`test_snapshot_semantic_movement_fails_closed`. Its
[`integration-closeout-contract-test.rb`](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/skills/pr-batch/bin/integration-closeout-contract-test.rb)
supplies `test_worker_head_has_one_bounded_integration_and_publication_owner`. No
predecessor reducer, receipt, or policy engine is reused.

## Run specification

This section is a proposal. Each field marked "needs authorization" is the maintainer's.

| Field | Value |
| --- | --- |
| Hypothesis | With three tickets, reading dependencies and checking overlap first reduces elapsed time or maintainer attention without more integration failures |
| Baseline arm | Shaka at the pinned baseline, one owner, no delegation, three sequential PRs |
| Candidate arm | The same revision plus the adaptation, pinned as one commit |
| Held equal | Seed, tickets, prompt, model, effort, review criteria, Ask merge preference, time and cost limits |
| Task | The three fixture tickets; needs authorization |
| Model and effort | Needs authorization |
| Budget and time limit | Needs authorization. Three PRs with hosted checks will not fit the one-hour default |
| Isolation | Needs authorization. The method follows [the evaluation guide](../../contributing/evaluating-changes.md#simple-default-one-matched-pair) |
| Delegated work | Needs authorization: up to two workers in the candidate arm, none in the baseline |

An arm passes only if all of these hold:

- The merged base returns base 500, insurance 200, and customs 800 for the `itemize`
  ticket's example, and the values sum to the total.
- Each PR stays within the trusted limits of 29 files, 999 changed lines, and 9 commits.
- Each PR head has an independent review that the owner selected, not a worker.
- Each issue closes through its merged PR, and no worker pushes to or merges into the base.

Record for each arm: where the collision was caught (worker, owner, reviewer, hosted
check, or after merge), integration failures, repair work, total usage, elapsed time, and
maintainer attention. Keep failed attempts. A combined branch is not an arm. If one is
built for comparison, report its files, lines, and commits against the trusted limits and
do not merge it.

## Measurements

| Measure | Baseline | Candidate |
| --- | --- | --- |
| Correctness | UNKNOWN, not run | UNKNOWN, not run |
| Integration failures | UNKNOWN, not run | UNKNOWN, not run |
| Repair work | UNKNOWN, not run | UNKNOWN, not run |
| Total usage | UNKNOWN, not run | UNKNOWN, not run |
| Elapsed time | UNKNOWN, not run | UNKNOWN, not run |
| Maintainer attention | UNKNOWN, not run | UNKNOWN, not run |
| Combined-branch review size | Not applicable | UNKNOWN, not built |

## What blocks a run

1. The five authorizations above.
2. [#206](https://github.com/shakacode/shaka/issues/206)'s isolated path has delivered one
   PR per session. The [experiment index](../README.md) records no run with delegated
   workers or a sequence of dependent PRs inside the container. That path needs its own
   qualification before a result could be scored. This issue does not build a replacement.
3. A candidate commit containing the adaptation, kept out of `main`.

## Guarantees

| Guarantee | Baseline | Adaptation | `implement-spec` as shipped |
| --- | --- | --- | --- |
| One owner integrates, verifies, and publishes | Kept | Kept | Lost |
| Independent review of each PR head | Kept | Kept | Lost |
| Bounded PRs within trusted limits | Kept | Kept | Lost when the spec is large |
| Issues close only through merged work | Kept | Kept | Lost |
| Work is never reset | Kept | Kept | Lost |
| Dependencies stay in the tracker | Kept | Kept | Kept |
| Independent tickets can run at once | Not offered | Offered when authorized | Offered |

## Limits of this evidence

- The comparison reads instructions. It does not show how an agent follows them.
- The collision was reproduced with hand-written edits. An agent might avoid it or meet a
  different one.
- The fixture is too small to approach the trusted size limits, so it cannot show where a
  combined branch would exceed them.
- The frequency count covers this repository's native relationships only. Dependencies
  written as prose in issue bodies were not counted, and other projects are UNKNOWN.
- The fixture is public. Once an arm has solved it, a later agent can read that solution.
- Passing this synthetic case would not establish an improvement for real users.
