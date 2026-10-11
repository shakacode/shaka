# Technical evidence guidance replay, #421

This is a manual instruction replay with invented, public-safe evidence, not an
executed bug fix or a model benchmark. The examples show how to apply
[the technical evidence prompts](../../skills/shaka/references/delivery.md#connect-a-technical-fix-to-its-evidence).
`B` and `F` denote hypothetical full base and fix revisions; a real assessment
substitutes actual revisions and links. No test result below claims execution.

## Material bug: streamed response loses an application callback

Replay input: a parser buffers an incomplete multipart boundary and mistakenly
returns before delivering a complete preceding part. A proposed fix delivers that
part before buffering the tail. The parser serves both a browser stream and a
server callback adapter. Evidence supplied to the writer:

- Before implementation, a supplemental probe on B with Node 22 feeds the same
  chunk sequence through parser → server callback; expected two callbacks, got one.
- On F, the same probe gets two callbacks. A committed regression test also
  checks two callbacks through that adapter. It fails on B and passes on F.
- After implementation, the parser/adapter suite passes on F under Node 22.
  The full application suite, browser streaming path, and disconnect behavior
  have not been exercised. No production frequency evidence is available.
- A reviewer flags duplicate delivery after disconnect as a plausible risk,
  without a reproduction. No maintainer has accepted that consequence.

Weak output: “Fixed multipart handling. Tests pass; risk documented. High
confidence.” It leaves reproduction, affected boundaries, and acceptance ambiguous.

Walkthrough output: “The parser's early return drops a complete part when its
chunk also ends in an incomplete boundary. Delivering that part before retaining
the tail addresses the observed callback loss. Link the changed return path and
committed callback regression here. The callback check reaches the server adapter;
it does not exercise browser delivery or disconnect.”

Current assessment output: “B failed and F passed the same callback probe before
and after the fix, on Node 22. The committed regression and parser/adapter suite
also pass on F; suite testing occurred afterward. Link their captured results.
Confidence is supported for callback loss at the server adapter. Browser delivery
and disconnect remain unverified. A duplicate callback could repeat an application
side effect; severity depends on the caller, and likelihood is UNKNOWN. Keep that
risk open for an agent-owned disconnect probe, or decision-needed if a consequential
choice belongs to the maintainer. Documentation alone does not settle it. Reverting
restores the known lost-callback behavior. The next useful check is disconnect
through the server adapter, followed by the browser streaming boundary.”

Link this assessment from the description and walkthrough; reuse the review note
for the disconnect concern. It establishes no readiness, approval, or merge consent.

| Maintainer question | Answer recoverable from the replay output |
| --- | --- |
| Did this reproduce the issue? | Identical chunks, B: one callback, F: two; real output links still required |
| Tested early and through what boundary? | Before-fix probe; parser → server callback; committed regression; suite afterward |
| What else can break? | Shared browser caller and disconnect; potential repeated side effect; rollback restores callback loss |
| What remains uncertain? | Browser/disconnect omitted; frequency and likelihood UNKNOWN; risk remains open without human acceptance |

## Trivial control: correct a documentation typo

Replay input: replace “calback” with “callback” in prose; no code, command, link,
or instruction meaning changes. The writer inspected the diff and surrounding
paragraph. Output: “Corrects a spelling error; the diff and surrounding paragraph
were inspected. No runtime behavior changed, so bug reproduction and integration
testing are inapplicable.” Routine repository checks still follow trusted policy.
No root-cause, blast-radius, or confidence report is added for this control.

## Observed limits

Manual inspection found each of the four questions answerable in the material
example and no blanket ceremony in the trivial control. These are illustrative
instruction outcomes; they do not establish model compliance, real-fix safety,
attention savings, or frequency. Those remain UNKNOWN pending real use.
The reported real example on React on Rails PR #5147 could not be inspected:
the pinned screened comment reader refused its closed PR. No raw comments were read.
