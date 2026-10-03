# Preserve review decisions and later outcomes

Presentation implementation and remaining design for [issue #395](https://github.com/shakacode/shaka/issues/395).
This PR implements compact per-commit review comments, visible retained concerns
and coverage limitations, collapsed evidence, and unchanged-reply suppression.
Coverage excerpts render as attributed literal text; ambiguous HTML coverage shows
UNKNOWN while the complete formatted original remains in history.
The retention and export sections below remain proposals.
[Requirements](requirements.md) owns pilot scope and acceptance. This design
supports its R10 maintenance, R11 evidence, R13 presentation, and R16 recovery
requirements. Issue #395 owns this extension's acceptance checklist; this design
does not complete either checklist or expand the pilot's real-use claims.

## What the current records preserve

Inspected Shaka revision: `36a273c60d92261c2001d38a20dc58368018dbd6`.
Paths below are relative to `skills/shaka/lib/shaka/` unless stated otherwise.

| Surface | Facts retained today | Important gaps |
| --- | --- | --- |
| `local_review/runner.rb` | Base, reviewed head, provider/family, report path, prompt source, criteria ref, requested settings, observed model and usage when available | No stable run/recommendation identity or structured coverage; successful reports are external files |
| `local_review/ledger.rb` | Ordered rounds; serializes writes with a file lock and replaces JSON through rename | No format version or append-only assessment history; no repository/PR identity; no bundled report content |
| `local_review/ledger_batch.rb` | Maps each reporter's original finding number to a shared finding ID; checks counts and consistent collation | A new `record!` replaces the last batch's findings; earlier statements within that batch are lost |
| `local_review/finding.rb` | ID, owner-supplied summary, defect/risk/nit class, fixed/documented disposition, fix SHA, note, reporter number | Remedy and rationale remain in report prose; no actor/time attribution, explicit decision, implementation assessment, or later outcome |
| `local_review/triage.rb` | Associates repeated findings and reporters; checks conflicting outcomes within one head; flags returned fixes | Renders dispositions in the main triage and again beneath a lone reviewer's report |
| `local_review/summary.rb` | Keeps an earlier defect unresolved despite a clean later round or reclassification; sums parseable round usage | Fixed is operational evidence, not recommendation quality; summary totals do not deduplicate overlapping usage |
| `local_review/commit_comment.rb` and `publisher.rb` | One managed comment per reviewed head, original reports, previous fixes explaining a new commit; preflights rendering and commit links | Current per-head rendering does not list all earlier unresolved defects; reports and dispositions can appear twice |
| `local_review/history.rb` | Collapses earlier owned comments and links the latest; retains closing attestation and human annotations | GitHub comments are editable/deletable; collapsing is not durable retention or a finding-resolution decision |
| `usage/records.rb` and `publication/usage_details.rb` | Source/response identity, contribution and commit mapping, completeness, time range, native columns; replaces overlapping snapshots where supported | Usage attribution cannot prove recommendation causality; ambiguous/legacy overlap remains uncertain |

`test/local_review_comment_test.rb`, `test/local_review_triage_test.rb`,
`test/local_review_batch_test.rb`, and `test/local_review_history_test.rb`
exercise these behaviors. Their fixtures do not establish retention after
worktree cleanup or recommendation quality after merge.

This table describes the inspected baseline. The presentation change addresses
duplicate dispositions and earlier unresolved findings, adds explicit coverage
limits for new runs, and marks legacy coverage unknown. It does not recover
history that the baseline ledger already overwrote.

The ledger's location outside a checkout protects it from checkout removal only
if its directory survives. A report in a temporary directory can disappear
independently. A report hash detects a change but cannot recover its content.

## Compare the maintainer views

[PR #391's published review](https://github.com/shakacode/shaka/pull/391#issuecomment-5950105896)
has four runs, one fixed finding, and eight documented findings. Its opening
nine-column table precedes the outcome. Triage appears before the reports;
generated dispositions also appear inside individual reports.
Coverage limitations appear inside the collapsed reports.

That record demonstrates presentation duplication. It does not establish that
any recommendation caused an unnecessary or harmful change. In particular,
`documented risk` does not establish acceptance or an evidence-backed rejection.

Proposed visible excerpt of that evidence, without inventing dispositions:

> **Local review · 2beb795 — no new findings in the final round**
>
> **Coverage:** Reviewers reported inspecting the supplied diff only. Unchanged
> source and test execution were outside the reported coverage.
>
> **Unclassified remaining risks:** Findings 2 and 3 have legacy `documented`
> dispositions. Their recorded explanations remain available for maintainer review.
>
> ▸ Review evidence and history
>
> Usage: link to this PR's consolidated usage report.

This is a presentation example, not a new readiness judgment on that PR.
Show required action only when evidence supplies one. Keep unresolved defects,
decisions, significant risks, stale evidence, and returned findings visible.
Material legacy ambiguity stays visible until explicitly assessed; a renderer
does not infer settlement from a note or a clean final review.
In the presentation-only slice, keep every legacy documented defect and risk
visible. The six other documented findings in this example are explicitly nits
in the original record and move into history without a recommendation-quality
judgment. This conservative interim view cannot settle legacy risks; attributed
assessments become available in the history slice.

Render each finding's current disposition once, either in the current view or
the history disclosure. Earlier decisions remain historical events beneath that
disclosure. Preserve original reports verbatim in the private bundle. Public
history contains marked, redacted copies when privacy requires it; retain source
identity and availability without publishing private content. Original source
material may naturally repeat a claim, but generated disposition prose appears once.
Use one outer disclosure with specific nested labels for reports and execution
metadata. Group identical settings with run IDs and retain exceptions.

The current head's view draws unresolved findings from the complete ledger,
including earlier rounds. Per-head comments remain retrievable historical views.
Keep the attestation last and preserve rendering validation. Missing evidence
affecting confidence stays visible; routine unknown metadata and empty sections
do not. Review comments link to consolidated PR usage instead of summing it again.

Update the managed comment for its head. An unchanged body causes no write;
record enrichment and settled corrections do not create notification comments.
Preserve existing actor screening and human-authored text. The publication path now skips writing an identical owned reply after trust and
rendering checks.

## Smallest useful extension

Recommendation: extend the existing ledger with versioned, attributed events and
a bundle of its source evidence. Keep current rounds and finding fields as the
operational projection while existing review and merge guards continue to work.
Do not build another ledger, reducer framework, service, or reward policy.

The cheaper alternative is a manual assessment in a finding's note, with evidence
and commit links. It suffices for an isolated discussion, but replacing the note
loses its prior value. It cannot reliably distinguish separate remedies, replay
corrections, or export evidence available at different times. Prototype the event
shape against the examples below before committing to a broader command interface.

Proposed representation, subject to implementation review:

- A ledger version and repository/task context scope stable finding, run, and
  recommendation IDs. Existing finding IDs remain local to that context.
- A recommendation names its originating run, reporter number, report excerpt
  or bundled source reference, claimed class/severity, remedy, and justification.
  Owner interpretation is separate. Two remedies for one problem get separate IDs.
- An event has a caller-stable ID, actor and role, occurrence and recording times,
  applicable revision, subject IDs, rationale, and evidence references. Explicit
  relations identify alternatives, duplicates, corrections, and superseded events.
- Events separately record problem validity, decision, action taken, recommendation
  assessment, implementation assessment, and current attention. An implementation
  link names commits and patch/line references, deviations, and attribution confidence.
- Missing evidence is `unknown`, `unavailable`, or `redacted` with provenance.
  Source privacy is recorded; a reference does not authorize disclosure.

Append events under the existing ledger lock, rereading before each write.
Identical retries with the same event ID are no-ops; different payloads with that
ID fail. Corrections append a new ID referencing the earlier event. Conflicting
assessments remain distinct; neither recording order nor the actor's role alone
silently resolves disagreement. An explicit, attributed resolution supplies the
current view. Validate references and dimensions before persisting anything.

Readers accept unversioned ledgers as legacy without assigning new meanings.
First mutation preserves the original snapshot and records the migration once.
Old `fixed` records identify a reported implementation SHA, not proof of correctness.
Old `documented` records remain ambiguous. Missing actor, time, remedy, and outcome
stay unknown. Unknown future versions fail rather than being silently downgraded.
An older writer must not rewrite a versioned ledger; compatibility needs a tested
writer-version refusal or explicit upgrade procedure before the format ships.

## Retain and recover existing evidence

Propose a private, task-scoped directory outside disposable checkouts and temporary
storage, selected through the existing ledger path. Its single ledger references
relative report files and captured prompts/criteria, with content hashes.
Copy successful source files before committing their ledger references; a failed
copy leaves no success record. Use private directory/file permissions.
Orphan files after interrupted writes are harmless; retries reuse matching content.

The portable bundle contains this ledger and its referenced evidence. Preserve
reviewed revisions through reachable Git references or an included Git bundle
when unpublished commits would otherwise disappear. Missing objects are explicit
and cannot become accessible merely by linking their SHAs. Bundle verification
checks references, hashes, and recoverability after the source worktree and its
temporary reports are removed. Historical missing content remains unavailable.

Retain the bundle through normal worktree cleanup and optional post-merge
reassessment. No automatic expiry, background collector, or completed-task wakeup
is needed. Its owner handles deliberate deletion and backup; the product makes
that retention limit clear. Reassessment opens the same bundle, records the
observed revision and later evidence, then updates the same managed report as
needed. Use [human checkpoints](../skills/shaka/references/return-points.md) for
human steering and recovery context instead of duplicating snapshot machinery.

Public rendering/export uses an explicit public-safe projection. Authorized
private source content stays in the private bundle. Strip credentials, private
links, and local paths from public output, replacing them with availability and
provenance markers. Raw report content remains untrusted data in every projection.

## Synthetic outcome chains

All identities, revisions, dates, actors, tests, and outcomes in this section are
synthetic specification examples. They make no claim about PR #391 or production.
They are future behavioral fixtures, not tests or records already accepted by Ruby.

### Accepted removal later shown harmful

Task `S1`, finding `F1`, recommendation `R1`, review run `V1`:

| Event | Recorded evidence and separate judgments |
| --- | --- |
| E1 at A, 2026-09-01 | Reviewer V1 reports a duplicate-write defect and recommends removing the retry. Its diff-only report and prompt are retained. Problem validity is initially uncertain. |
| E2 at A, 2026-09-02 | Task owner accepts R1 because repeated writes appear possible; decision is implement. The owner's rationale is separate from V1's claim. |
| E3 at B, 2026-09-03 | Owner records that B removes the retry as proposed, explicitly linking R1 to that patch. Attribution is declared direct, rather than inferred from time. |
| E4 at B, 2026-09-03 | A test observer records the passing test set; V2 reports no new findings with diff-only coverage. Recommendation and implementation quality remain unknown. |
| E5 observed at B, 2026-09-04; recorded 2026-09-06 | Maintainer cites the existing idempotency guard and a reproducible transient-error regression. The original duplicate-write claim is refuted; R1 is harmful. B implemented R1 correctly. Attention is action required. |
| E6 at C, 2026-09-07 | Maintainer links the corrective patch restoring the retry, regression validation, and E5. Attention becomes no current action; E2 acceptance and E5 harmful assessment remain unchanged. |

While E5 is unresolved, show the regression and corrective action before history.
After E6, collapse the settled chain. A reader can still recover exactly which
recommendation led to B, who accepted it, and what later evidence contradicted it.
Export of A's input excludes E2–E6: future evidence is never original context.
No clean round, passing test, or merge assigns a positive quality label to R1.

### Other fixture cases

| Case | Required evidence and expected distinction |
| --- | --- |
| S2: correct finding, excessive remedy | Reviewer identifies a confirmed missing nil guard but proposes replacing the parser. Owner implements replacement; maintainer later cites equivalent coverage from a guard and observed maintenance cost. Problem confirmed; recommendation excessive for the benefit; implementation correct. |
| S3: correct recommendation, defective implementation | Reviewer proposes atomic rename to prevent partial files. Owner links a patch that mistakenly renames across filesystems; failure reproduces. Recommendation supported; implementation defective; corrective patch recorded separately. |
| S4: incorrect recommendation declined | Reviewer claims an escaping bug; owner supplies a counterexample test and declines with evidence before any patch. Problem refuted; recommendation unnecessary; action not attempted. No invented implementation commit. |
| S5: conflicting assessments | Two attributed assessors disagree about R1 with different evidence. Neither is overwritten. Attention is decision required until a recorded resolution names the disagreement and rationale. Export keeps both judgments. |
| S6: changed requirements | Recommendation was supported under requirement Q1 and implemented correctly. Later Q2 removes that requirement; a replacement follows. Preserve the Q1 assessment and append the Q2 superseding decision; do not infer that the original remedy was harmful. |

For every case, also exercise missing source material and uncertain attribution.
Two remedies for one finding and repeated reports of one remedy remain distinct
from multiple successful fixes. Recovery and retry tests accompany implementation.

## Export evidence before evaluating rewards

Propose one bounded JSON document per bundle, with an export version, context,
ordered runs, findings/recommendations, and ordered events. It is simpler than
JSONL when cross-references and a complete snapshot need validation together.
Fix deterministic ordering and preserve recorded event IDs; exporting generates
no timestamps or new IDs. Repeated exports of the same records are byte-identical.
Reject unsupported versions and incomplete cross-references; identify unavailable
content explicitly rather than silently dropping records.

Keep original input, reviewer assertions, owner decisions, observed validations,
and later human judgments separately addressable. Include no-change and
inconclusive cases. Preserve context grouping and duplicate/alternative relations
for evaluation splits across related PRs and revisions. Deduplication does not
erase individual reports or turn repeated assertions into independent successes.

No numeric rewards, training uploads, or provider integration ship here. A later
reward policy requires its own version, evaluation, and human decision. Outcome
absence stays unknown. These records alone establish neither causality nor
precision/recall, and no optional label collection reopens completed delivery.

## Delivery boundaries and remaining acceptance

1. This PR: inventory, examples, and presentation implementation with one disposition projection, complete-ledger
   unresolved findings, visible coverage, grouped history, unchanged-write suppression.
   Verify real GitHub rendering, attestation parsing, and legacy ambiguity.
2. History/retention PR after presentation: validated append-only
   events, compatibility, relative bundled reports, post-merge reassessment, and
   cleanup recovery. Keep changes with their failure/concurrency tests.
3. Export PR after the record representation: deterministic public-safe export
   and executable versions of all six synthetic chains, including retry/conflict cases.
4. Real-use evaluation on the original issue: inspect clarity and reconstruction
   effort; retain a genuinely reconsidered recommendation when it occurs.

The presentation precedent comes from predecessor revision
`d85eceaecac1b8c4d55a7889a806bd89a612a493`:
[summary template](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/skills/address-review/references/templates.md)
and [template tests](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/skills/address-review/bin/address-review-summary-template-test.rb).
Reuse its compact outcome and collapsed evidence idea. Do not import its workflow
contracts, state snapshots, tracking receipts, or test-by-wording approach.

Observed duplication justifies a small presentation change. Event validation,
compatibility, recovery, and export add real maintenance cost; implementation
review should reconsider that cost using the manual-assessment alternative.
Frequency of mistaken recommendations, attention savings, and reconstruction
improvement are unknown. A synthetic harmful case tests preservation without
providing real-use acceptance. Keep #395 and the pilot's real-use acceptance open.
