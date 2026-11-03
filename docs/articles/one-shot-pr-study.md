# Choose what still needs your review

Keep human attention on decisions that need your knowledge. A small change to
user documentation can need more judgment than a larger routine code fix.

In a study of 309 merged Shaka PRs, 65 received human feedback after the agent
first called them ready. Of those, 64 changed docs or agent instructions; the
other changed Shaka settings. No code-and-test-only PR received that feedback.
The absence of feedback does not prove correctness or show how closely anyone
read a PR.

Before enabling automatic merging, ask:

```text
Help me choose which changes should always come back to me. Inspect recent
PRs and ask where my knowledge changed the outcome. Propose review floors.
```

Use [human review floors](../settings.md#pr_descriptionhuman_review_floors) to
identify files that need attention, and [Auto's floor limit](../settings.md#mergeauto_max_review_floor)
to bring those PRs back for a merge decision. Size alone is a poor substitute.

## Limits of the study

The study covered PRs merged September 21 through October 20, 2026, in a
repository whose product is largely docs and instructions. Chat logs were
incomplete, and model differences were confounded with when the work happened.
The results do not establish safety for authentication, merge, or other
consequential code.

The [dated study](https://github.com/shakacode/shaka/blob/56f255c3e0b6a75d99ef04666a67d5bb9cac14fa/docs/articles/one-shot-pr-study.md)
contains the classifications, data, and original proposals. It describes that
period, not a guarantee that another project's PRs can merge without review.

<a id="main-results"></a>
<a id="how-each-pr-was-classified"></a>
<a id="what-the-pr-changed"></a>
<a id="size"></a>
<a id="the-agents-own-rating"></a>
<a id="what-people-asked-for"></a>
<a id="implementing-model-and-provider"></a>
<a id="data-and-limits"></a>
<a id="what-this-means-for-automatic-merging"></a>
<a id="run-the-same-study-on-your-repository"></a>

<a id="which-prs-merged-with-no-change-from-a-person-shakacodeshaka-2026-09-21-to-2026-10-20"></a>
