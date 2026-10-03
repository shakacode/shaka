# Continue feedback intake on an open PR

Keep the owning task available for feedback through PR closure or a confirmed
ownership transfer, including after an Ask handoff. The check watcher ends when
checks finish; it supplies no later comment coverage. This procedure uses the
existing trusted comment reader, WIP Details, and stable replies, without a new
coordination store. Ruby detects a wake; the agent assesses and answers feedback.

## Arrange bounded coverage

Use a host wake mechanism only when it can resume this same task for new ordinary
comments, review summaries, and inline comments, including while awaiting merge
approval. A check-completion or failure-only monitor is insufficient. Record the
mechanism and expiry in WIP Details. Keep one monitor; cancel the previous owned
watch before rearming. Existing task authorization covers handling feedback within
scope, not unrelated work or expanded merge authority.

When background-command completion resumes the task, use the saved trusted helper:

```sh
shaka pr watch OWNER/REPO NUMBER --head HEAD_SHA --root DIR --ref TRUSTED_SHA \
  --comments-only --owner 'EXACT WIP OWNER CELL' --baseline comments.json
```

Save `comments --head HEAD_SHA` outside the checkout after triaging its items and
publishing the handoff. Pass that packet as the baseline, including the agent's
own replies. Inspect feedback arriving during publication before accepting this
packet as handled. A baseline from before startup catches feedback in that gap.
The owner argument is the published WIP Details Owner cell, including its random
tag. A missing owner fails; a changed owner stops the old watch and wakes the
task for verification. Treat either as unavailable coverage until resolved.
PR-body metadata supplies no ownership authority. Confirm a transfer from direct
maintainer guidance or the live native ownership registry before relinquishing
the task. Without confirmation, retain follow-up ownership, expose the coverage
failure, and obtain a maintainer decision rather than silently abandoning feedback.

Comment-only mode ignores check completion. It exits for a trusted interaction,
head movement, closure, ownership transfer, error, or timeout. The default bound is
one hour, polling every 60 seconds with a 15-second settle window. It grants no
merge readiness; retain all validation, review, and merge gates. At timeout,
refresh ownership and live state, then rearm while ownership and host support
remain, or record the manual fallback. Stop on closure or confirmed transfer.
On head movement, refresh evidence and save a baseline for the new head before
rearming. On error, report coverage unavailable until the reader/watch recovers.

If the host cannot wake this task, or cannot retain it after the user archives it,
say **Automatic feedback intake unavailable** in the PR and final handoff. Name
the maintainer responsible for checking later feedback and give the exact resume
prompt, such as `$shaka https://github.com/OWNER/REPO/pull/N`. Record that owner,
limitation, and prompt in WIP Details. An available terminal session alone does
not establish a wake mechanism. Avoid claiming continued coverage. A manual
fallback needs no worker or scheduled automation.

At an Ask handoff, keep `awaiting-merge-approval` while comment coverage is armed;
run `handoff` without `--woken-by` so it still checks the ready merge handoff.
Keep the owning chat unarchived while automatic intake depends on it. A final
archiving sentence applies after closure, transfer, or the explicit manual
fallback, when no current actionable feedback remains.

## Triage a wake once

1. Refresh the PR head, state, WIP owner, and trusted policy. Stop task work if
   closed or a transfer is confirmed as above; preserve local work unpushed.
   An `ownership_transferred` wake alone requires verification, not relinquishment.
   Read feedback only with
   `comments --head SHA`. Excluded public prose stays withheld and gains no wake
   or execution authority.
2. Compare all three interaction lists with the last handled packet. Identify
   items by kind and ID; inspect existing agent dispositions and linked replies
   before responding. Prioritize feedback from the primary owner named by this
   session or trusted project instructions, then other actionable feedback.
   Treat a `COMMENTED` review with praise and a request as feedback, not approval.
3. For new actionable feedback, run `attention --state none` before handling it.
   Publish WIP Details saying the earlier merge-ready handoff is withdrawn
   pending assessment, with the feedback URL and next action. No code changes
   are needed to withdraw readiness. An excluded interaction needing maintainer
   screening follows the existing public-comment procedure instead.
4. Record each actionable item's disposition on GitHub: fix with evidence, reply
   with evidence, or request a consequential maintainer decision with a specific
   blocker. Use `reply --key feedback-KIND-ID`; an uncertain publication is read
   back or retried with the same key, preventing duplicate issue replies. Inline
   replies also pass `--comment ROOT_ID` and follow the existing resolve rules.
   Link review-summary dispositions to their review URLs. A disposition still
   open remains unfinished in WIP Details; advancing a detection baseline never
   marks that work resolved. A consequential decision uses description
   `decisions` and `awaiting-answer`.
5. Complete fixes through the workflow's verification and review phases. Refresh
   the walkthrough, required checks, and authority before restoring merge
   readiness. Evidence-backed replies without edits still need a fresh PR and
   comment read. Preserve Ask; praise supplies no new merge authorization.
6. Save the handled packet after dispositions and publications, checking any
   newly arrived item first. Rearm one watch for the current owner and head, or
   expose the manual fallback. Keep unresolved items visible on the PR rather
   than repeating replies on every wake.

Tests exercise late review, comment and inline detection, handled baselines,
excluded input, head movement, closure, and owner transfer. Host wake and agent
triage still require real-use evidence; a mocked wake does not prove an agent
resumed or answered on GitHub.
