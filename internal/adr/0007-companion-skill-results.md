# 0007: Show companion skill results on the PR

Status: design answers accepted on 2026-11-12; build waits for decision 1's trigger.
Date: 2026-11-09. Tracks [issue #1075](https://github.com/shakacode/shaka/issues/1075).

## Context

Some companion skills produce evidence a maintainer could check before merging:

- pstack's `/statechart` checks a TLA+ model (a formal description of the program's
  states) and draws the flow.
- Formal verification skills report each property, its bounds, and any counterexample.
- A harness from `create-verification-skill` captures screenshots and logs.
- pstack's `interrogate` keeps findings that a run proves, each with the command that reproduces it.

A Shaka PR description has two places for that evidence today, and neither checks that the evidence is current:

- **Verification** holds up to three `checks`, at least one once the PR is finished. Each one-line check needs a link or a code
  span (`IntentVerification::EVIDENCE`). Nothing compares the commit a line names with
  the head.
- **Skills used** gives each skill a one-line `contribution` (`SkillsUsed`). It records
  that a skill was applied, not what a run found.

[Companion skills](../../skills/shaka/references/companion-skills.md) already tells the
agent where such output goes: carry the command, commit, result, artifacts, and gaps
into Verification, put a diagram in a `sections` item, and put before and after evidence
in a `details` item. Those items are free-form, so Ruby checks none of the fields.

**Demand is unproven.** The issue says to build this once a real PR uses `/statechart`
or a verification harness, so the format follows real output. On 2026-11-09, a GitHub
search of shakacode PRs for each skill name found:

- No shakacode PR mentions `/statechart`.
- In a private shakacode repository, seven recent PRs mention `create-verification-skill`.
  None of the seven reports a harness run in Skills used.

**Overlap with #1071.** [Issue #1071](https://github.com/shakacode/shaka/issues/1071)
adds a doctor check for duplicate and broken skill installs. That check reads skill
folder names and links only. It resolves no pack or revision, so it offers nothing this
design could reuse. The two changes touch different files.

## Decisions

1. **Wait for real output before building.** Approving this ADR settles the design, not
   the timing. Build it once a real PR uses `/statechart` or a verification
   harness, as the issue says. Until then, the existing companion-skills
   guidance stands, and no code changes.
2. **A separate list, joined to Skills used by skill.** Description content gains
   optional `companion_results`. Each entry describes one run. Its fields are the ones
   companion-skills already asks the agent to carry, plus `checked`:
   - `skill`: the `name` of a `skills_used` record, matched exactly, including case.
   - `source` and `revision`: optional; each is required when the matching Skills used
     records differ in it.
   - `command`: the command the run used, as plain text.
   - `checked`: one line on what the run checked.
   - `result`: one line on what it found.
   - `not_covered`: one line on what the run did not check, or `Nothing.`
   - `commit`: the full SHA the run used.
   - `artifacts`: a list of http or https links, possibly empty.

   An entry joins a skill, meaning one name from one source at one revision, not a single
   Skills used row. Skills used keeps separate rows for the same skill in different
   phases, and all of them name the same skill. An entry normally omits `source` and
   `revision`, and the helper takes them from the matching rows. When two installs
   share a name, or one skill appears at two revisions, the entry names the field that
   tells them apart. The helper renders the list as one collapsed
   `Companion skill results` section, one entry per run. Every field except `command`
   and `artifacts` goes through `PublicationText.summary_text`, including `skill`,
   `source`, and `revision`, after decision 3 matches their raw values. That is the
   escaping Skills used cells get before their table escaping, so HTML an agent copied from a skill's output cannot close the collapsed
   section. Markdown passes through, as it does in Skills used cells.
   The helper wraps `command` in a code span without HTML escaping, because GitHub shows
   entities in a code span literally. Each artifact renders as an angle-bracket link.
   For example, `command: bundle exec rake test` renders as `` `bundle exec rake test` ``.

   These fields are published as written apart from that escaping. The agent removes
   credentials before publishing, as it does for every other description field; Ruby
   does not scan for credentials. Ruby does refuse local absolute paths, as decision 3
   lists.
3. **Ruby checks the shape and the commit, not the truth.** Publication refuses an entry
   in these cases:
   - it lacks `skill`, `command`, `checked`, `result`, `not_covered`, `commit`, or
     `artifacts`, or it has a key outside the list in decision 2;
   - its raw `skill`, with any raw `source` and `revision` it gives, matches no Skills used
     record, or still matches records that differ in source or revision;
   - `command` is empty, more than one line, or contains a backtick or `</`, which could
     end the collapsed section early;
   - `checked`, `result`, or `not_covered` is empty or more than one line;
   - `commit` is not a full SHA;
   - an artifact is not an `http` or `https` URL without spaces or angle brackets;
   - any text field or artifact contains a local absolute path such as `/Users/` or
     `/home/`. This is a new check; local review today redacts such paths rather than
     refusing them.

   These are shape checks. The rendered `command` code span meets the test
   `IntentVerification::EVIDENCE` applies to each Verification check, but neither proves
   that the command ran.

   An entry whose commit is not the head renders with a visible `stale` label. The
   helper computes it each time it publishes the description, against the head it
   reads then, so it is current as of the last publish. When the helper has no head to
   compare, such as a publish without a pull request, the entry shows `head unknown`. The workflow republishes before
   the final handoff; a commit pushed after a publish shows no label until the next one. Ruby does
   not refuse it. Rerunning a model check or harness can be expensive, and a reviewer can
   judge whether a later commit touched what the run checked.
