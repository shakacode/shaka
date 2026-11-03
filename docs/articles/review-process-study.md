# Choose review coverage with evidence

A second reviewer can catch problems the first missed. In a study of Shaka's
own PRs, Codex alone reported 35 distinct defects Claude did not report.
A third reviewer added little in a small trial. More reviewers are not always
worth their cost.

Try your existing AI accounts first, then compare what each reviewer uniquely
found and what you actually fixed:

```text
$shaka Study our recent PR reviews. Which reviewers found distinct problems
we fixed, what did they cost, and which checks should we keep?
```

Choose [reviewer coverage](../settings.md#reviewprovider_coverage) based on your
project's evidence. Keep review quality separate from how many findings a model
produces; triaging speculative reports costs attention too.

## Limits of the study

The study covered 350 Shaka PRs created September 19 through October 17, 2026.
Finding classifications and fix outcomes came from the agents' records, without
independent confirmation of every finding. Discussion counts were partial on
four large PRs, and hosted Claude cost was unknown. These results do not establish
which reviewers will work best on another repository.

The [dated study](https://github.com/shakacode/shaka/blob/56f255c3e0b6a75d99ef04666a67d5bb9cac14fa/docs/articles/review-process-study.md)
contains the data, methods, source links, and proposals as recorded on October 17.
Those proposals are historical, not instructions or a statement of current defaults.

<a id="main-results"></a>
<a id="data-and-limits"></a>
<a id="what-goes-into-a-pr"></a>
<a id="hosted-claude-review-githubworkflowsclaude-code-reviewyml"></a>
<a id="local-adversarial-review-the-ledger"></a>
<a id="deepseek-trial"></a>
<a id="current-anthropic-guidance-primary-sources-checked-2026-10-17"></a>
<a id="findings"></a>
<a id="1-the-local-claude-reviewer-is-noisy-but-it-carries-most-of-the-fixes"></a>
<a id="2-the-hosted-claude-review-adds-few-findings-after-local-review-and-its-prompt-goes-against-anthropics-guidance"></a>
<a id="3-shakas-own-review-publications-are-the-largest-single-kind-of-post"></a>
<a id="4-three-hosted-bot-reviewers-overlap"></a>
<a id="5-the-retrospective-procedure-cant-run-this-study"></a>
<a id="run-the-same-study-on-your-repository"></a>

<a id="review-process-study-shakacodeshaka-prs-2026-09-19-to-2026-10-17"></a>
