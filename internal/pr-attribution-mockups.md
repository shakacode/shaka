# PR attribution mockups

Proposed treatments for identifying Shaka in a PR description. These are design
samples, not shipped renderer behavior. The draft PR presents all six for comparison.
Choose one treatment before changing the renderer.

Each excerpt uses an illustrative summary and placeholder walkthrough text.
The existing agent identity, verification, provenance, and usage remain separate.
Attribution should identify the workflow without suggesting Shaka authored every
line or approved the change.

## A — Small signature beneath the summary (recommended)

Search handles apostrophes without dropping matching results.

<sub>Prepared with <a href="https://github.com/shakacode/shaka/blob/main/docs/getting-started.md">Shaka</a> · <a href="https://github.com/shakacode/shaka/blob/main/skills/shaka/SKILL.md">View the skill</a></sub>

**Code Walkthrough:** _example walkthrough link_

Visible before the details, with reduced visual weight. The name leads to getting
started; the second link answers how the description was prepared. Two links add
some clutter, but serve the two reader goals directly.

## B — Quiet footer

Search handles apostrophes without dropping matching results.

**Code Walkthrough:** _example walkthrough link_

_…verification and expandable details…_

---

<sub>Prepared with <a href="https://github.com/shakacode/shaka/blob/main/docs/getting-started.md">Shaka</a>.</sub>

A familiar signature with one link. Readers who stop after the summary may miss it.

## C — Alongside the walkthrough

Search handles apostrophes without dropping matching results.

**Code Walkthrough:** _example walkthrough link_ · [Shaka workflow](https://github.com/shakacode/shaka/blob/main/skills/shaka/SKILL.md)

Compact and near an existing point of interest. Readers may interpret it as another
review artifact rather than an attribution. It links directly to the instructions.

## D — Plain italic credit

Search handles apostrophes without dropping matching results.

_PR prepared with [Shaka](https://github.com/shakacode/shaka/blob/main/docs/getting-started.md)._

**Code Walkthrough:** _example walkthrough link_

Uses ordinary Markdown and stays readable on small screens. Slightly more prominent
than the small signature, and “PR prepared” describes the broader delivery workflow.

## E — Discoverable explanation

Search handles apostrophes without dropping matching results.

<details>
<summary>Prepared with Shaka</summary>

[Shaka](https://github.com/shakacode/shaka/blob/main/docs/getting-started.md) guides coding agents through verification and PR delivery. [Read the skill](https://github.com/shakacode/shaka/blob/main/skills/shaka/SKILL.md).

</details>

**Code Walkthrough:** _example walkthrough link_

The visible label identifies Shaka; opening it explains the workflow. The links take
an extra click, and another disclosure competes with existing details.

## F — Gentle invitation

Search handles apostrophes without dropping matching results.

<sub>Prepared with <a href="https://github.com/shakacode/shaka/blob/main/skills/shaka/SKILL.md">Shaka</a> · <a href="https://github.com/shakacode/shaka/blob/main/docs/getting-started.md">Try it on your next PR</a></sub>

**Code Walkthrough:** _example walkthrough link_

The clearest invitation to adopt Shaka. Still visually small, but more promotional
than A. The name links to the skill; the invitation links to getting started.

## Link and placement choices

Use one credit per description. Keep verification and the reader's merge decision
more prominent. Do not add a badge, tracking parameter, or repeat the credit in
every section. If implemented, a maintainer should be able to suppress attribution;
this proposal does not yet choose a setting or change its default.

The mockups use canonical GitHub links so the destinations are inspectable. The
published documentation site may be a friendlier getting-started destination;
verify its route before selecting it. A version-pinned skill link offers exact
reproducibility, while the main-branch skill link shows the latest instructions.
The existing execution provenance already records the workflow version.

## Scope and evidence

This PR compares editorial alternatives without changing the formatter or workflow.
Its value is making the choice reviewable in GitHub; conversion and adoption impact
are unknown. Start with A or D rather than adding a configurable layout system.

The current renderer has no visible attribution link outside expandable provenance
and settings. The predecessor's PR-batch skill and writing guide were checked;
no reusable attribution treatment was identified in those sources. No predecessor
code or workflow machinery is imported.
