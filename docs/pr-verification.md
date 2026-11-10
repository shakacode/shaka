# Review the PR and improve the process

<a id="decide-what-happens-next"></a>

Shaka produces a pull request with an **evidence packet**: an explanation of the
change, checks and review results, visual comparisons when relevant, and what
remains unverified.

Use that record to decide what happens next. Keep it for regular retrospectives
that improve future work, including automatic merges.

<a id="what-the-evidence-packet-gives-you"></a>
<a id="start-with-the-change"></a>
<a id="see-what-needs-your-decision"></a>
<a id="see-whether-human-review-is-needed"></a>
<a id="understand-the-limits-of-verification"></a>
<a id="check-how-review-went"></a>
<a id="check-that-the-evidence-is-current"></a>
<a id="pr-verification"></a>
<a id="read-a-pr-for-your-decision"></a>
<a id="answers-for-your-merge-decision"></a>
<a id="answers-for-your-next-decision"></a>
<a id="current-human-review-rating"></a>
<a id="checkpoint"></a>
<a id="decision-checkpoint"></a>
<a id="evaluation-checkpoint"></a>
<a id="check-the-latest-changes"></a>
<a id="see-a-current-pr"></a>
<a id="start-with-the-recommendation"></a>

## Find what needs your attention

Start near the top of the PR description:

| Look for | What it tells you |
| --- | --- |
| **Summary** and **Intent** | What changed, why, and whether it matches your request. |
| **Risk** and **Risk and review** | How carefully to review, and which code to read first. |
| **Verification** | What was checked and what remains unproven. |
| **Decisions to make**, when present | Questions needing your judgment, with options and a recommendation. |
| **Checkpoint** link | The assessment of whether the result is worth merging, including unresolved concerns. |

See [what each risk level asks of you](reference/pr-record.md#risk-and-review).
Inspect screenshots or try the changed feature when your judgment depends on the
result. Open **Code Review** or **Code Walkthrough** for closer examination.

Evidence should cover the version you're reviewing. Passing checks support a
decision; they do not settle every product choice or prove every claim.

## Walk through the code together

Ask for an interactive tour when you want to understand a PR before deciding:

```text
$shaka Walk me through https://github.com/OWNER/REPO/pull/123 one concept at a time.
```

The agent starts with a short agenda, explains one concept, and pauses for your
questions. Say `next` to continue, or ask to change the depth, revisit a concept,
or skip ahead. Larger PRs get a lightweight coverage map that connects concepts
to changed files and tracks what has been covered.

The tour follows a specific revision and refreshes when the comparison changes.
It complements the published Code Walkthrough and selective notes on the diff.
Finishing the tour does not approve or authorize merging the PR.

<a id="use-the-prepared-merge-message"></a>
<a id="approval-and-attention-labels"></a>
<a id="squash-merge-details"></a>
<a id="merge-queues"></a>

## Give feedback or merge

Explain the result you want in the owning chat. If you comment on GitHub, paste
the comment link into that chat.

Under **Ask**, tell the agent when you're ready:

```text
You can merge.
```

You can also [merge through GitHub](reference/pr-record.md#merge-messages).
Confirm that its commit is the version you reviewed. Required checks and
approvals still apply.

Under **Auto**, the agent merges when the change is ready.

<a id="check-the-cost-of-getting-the-result"></a>
<a id="revisit-a-merged-change"></a>

## Improve the process over time

Regularly ask your agent to examine completed PRs and what happened after merging.
Look for patterns in correctness, review rounds, repeated repairs, token use,
and timing.

Skills such as
[AI Hero's `/retro`](https://github.com/mattpocock/skills/blob/main/skills/engineering/retro/SKILL.md)
and [Poteto's `/reflect`](https://github.com/cursor/plugins/blob/main/pstack/skills/reflect/SKILL.md)
can help turn those lessons into improvements.

<a id="request-changes-or-authorize-merging"></a>
<a id="supporting-reference"></a>
<a id="understand-the-recommendation"></a>
<a id="inspect-visible-changes"></a>
<a id="understand-how-the-change-works"></a>
<a id="understand-what-undoing-the-change-would-require"></a>
<a id="find-feedback-from-people"></a>
<a id="see-which-skills-contributed"></a>
<a id="revisit-an-earlier-direction"></a>
<a id="find-prs-waiting-on-you"></a>
<a id="check-for-steps-before-or-after-merging"></a>
<a id="check-claims-about-speed"></a>
<a id="understand-a-blocked-draft"></a>
<a id="follow-the-review-history"></a>
<a id="reconsider-the-finished-result"></a>
<a id="show-what-a-person-will-see"></a>
<a id="show-what-changed-between-captures"></a>
<a id="notes-on-the-diff"></a>
<a id="when-a-diagram-helps"></a>
<a id="what-a-rollback-undoes"></a>
<a id="see-what-people-said"></a>
<a id="return-points"></a>
<a id="show-whether-it-is-faster-or-slower"></a>
<a id="publish-work-while-a-base-repair-is-pending"></a>
<a id="corrections-after-review"></a>
<a id="keep-the-pr-easy-to-read"></a>
<a id="expect-a-readable-delivery-record"></a>
<a id="change-one-behavior-at-a-time"></a>
<a id="documentation-changes"></a>

For lookup, see [PR record details](reference/pr-record.md),
[usage and cost](reference/usage-and-cost.md), and [feedback and recovery](working-with-shaka.md).
