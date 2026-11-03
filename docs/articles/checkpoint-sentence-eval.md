# Test whether a prompt change helps

Before adding more instructions to an AI reviewer, compare what it does with
and without them. A sentence can improve one kind of finding while distracting
from another.

A 30-run Shaka experiment asked the checkpoint reviewer to consider what a
failure would reach and what a revert could undo. The added sentence surfaced
untested paths and irreversible effects. On one shared-helper case, two of five
runs with it missed a gap that all five runs without it found.

To evaluate a change to your review prompt:

```text
$shaka Compare this prompt change on a shared-helper fix, an irreversible
change, and a docs edit. Keep the task and model settings fixed, score the
reports without knowing which prompt produced them, and report the limits.
```

Choose criteria that would change your decision before scoring. Compare actual
findings, missed problems, report length, and cost. More detailed output alone
does not establish a better review.

## Limits of the study

The experiment used one model and effort, three PRs, and one scorer on
October 19, 2026. Criteria were written after the first run, and the scorer also
wrote them. Two or three runs per prompt and case cannot establish a reliable
success rate.

The [full report](https://github.com/shakacode/shaka/blob/main/eval/reports/checkpoint-blast-radius.md)
and [fixtures](https://github.com/shakacode/shaka/tree/main/eval/fixtures/checkpoint_blast_radius)
retain the results and materials. The [dated article](https://github.com/shakacode/shaka/blob/56f255c3e0b6a75d99ef04666a67d5bb9cac14fa/docs/articles/checkpoint-sentence-eval.md)
records the original decision and proposals.

<a id="main-results"></a>
<a id="data-and-limits"></a>
<a id="method"></a>
<a id="findings"></a>
<a id="1-the-sentence-makes-reviewers-state-revert-limits-and-untested-paths"></a>
<a id="2-on-the-merge-path-it-found-the-decision-nobody-tested"></a>
<a id="3-on-a-docs-edit-it-stayed-quiet"></a>
<a id="4-it-can-crowd-out-the-question-of-whether-the-pr-delivers-what-it-promises"></a>
<a id="decision"></a>
<a id="rerun-it"></a>

<a id="does-one-prompt-sentence-change-what-the-checkpoint-reports"></a>
