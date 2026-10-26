# 0004: Mark the lines that need the closest reading

Status: proposed; awaiting maintainer approval. Nothing here is shipped.
Date: 2026-10-25. Tracks [issue #846](https://github.com/shakacode/shaka/issues/846).

## Context

A Shaka PR description gives one review effort for the whole change, from 1 (read the
description) to 5 (review every line, reproduce it, and ask a second reviewer).
`IntentVerification::REVIEW_EFFORT` renders it under **Change and review**, and
`ReviewEffortFloor` refuses a rating below the highest
[human review floor](../../skills/shaka/references/human-review-floors.md) that the
changed paths match.

Review effort is a level of care for each line, not a yes-or-no on reading code. A PR
often has a few lines that need intense reading and many that do not. One rating either
rises to cover those lines and asks for more care everywhere, or stays low and
understates them. A floor makes this worse: one changed file under
`.github/workflows/` lifts the whole PR to 4.

Two existing tools point at lines but carry no level:

- [Walkthrough notes](../../skills/shaka/references/walkthrough-notes.md) are inline
  comments on the walkthrough review. The command refuses them when the base requires
  conversation resolution, and they cannot sit on a line the diff does not show. They
  also live in the walkthrough, which the maintainer opens after deciding how hard to look.
- Walkthrough `code_links` (`Walkthrough::CodeLinks`) find a range by text in the file at
  the head and refuse missing or ambiguous text, so a range cannot drift onto other code.

The predecessor `shakacode/agent-workflows` (checked at `d85ecea`) has no per-line or
per-path review level to reuse.

Impact and frequency: UNKNOWN. The gap comes from one maintainer comment on
[#825](https://github.com/shakacode/shaka/pull/825#discussion_r4343957784).

## Decisions

1. **A short list beside the PR rating.** Description content gains optional
   `intent.review_focus`: a list of entries, each with `path`, `level`, `reason`, and
   optionally `from` with `to` or `block: true`. `review_effort` stays a whole number, so
   existing content files keep working. Ruby sets no count limit. A fixed cap would be a
   maintainer choice with no default to change, and a setting would add a default, a
   reference entry, and a migration for every repository. The workflow sentence asks for
   a few entries, and a long list is visible to the reviewer it fails.
2. **Ranges are found by text, the way walkthrough code links are.** `from`, `to`, and
   `block` mean what they mean in `code_links`, through the same `LineRange` lookup at
   the PR head the description already reads (`headRefOid`). Without `from`, the entry
   covers the whole file. Line numbers are never accepted: they drift when a later commit
   moves code, and a republished description would then point at the wrong lines.
3. **Ruby refuses entries that cannot help a reviewer.** Publication refuses an entry
   whose `level` is not a whole number above the PR's `review_effort` and at most 5, whose
   `path` is not among the PR's changed files or has no file at the head (a deleted file or
   the old side of a rename), whose text is missing or ambiguous at the
   head, or whose `reason` is empty or more than one line. An entry asks for more care; it
   never lowers the PR rating or a floor. The file check reads each file's `status` and
   `previous_filename` from the pull request file list that publication already fetches:
   a `removed` file and the old name of a rename have no file at the head. The changed-path
   list the floors use cannot answer this, because it holds both names of a rename and no
   status.
4. **Rendered under Review effort, linked to the head.** Each entry becomes one line
   below the Review effort line, highest level first:

   ```markdown
   **Review effort:** 2 of 5, easy: skim the diff.

   **Closer reading:**
   - 4 of 5: [`lib/shaka/merge.rb` lines 40–58](https://github.com/OWNER/REPO/blob/HEAD_SHA/lib/shaka/merge.rb#L40-L58), compares the queue base before submitting.
   ```

   A path with unusual characters shows as "a file whose name is withheld", as the floor
   line already does, because a changed filename comes from the PR author. Its link keeps
   the path percent-encoded, as `CodeLinks` writes it, so no author text reaches the
   Markdown unescaped.
5. **Merge stays as it is.** `merge` and `MergeReviewFloor` read changed paths and
   trusted floors, never the agent's ratings; a PR rated 5 does not hold Auto today.
   `review_focus` follows that rule and holds nothing. A reviewer sees it; the merge
   guard does not.
6. **The checkpoint reads it as part of intent.** The post-implementation packet already
   carries `intent`, so the entries reach the adequacy judge without new plumbing. The
   adequacy prompt says to weigh verification against `review_effort` and any
   `review_focus` level, so a check that never reaches a level-4 range counts as a gap.
7. **Instructions stay short.** `workflow.yml` gains one sentence in the description
   paragraph that names `review_focus` and when to use it: a few lines need more care
   than the rest. If that sentence uses never, must, do not, or only when,
   `enforcement.yml` gains its entry in the same PR. `docs/pr-verification.md` extends
   the existing "How carefully should I review it?" row; no new guide.

## Open question for the maintainer

**May a focus entry satisfy a floor?** Today one file under a level-4 floor raises the
whole PR to 4. A whole-file focus entry at the floor's level on every matching file
would keep that care for those files, so the PR rating could stay lower.

- Recommended: **no, not in this change.** Floors are path-derived so that an agent
  cannot argue its own PR down, and the issue says to keep the PR-wide rating. Shipping
  focus entries first shows whether agents use them well before they can lower anything.
- Alternative: allow it when entries cover every file that sets the floor, at that file's
  level or higher. This touches `ReviewEffortFloor`, a level-4 trust path, and needs its
  own tests for partial coverage and for files that match two floors.

## Alternatives considered

- **Raise the PR rating (no change).** It costs nothing, and the maintainer comment
  is the evidence that it overstates care everywhere else.
- **Give walkthrough notes a level.** Notes are refused on bases that require
  conversation resolution, cannot cover lines the diff does not show, and appear only
  after a reviewer opens the walkthrough.
- **Accept path and line numbers.** Simpler to write, but ranges drift between the
  commit the agent read and the head the description renders, with no refusal.
- **Let a focus level hold Auto.** It only tightens, but `merge` would have to trust
  agent-written description content, which it reads nowhere else.

## Consequences

- One optional content key with refusals and behavioral tests in
  `IntentVerification`'s tests. Ranges use the existing `Walkthrough::LineRange.find`;
  reading a file at the head is shared with `CodeLinks` rather than copied.
- Description publication reads file text at the head when entries name `from`. The
  file check reuses the file list it already fetches; without entries it makes no new
  request.
- `workflow.yml` grows by one sentence, `post-implementation-adequacy.md` by a clause.
  `bin/report-instruction-growth` evidence goes with the implementation PR.
- The checkpoint packet validates intent without a pull request, so there it checks
  only `level` and `reason`; the description publication checks paths and text.
- Older content files publish unchanged. Intent has no unknown-key refusal today, so an
  older installation publishes a description with `review_focus` and drops the list.

## Delivery

After this ADR is approved, one implementation PR delivers decisions 1 to 7 and its
docs row. If the maintainer chooses the floor alternative, it follows as a second PR so
the trust-path change is reviewed on its own.
