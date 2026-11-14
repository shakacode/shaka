# 0007: Publish code walkthroughs on request

Status: proposed.
Date: 2026-11-13. No issue; the maintainer raised it in a Shaka task chat.

## Context

[R4](../requirements.md) calls for a conceptual code walkthrough published as a
commit-bound COMMENT review. The workflow's Explain phase publishes one before every
merge. The merge gate (`merge --walkthrough`) and the ready checkpoint require one for
the current head. `handoff` owes one once merge is requested, or when this account's
walkthrough explains an older head. A change to three or more files also gets inline
walkthrough notes, including a **Start here** note.

The maintainer reports that the walkthroughs have not been useful. The record agrees.
The last 40 merged PRs (#1114 to #1171, measured 2026-11-13) show:

- **Every PR had a walkthrough.** One changed 2 lines and another changed 4. Each PR's
  walkthrough was republished about twice on average, up to five times.
- **Most PRs were small.** 26 of the 40 changed fewer than 176 lines.
- **No note was answered.** The 40 PRs carried 103 walkthrough notes. None got a reply,
  from a person or an agent. That shows the notes started no conversation, not that
  nobody read them.
- **The walkthrough repeats the description.** In #1120, the walkthrough's opening and
  its **Why** section restate the description's Summary and Intent. The remaining
  sections retell the diff, mechanism by mechanism, with links.
- **It costs upkeep.** Open issues #1148, #1175, and #1176 track walkthrough bookkeeping.
  #1173, merged during this design, added labels to inline walkthrough comments.

Method: `gh pr list --state merged --limit 40` gave the PRs. For each one, the reviews API
gave the reviews whose body contains `Code Walkthrough`. The review comments API gave the
inline comments whose `pull_request_review_id` matches one of those reviews (the notes).
Replies are the comments whose `in_reply_to_id` names a note.

Published research points the same way:

- **Context helps reviewers who don't own the code.**
  [Bacchelli and Bird (ICSE 2013)](https://web.eecs.umich.edu/~weimerw/2018-481/readings/codereview.pdf)
  found that understanding a change is the reviewer's hardest need. Reviewers who don't
  own the files rely on the description; owners go straight to the code. Here the
  maintainer owns the code and is the only reviewer, which is the case where a
  walkthrough helps least.
- **Reading order matters for large changes.**
  [Fregnan et al. (FSE 2022)](https://arxiv.org/abs/2208.04259) found that files shown
  later got less scrutiny. [Gonçalves et al.](https://arxiv.org/html/2503.21455v1) is a
  2025 preprint that observed 25 reviews in a think-aloud study. Its reviewers read
  linearly up to about 176 changed lines and used several strategies beyond that,
  often starting from the core of the change. The study observed behavior; it did
  not test an intervention.
- **Sparse "why" comments are common advice, not measured evidence.**
  [GitHub Docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/getting-started/helping-others-review-your-changes),
  [Red Gate](https://www.red-gate.com/simple-talk/development/dotnet-development/the-zen-of-code-reviews-pre-review-comments/),
  and the [Cal.com handbook](https://handbook.cal.com/engineering/self-reviews) recommend
  that authors comment on their own PR at surprising spots, such as a rejected
  alternative or a caveat. No controlled study isolates the effect.
- **Agent-written PRs call for different review evidence.**
  [Simon Willison](https://simonwillison.net/2025/Dec/18/code-proven-to-work/) asks for
  proof in the PR that the code works.
  [Addy Osmani](https://addyosmani.com/blog/code-review-in-the-age-of-ai/) proposes a
  "PR contract" of intent, evidence, risk, and one or two focus areas. Both concern
  intent and verification rather than a tour of the code.

Shaka already covers intent and verification. The description carries Intent,
Verification, and `review_focus` ([ADR 0004](0004-review-focus.md)), and the checkpoint
judges whether the result fits the task. The walkthrough adds a code tour that this
maintainer does not read closely on small PRs.

The predecessor `shakacode/agent-workflows` (checked at `d85ecea`) did not publish
walkthroughs by default. Its `$pr-walkthrough` skill ran when a person asked to
understand a PR. Nothing there can be reused as code; this ADR adopts its default.

Impact beyond this repository is UNKNOWN. The sample is one repository with one
reviewer who owns the code. Teams whose reviewers did not write the code benefit more,
so the old behavior stays available as a setting.

## Decisions

1. **A setting chooses when a walkthrough is published.** `walkthrough.publish` takes
   `on_request` (default) or `always`. Under `always`, everything works as it does now.
   Under `on_request`, the agent publishes a full walkthrough only when someone asks for
   one in the task, the PR, or the chat. The interactive tour stays on request in both
   modes.
2. **Reviewer notes replace the routine walkthrough.** Under `on_request`, the agent may
   publish a few inline notes as a COMMENT review. The helper writes its one-line body,
   naming the commit and saying it is not an approval. A note goes where a reviewer
   would ask why: a rejected alternative, a non-obvious constraint, a risky spot, or a
   mechanical move to skim. A PR with nothing surprising gets no notes. The
   three-files and **Start here** rules apply only to a full walkthrough.
3. **Gates require a walkthrough only when one is due.** A walkthrough is due in three
   cases:
   - under `always`;
   - when the description records a request;
   - when this account already published one on the PR, for any head. A stale
     explanation misleads, so once a PR has a walkthrough, every head needs one. A
     walkthrough someone else posts does not count, as `handoff` already ignores
     other accounts' reviews.

   To record a request, the agent sets description `walkthrough` to `requested`. The
   links line then shows **Code Walkthrough: _Requested._** until the review URL
   replaces it. Ruby sees only what the agent records. Recording a request made in chat
   or a PR comment is an agent rule, which the implementation classifies in
   `enforcement.yml`. When a walkthrough is due:
   - `merge` requires `--walkthrough`. It also gains the check `handoff` already
     applies: the review must be this account's rendered walkthrough. Today `merge`
     accepts any non-empty COMMENT review at the head, which would let a reviewer-notes
     review or another account's comment pass as the walkthrough.
   - `handoff` owes it for the current head.
   - The ready checkpoint has to follow it.

   The current exceptions stay:
   - the hold while the description lists decisions;
   - publication sooner when someone asks;
   - the hold while an unsubmitted review is pending, since GitHub refuses a new
     review beside it;
   - the checkpoint check's skip for blocked, failed, and opted-out results.

   A request in a PR comment counts only from an author the `comments` command admits.

   When none of the three cases applies, `merge` does not require `--walkthrough`, and
   still verifies one if it is supplied. `handoff` and the checkpoint owe nothing. Reviewer notes are never owed, and the
   helper does not count them as a walkthrough. A note on an older head stays as an
   outdated thread. The existing refusal of notes on a base that requires
   conversation resolution keeps them from blocking a merge.
4. **The description links what exists.** The links line shows **Code Walkthrough**
   when one is published or due, and **Reviewer notes** when notes are published.
   Otherwise it shows neither and prints no placeholder. Intent, Verification, and
   `review_focus` stay as they are.
5. **R4 changes to match.** Its new text: Shaka explains intent and verification in
   the description. It adds reviewer notes where code needs a why. It publishes a
   conceptual walkthrough with links to reviewed code, as a commit-bound COMMENT
   review, on request or on every PR when the repository sets `always`. A walkthrough remains readable after merge and substitutes for neither
   approval nor required acknowledgment. The interactive tour, the coverage map, and
   the selective notes sentences stay as they are. Requirements text that treats the
   walkthrough as an unconditional gate changes to "a due walkthrough" in three places:
   - R5's "After the walkthrough and required gates";
   - the merge-queue sentence that says submission does not relax walkthrough gates;
   - the acceptance step that publishes and reads back a walkthrough. It now reads back
     a walkthrough on a PR where one was due.

## Consequences

- **What a default PR loses.** It no longer carries a per-PR rollback sentence,
  ordered code tour, or **Start here** pointer.
  - Merge decisions still rest on the description's Intent and Verification, the code
    review, and the checkpoint's risk judgment.
  - It also loses the `WalkthroughEvidence` check, which refuses a walkthrough that
    lacks a commit-pinned link to a changed file or a name for each completed
    required and review check. That record is redundant for merging, for two
    reasons. `merge` enforces required checks itself, and the description's
    Verification takes the validation and review lines from their result files.
    The PR still loses one sentence naming every completed check.
  - A team that relies on the tour sets `always`.
  - Rollback already belongs in the description. The workflow puts it under the
    description's `details`, and the
    [placement rule](../../skills/shaka/references/delivery.md#why-the-description-and-the-walkthrough-differ)
    keeps routine rollback there collapsed. Nothing enforces these rules or the
    walkthrough's rollback instruction. In practice, though, each walkthrough in the
    40-PR sample was the place a rollback consequence appeared.
- **A requested walkthrough costs upkeep.** Once a PR has one, every later head owes
  a new one, as every PR does today. The cost now falls only on PRs where someone
  wanted the walkthrough.
- **Every installation's default changes on update.** The release notes and the
  Changelog section must say so and name `walkthrough.publish: always` as the way back.
  The new key follows the settings migration flow. It goes in `defaults.yml`,
  `docs/settings.md`, and the `.agents/shaka/config.yml` example. This repository uses
  the default.
- **Walkthrough guidance applies only to full walkthroughs.** `project_guidance.walkthrough`
  does not apply to reviewer notes. A repository that set it asked for walkthroughs that
  cover its requirements, so the release notes tell it to set `always` to keep them.
  Shaka does not infer `always` from the guide; the two settings stay independent.
- **Rebased heads need a new reference for consent.** Two Finish rules carry a
  person's confirmation across a rebase:
  - The limits confirmation carries to a clean rebase with no comparison. It also
    carries to "a conflict resolution that changes no behavior the walkthrough
    describes".
  - An Ask approval carries over when the rebased change "keeps the behavior the
    walkthrough describes".

  Only those two walkthrough references change. Without a walkthrough, they point to
  the behavior the description's Intent states, the text the merge decision used. The
  clean-rebase clause stays as it is, and so does each rule's strictness: a change to
  that behavior still needs a new confirmation.
- **Enforcement entries change.** In `enforcement.yml`, four entries take the new
  condition:
  - `checkpoint-after-walkthrough`;
  - `walkthrough-link-placement`;
  - `stop-time-handoff`, whose note describes the owed walkthrough;
  - `post-implementation-conclusion`, whose quote names the final walkthrough, which
    a default PR no longer has.

  `walkthrough-length` and `walkthrough-whole-diff` still describe a full walkthrough
  when one is published. The loader catches a quote that leaves the workflow but not a
  note that turned wrong, so the implementation review checks each of these notes.
  The workflow's Explain and Finish passages say when a walkthrough is due, and its
  `merge` usage lines and Auto-merge instruction pass `--walkthrough` only then.
- **Related open work.** #1148, #1175, and #1176 apply only when a walkthrough is
  published, so they lose urgency but stay valid. The labels #1173 added still apply
  to reviewer notes. #421 can build on the description rather than the
  walkthrough.
- **Expected size.** The implementation PR changes the setting, three gates, the links
  line, a notes-only rendering path, the workflow and enforcement text, the docs, and
  R4. It also updates the passages that send content to the walkthrough: the
  workflow's passage dividing the description from the walkthrough, and the
  code-level rollback sentence in `delivery.md`. Without a walkthrough, rejected
  alternatives go to reviewer notes and rollback goes to the description. It also
  rewrites `skills/shaka/references/walkthrough-notes.md` for notes published alone. That file now assumes a walkthrough body carries rollback and that a
  newer walkthrough resolves older notes. A notes-only review stays under the same
  `prose_limits` that apply to a walkthrough. Three notes-only side effects also change:
  - Without a newer walkthrough, nothing resolves notes on older heads. The
    notes-only publish path resolves this account's unanswered notes through the same
    `Walkthrough::NoteThreads` helper that walkthrough publication uses. That helper
    finds notes by `Notes::MARKER`, so notes-only reviews keep the same marker. A test
    checks that publishing notes for a newer head resolves an unanswered older note and
    leaves an answered one open. The `resolve` command's reply-before-resolve check
    stays as it is.
  - `handoff` stops listing open reviewer-note threads as answered threads awaiting
    confirmation.
  - The conversation-resolution refusal no longer tells the agent to publish a
    walkthrough without notes.

  The estimate is 400 to 600 changed lines. If the implementation exceeds 500, it
  splits into two PRs: first the setting and the gates, then notes-only publication,
  the links line, and the docs.

## Alternatives considered

- **Off by default with no notes.** This is simpler, but it drops the occasional "why"
  hint that the maintainer found useful when people wrote the code.
- **Keep the walkthrough and shorten it.** This lowers reading cost, but every PR still
  pays for publication, republication, and the gates.
- **Keep the current default and let repositories opt out.** This leaves the measured
  problem in place for the repository that showed it. It also contradicts the
  predecessor's on-request design, which nobody reported missing.