4. **The run's record has one home.** Once the field ships, a companion run's full
   record goes in `companion_results`, in place of the Verification record
   companion-skills prescribes today. A before-and-after comparison keeps its `details`
   item, because its "before" run uses the base commit and would always show `stale`.
   The entry for the "after" run names that item's summary in its `result`. A result that bears on the merge also
   gets one Verification line that summarizes it. That line stays agent-written
   and unchecked: it carries no commit field, so no `stale` label reaches it. The entry it
   summarizes sits one click below and shows the label, which is where a reviewer checks
   currency. The helper does not copy entries into Verification, because the limit of
   three checks is what keeps that section readable. A Mermaid diagram (a chart
   GitHub draws from text) stays in a `sections` item, and the entry's `result`
   names its heading. Neither item has an anchor a link could target, so `artifacts`
   stays limited to URLs.
5. **Links only; the upload route waits.** `artifacts` accepts links only, and this ADR
   adds no uploader. How a screenshot or a diagram rendered to an image gets uploaded is
   left to the implementation PR. The existing [UI evidence publication](../../skills/shaka/references/ui-verification.md#publish-ui-evidence)
   path is scoped to UI changes and folds earlier UI checks, so that PR weighs it against
   a plain comment attachment.
6. **Rewrite the existing guidance, add none.** When the code ships, the "Consume
   verification evidence" sentence in companion-skills that sends the command, commit,
   result, artifacts, and gaps into the Verification record is rewritten to send them to
   `companion_results`, with one summary line in Verification for a merge-relevant
   result. The matching paragraph in `docs/working-with-shaka.md`, which tells readers
   the PR's verification lists the harness command and its results, changes to say
   that the PR's companion results list the command, the commit, what it showed, its
   screenshots or logs, and what it didn't cover, and that a result from an earlier
   commit shows as stale.
   The next sentence, "Shaka's current-head requirements override a companion's
   verdict-reuse policy," becomes: a result from an earlier commit stays listed with a
   `stale` label, and the agent reruns it when a later commit touches what it checked.
   `workflow.yml` gains only `companion_results` in its list of description keys; the
   guidance stays in companion-skills, which loads only when a task uses a companion
   skill.

## Maintainer answers

On 2026-11-12 the maintainer accepted both recommendations the review left open:

- The Verification summary line stays agent-written with no `stale` label, as decision 4
  says. Dropping the line, or having the helper write it from the entry with the label,
  were the alternatives.
- An entry matches Skills used by the raw `skill`, `source`, and `revision` values, and
  the helper escapes them only when it renders.

On 2026-11-13 the maintainer also chose to leave these to the implementation PR:
how older installations treat `companion_results`, the exact local-path rule, the
upload route in decision 5, and whether result text may carry Markdown links and
images.

## Alternatives considered

- **No new field (keep `details` and Verification).** This costs nothing. Ruby can
  check neither the commit nor the link, so a stale or unsupported result can pass as
  current. It stays the answer until decision 1's trigger arrives.
- **Add results to Skills used records.** This uses one list, but a record describes a
  skill and a result describes one run. Two runs at different commits would need two rows
  for the same skill, and the Skills used table would grow columns most rows leave empty.
- **Refuse a name Skills used lists with two sources or revisions.** This is simpler
  than optional `source` and `revision`, but it would forbid reporting the same skill at
  two revisions, which Skills used allows today.
- **Refuse stale entries.** This is stricter, but it forces a rerun after every
  unrelated commit, or pushes agents back to free-form `details`, where nothing is
  checked.
- **Wait for [#1026](https://github.com/shakacode/shaka/issues/1026).** #1026 would bind a
  separately run harness to its commit through `evidence run`. That is stronger
  evidence, but only for a harness the repository runs through a fixed entry point
  beside `validate`. A TLA+ check or an `interrogate` run is a one-off command outside
  that entry point, so the `stale` label serves cases #1026 does not cover. The two can ship in either order.

## Consequences

- One optional content key, one renderer beside `SkillsUsed`, and behavioral tests for
  each refusal and the `stale` label. No setting, so no `defaults.yml` entry or settings
  migration.
- Older content files publish unchanged. Description content has no unknown-key refusal
  at the top level today, so an older installation that receives `companion_results`
  drops it.
- Revision stays agent-reported. [#1027](https://github.com/shakacode/shaka/issues/1027)
  remains the place to make pack and revision countable.
- The `stale` label departs from the companion-skills sentence that current-head
  requirements override a companion's verdict reuse: a stale entry is labeled, not
  refused. Decision 6 rewrites that sentence.
- The commit check compares text with the head. It does not prove the run happened on
  that commit.
- The `stale` label covers the commit only. An artifact link to a UI check that a later
  check folds or retires shows no label on the entry; the reader sees the folded comment
  when they open it.

## Delivery

This ADR merges first as the design record. Once decision 1's trigger arrives, one
implementation PR delivers decisions 2 to 6, and its description links the triggering PR.
