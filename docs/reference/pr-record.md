# PR record details

Use the [decision guide](../pr-verification.md) for the main reading path.
This reference explains fields and exceptions you may encounter.

## Verification results

In the PR description, **Verification** summarizes the checks and reviews.
Results name the commit they cover. Expand **Evidence and limitations** for
supporting results:

- **Not verified** names a claim or behavior that remains unproven.
- **Setup gaps** names reviewers that could not complete as configured and how
  many completed. A Codex reviewer whose sandbox could not start is identified
  as reading only the diff.
- **Merge limitations** names something that should hold the merge until resolved.

Tests support the behavior they exercised. A review with no findings still has
coverage limits. The agent reports these limits; Shaka does not prove the reports
are complete. See [what is enforced](../workflow.md#what-is-enforced).

The **Code Review** link opens the review record. Check coverage, unresolved
findings, and the number of rounds; repeated rounds can signal work worth
investigating. Detailed findings remain available for later agent analysis.

## Human review

The checkpoint rates each PR's **Risk** as low, medium, or high, with reasons.
Low is meant for auto-merge with a later audit, medium for a person to merge
after a skim, and high for a careful review that starts with the verification.
A change in one of the repository's
[`high_risk_areas`](../settings.md#high_risk_areas) always counts as high.
Under Auto, [`merge.auto_merge_max_risk`](../settings.md#mergeauto_merge_max_risk)
sets the highest rating the agent merges without you; the default is low.

**Closer reading**, under **Intent** when present, links to the code needing
particular attention, each with its reason.

## Checkpoint

Open **Checkpoint**, linked near the top of the PR description, for the assessment
of whether the result solves the problem, earns its maintenance cost, and has
supporting evidence. The written **Code Walkthrough** explains the implementation.

| Label | Meaning |
| --- | --- |
| **Recommendation** | What the task owner proposes doing next. |
| **Recorded decision** | Guidance accepted or acted on under existing authority. |
| **Reviewer recommendation** | The reviewer's view, before the owner records a recommendation. |
| **No recommendation yet** | The owner has not recorded a recommendation for this commit. |
| **Not published yet** | The linked report is not available yet. |
| **Merge after maintainer decision** | A question or concern needs your decision before merging. |

The reviewer's conclusion is **Proceed**, **Simplify/reframe**, or **Do not merge**.
Substantive unresolved concerns hold readiness and Auto even when checks pass.
With **Proceed**, you can explicitly accept a listed concern; the agent records
it under **Concerns recorded as accepted by the maintainer**. Shaka checks that
decisions are recorded, not who made them or whether they are sound. Acceptance
does not override **Simplify/reframe** or **Do not merge**.

The checkpoint also judges verification as **Adequate**, **Adequate, with gaps the
reviewer judged acceptable**, **Inadequate**, or **Cannot judge**. The reviewer's
acceptance of a gap is not yours. With Ask, the verdict informs your decision.
With Auto, **Inadequate** or **Cannot judge** stops merging until you approve that
commit. A recommendation grants no merge authority. See
[checkpoint settings](../settings.md#checkpoint).

## Human comments

When people leave feedback, Shaka highlights it near the top of the PR description
under **Human comments**, with links to comments and responses and what remains
open. The list reflects the agent's last read of GitHub comments. Guidance given
only in chat is not included.

Untrusted comments appear as linked **Unverified** entries without quoted or
summarized content. See [review safety](../workflow.md#trust-model) and
[human-comment settings](../settings.md#pr_descriptionshow_human_comments).

## Before and after merge

When actions outside the code are needed, the PR description includes a **Before
and after merge** section. It names the action, owner, timing, and how to confirm
completion. Merging alone does not configure a service, migrate data, or deploy
the change. See [release responsibilities](../releases-after-merge.md).

## Merge approval

Under Ask, a GitHub **Approve** review also grants merge authority when it comes
from someone you named as a merge approver for the task. Required GitHub approval
still needs an eligible reviewer; chat approval does not replace it. GitHub does
not let PR authors approve their own PRs. Return to the owning chat unless its
handoff names active automatic follow-up.

Under Auto, every reported check must pass; skipped and neutral count as passing.
A job that has not started is unseen, so make a check required if it must always
hold the merge. Failed optional checks return work to you, except one the agent names
as failing on the PR's target branch too ([failures the target branch shares](../working-with-shaka.md#choose-a-merge-policy)). An Auto merge normally
gets the `auto-merged` label; queued merges and failed label writes are exceptions.

If GitHub needs a branch update, the agent revalidates and reviews the new commit.
Your decision carries forward if the approved behavior is preserved. A branch
rule may still require fresh GitHub approval. Changed behavior returns to you.

## Merge messages

A **squash merge** combines the PR's commits into one. Open **Checkpoint** near the
top of the description for the prepared title and body, and copy them into
GitHub's fields. If the checkpoint was explicitly skipped, the agent publishes a
separate message comment. Use the message for the commit you reviewed.
The agent supplies the message when it merges for you.

A **merge queue** provides no message fields. Add the PR to the queue instead.
Its repository settings control the message. Shaka's own merge refuses a queue
that copies the full PR description into Git history, or whose settings cannot
be read. The checkpoint warns you before you add the PR through GitHub.
For squash queues, choose **Default message** for branch commit messages or
**Pull request title** for the PR title.

For ordinary squash merges, choose **Pull request title** under GitHub's
**Settings → General → Pull Requests → Allow squash merging** to start from the
PR title and an empty body.

## Visual evidence

Annotated before-and-after desktop and mobile screenshots help assess UX changes.
Recordings can show a flow and animations. The explanation names what was tested
and what remains unverified. Captures and tests provide different evidence:

| Change | Useful evidence |
| --- | --- |
| Layout, styling, or visible output | Annotated before-and-after desktop and mobile screenshots. |
| Interaction, animation, or timing | A recording, with screenshots where useful. |
| Backend or command-line behavior | Focused tests and concise before-and-after output. |

## Diagrams

A walkthrough diagram explains how the pieces fit together. It does not prove
the change works. A duplicate-refund fix might show both callers reaching one check:

```text
RefundsController#create ──┐
RefundRetryJob#perform ────┴── Refunds.issue
                               ├── RefundPolicy.check      refuses a second refund (new)
                               └── PaymentGateway.refund   reached only after the check passes
```

A smaller change can use a sentence: "RefundPolicy.check now rejects refunds
larger than the original charge." No call order changed, so no diagram is needed.

## Recovery

Reverting code may not undo sent emails, issued refunds, or changed data. Look for
recovery consequences in the walkthrough before merging. The agent writes this
assessment; missing recovery details do not establish that a revert is enough.

A **return point**, labeled C1, C2, and so on in the PR description, connects earlier
human guidance to a code revision. See [revising earlier guidance](../working-with-shaka.md#revise-earlier-guidance-and-try-again)
for recovery limits and how to try another direction.

## Performance and blocked work

For a speed claim, look for a comparison with the previous version, tested
conditions, and a result: faster, slower, no meaningful difference, or inconclusive.
If unmeasured, the PR should say so. Regressions, inconclusive results, or no gain
for an intended speed-up return for repair or your acceptance.

An existing failure can leave unrelated work in a **blocked draft**. The PR should
show the failure without the change and name what happens next. It is not ready
to merge; accepting a known failure does not waive required checks, security,
trust, or repository protection.

For unfinished work and attention labels, use [the task guide](../working-with-shaka.md#find-prs-waiting-on-you).
For measurements, use [usage and cost](usage-and-cost.md) and [timings](timings.md).
