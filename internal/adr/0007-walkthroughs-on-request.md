# 0007: Publish code walkthroughs on request

Status: proposed.
Date: 2026-11-13. No issue; the maintainer raised it in a Shaka task chat.

## Context

[R4](../requirements.md) requires a conceptual code walkthrough on every PR, published as
a commit-bound COMMENT review. The merge gate (`merge --walkthrough`), `handoff`, and the
ready checkpoint all require one for the current head. A change to three or more files
also gets inline walkthrough notes, including a **Start here** note.

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
  Open PR #1173 labels inline walkthrough comments.

Published research points the same way:

- **Context helps reviewers who don't own the code.** Bacchelli and Bird (ICSE 2013)
  found that understanding a change is the reviewer's hardest need. Reviewers who don't
  own the files rely on the description; owners go straight to the code. Here the
  maintainer owns the code and is the only reviewer, which is the case where a
  walkthrough helps least.
- **Reading order matters for large changes.** In Fregnan et al. (FSE 2022), files
  shown later got less scrutiny. In Gonçalves et al. (2025 preprint), reviewers read
  linearly up to about 176 changed lines and looked for the core of the change beyond
  that.
- **Sparse "why" comments are common advice, not measured evidence.** GitHub Docs,
  Red Gate, and the Cal.com handbook recommend that authors comment on their own PR at
  surprising spots, such as a rejected alternative or a caveat. No controlled study
  isolates the effect.
- **Agent-written PRs call for different review evidence.** Simon Willison asks for
  proof in the PR that the code works. Addy Osmani proposes a "PR contract" of intent,
  evidence, risk, and one or two focus areas. Both concern intent and verification
  rather than a tour of the code.

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
3. **Gates require a walkthrough only when one is due.** A walkthrough is due under
   `always`, and also after someone asked for one, because a walkthrough for an
   older head misleads. Then:
   - `merge` requires `--walkthrough`, and verifies it as it does now.
   - `handoff` lists a walkthrough for an older head as owed work.
   - The ready checkpoint has to follow it.

   Otherwise `merge` accepts no `--walkthrough`, and `handoff` and the checkpoint
   owe nothing. Ruby can see `always` and an existing walkthrough, but not a spoken
   request. The agent publishes the requested walkthrough, and the gates take over from
   there. Reviewer notes are never owed or republished, and the helper does not count
   them as a walkthrough.
4. **The description links what exists.** The links line shows **Code Walkthrough**
   when one is published or due, and **Reviewer notes** when notes are published.
   Otherwise it shows neither and prints no placeholder. Intent, Verification, and
   `review_focus` stay as they are.
5. **R4 changes to match.** Its new text: Shaka explains intent and verification in
   the description. It adds reviewer notes where code needs a why, and publishes a
   commit-bound walkthrough on request or when the repository sets `always`.

## Consequences

- **What a default PR loses.** It no longer carries a per-PR rollback sentence,
  ordered code tour, or **Start here** pointer.
  - Merge decisions still rest on the description's Intent and Verification, the code
    review, and the checkpoint's risk judgment.
  - A team that relies on the tour sets `always`.
  - The rollback sentence is the one piece with no other home. Adding one to the
    description is a possible follow-up, not part of this change.
- **Every installation's default changes on update.** The release notes and the
  Changelog section must say so and name `walkthrough.publish: always` as the way back.
  The new key follows the settings migration flow. It goes in `defaults.yml`,
  `docs/settings.md`, and the `.agents/shaka/config.yml` example. This repository uses
  the default.
- **Enforcement entries change.** The `enforcement.yml` entries for checkpoint after
  walkthrough, link placement, and walkthrough evidence take the setting's condition.
  The workflow's Explain and Finish passages say when a walkthrough is due.
- **Related open work.** #1148, #1175, and #1176 apply only when a walkthrough is
  published, so they lose urgency but stay valid. #1173 labels inline comments and
  still applies to reviewer notes. #421 can build on the description rather than the
  walkthrough.
- **Expected size.** The implementation PR changes the setting, three gates, the links
  line, a notes-only rendering path, the workflow and enforcement text, the docs, and
  R4. The estimate is 400 to 600 changed lines.

## Alternatives considered

- **Off by default with no notes.** This is simpler, but it drops the occasional "why"
  hint that the maintainer found useful when people wrote the code.
- **Keep the walkthrough and shorten it.** This lowers reading cost, but every PR still
  pays for publication, republication, and the gates.
- **Keep the current default and let repositories opt out.** This leaves the measured
  problem in place for the repository that showed it. It also contradicts the
  predecessor's on-request design, which nobody reported missing.
