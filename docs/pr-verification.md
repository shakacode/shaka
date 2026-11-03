# Before you merge

Use your knowledge of the project where an AI cannot: whether the change solves
the right problem, fits your users, and is worth maintaining.

```text
What should I check myself before merging this PR?
```

<a id="read-a-pr-for-your-decision"></a>
<a id="answers-for-your-merge-decision"></a>

## Answers for your next decision

Ask for a demonstration of the outcome you requested. For a search fix, try the
query that failed. For a billing change, confirm the rule against the contract.
A passing test can verify the calculation without establishing the right rule.

If something needs staging, a backfill, or a feature-flag change, agree who does
it and when. Merging alone does not complete those steps. See
[releases after merge](releases-after-merge.md).

<a id="see-a-current-pr"></a>
<a id="start-with-the-recommendation"></a>
<a id="follow-the-review-history"></a>
<a id="check-the-latest-changes"></a>
<a id="change-one-behavior-at-a-time"></a>
<a id="documentation-changes"></a>
<a id="show-what-a-person-will-see"></a>
<a id="show-what-changed-between-captures"></a>
<a id="show-whether-it-is-faster-or-slower"></a>

## Check the evidence

A green job does not establish that the important behavior was tested. Ask:

```text
Which requested outcomes remain untested? Show how the checks would catch a failure.
```

For an interface change, try the preview with realistic data and the devices
your users use. If you cannot try it, ask the agent to demonstrate that path.
Screenshots alone cannot establish that clicking a control works.

<a id="keep-the-pr-easy-to-read"></a>
<a id="expect-a-readable-delivery-record"></a>
<a id="notes-on-the-diff"></a>
<a id="read-the-walkthrough-when-you-need-more-detail"></a>
<a id="when-a-diagram-helps"></a>
<a id="what-a-rollback-undoes"></a>

## Consider what a revert cannot fix

Reverting code cannot recall emails, reverse charges, or restore deleted data
by itself. Before a change with outside effects, ask:

```text
If this fails, who is affected, and what would recovery require beyond reverting the code?
```

<a id="reconsider-the-finished-result"></a>
<a id="decision-checkpoint"></a>
<a id="evaluation-checkpoint"></a>

## Checkpoint

A **Merge** recommendation is advice. You can still reject an approach that
costs more to maintain than its benefit warrants.

Substantive concerns need a fix, evidence disproving them, or your explicit
acceptance. After a **Proceed** verdict, you can say, for example,
"I accept the unknown-frequency concern; merge as is." Check that the recorded
acceptance matches your decision. Acceptance does not override
**Simplify/reframe** or **Do not merge**; those need revision or reassessment.

Under Auto, **Inadequate** or **Cannot judge** verification returns the merge
decision to you. Required checks and approvals still apply.

## Approval and attention labels

By default, you merge on GitHub or approve the agent's merge. An initial "Go"
starts work; it does not grant that later approval. See
[merge choices](working-with-shaka.md#choose-a-merge-policy).

You can name a teammate as a merge approver for this task. Their GitHub
**Approve** then grants Ask authority. Approval in chat cannot replace a
required GitHub review from an eligible reviewer.

When GitHub requires a branch update, your decision carries forward if the
updated change keeps the approved behavior. The agent revalidates and reviews
it. Repository rules may still require fresh GitHub approval. Changed behavior
comes back to you for a new decision.

Use [attention-label searches](working-with-shaka.md#find-prs-waiting-on-you)
to find work waiting on you.

<a id="corrections-after-review"></a>
<a id="publish-work-while-a-base-repair-is-pending"></a>

## Return points

If an approach goes wrong, ask to [revise earlier guidance](working-with-shaka.md#revise-earlier-guidance-and-try-again).
A return point pairs your guidance with preserved work. Ask what can be restored
before rewinding; unsaved work and outside effects may be unrecoverable.

## Squash merge details

Before clicking merge, compare GitHub's current commit with the agent's handoff.
If they differ, return to the agent. Copy the prepared title and body from the
ready **Checkpoint**, or the squash-message comment if the checkpoint was skipped.

### Merge queues

A queue takes no custom message. If its message setting is **Pull request title
and description**, it copies the whole description into Git history, including
WIP Details. Ask the repository maintainer to choose **Default message** or
**Pull request title** instead. The agent refuses to submit to that queue;
GitHub does not prevent you from doing it yourself.

<a id="see-which-skills-contributed"></a>
<a id="see-what-people-said"></a>
<a id="look-up-supporting-detail"></a>
<a id="revisit-a-merged-change"></a>

## Learn from the result

After using the change, compare what happened with the original goal. Tell the
agent what you learned before starting a follow-up. The PR preserves the earlier
reasoning; it does not prove the tests or review were sufficient.

For reporting questions, ask about [cost](reference/usage-and-cost.md) or
[timings](reference/timings.md). For guarantees, see
[what Shaka enforces](workflow.md#what-is-enforced).

<a id="pr-verification"></a>
