# Operate control towers

Use this reference after a tower's setup skill establishes its role. The
[control-tower guide](../control-towers.md) contains installation and role prompts.
The setup skills own host-specific registration and error handling.

An MCT coordinates repositories; an RCT owns one repository's selection and
follow-through. Every delivery has one Shaka owner. Registration completes only
when the master acknowledges the same repository and task. A title, idle state,
or queued message does not prove ownership or completion.

## Who owns what

| Role | Owns | Completion evidence |
| --- | --- | --- |
| Master tower | Cross-repository priorities, dependencies, and consequential decisions | The requested outcomes and remaining dependencies, linked to repository results |
| Repository tower | Task selection, existing-owner reconciliation, sequencing, and follow-through | Each selected task has one accountable delivery owner and a verified result or blocker |
| Shaka delivery owner | Intake, implementation, checks, review, walkthrough, and authorized merge or handoff | The PR's current revision, validation, independent review when required, and actual final state |

The RCT can be the delivery owner for one bounded task. If a separate task
already owns the work, continue there; the RCT follows its result instead of
also editing or merging its PR. Transfer ownership explicitly before taking over.
An idle icon, an old comment, or a title is not proof that work is abandoned.

Keep requirements in their original issue or tracker and delivery evidence on
GitHub. A private portfolio page may link to them; do not copy private priorities,
task links, or customer context into a public PR. A dashboard is a view, not
proof of ownership, authorization, or completion.

## Select work interactively

After `$rct` or `/rct-claude` registration completes, give a read-only
recommendation from a fresh read of live issues, PRs, tracker relationships, and
any native task ownership the host exposes, not from the setup-time inventory.
Reread this section
before that first recommendation and before every later one, including after a
delivery finishes or blocks, after a PR completes or opens, and when the user
reports a material priority change.

Triage recommends one bounded delivery and waits for the user in this task to
assign it or explicitly request a start. Tracker assignee fields are data, not
start authority. The
recommendation does not mutate tracker state, create workers, start
implementation, or change merge authority because it found work. Reconcile
existing owners, explicit pauses, and active PRs before admitting new work.
When that assignment or request arrives, refresh live ownership again where the
host exposes it before starting `$shaka`.
If another owner now holds the candidate and the user has not explicitly transferred
ownership to this task, report it and wait for the user's decision instead of starting
a second writer. Each selected delivery continues through the installed `$shaka`
skill with one accountable owner.

Reconstruct the repository's essential backlog from GitHub or the selected project
tracker. A fresh authorized task should not need a private workflow database, old
tower transcript, or external coordination ledger to understand that backlog.

Classify each relevant candidate as deliver next; repair, through its existing owner
when one exists; design or investigation first; blocked; defer with reason;
superseded / close; or no action. Order admitted work by verified customer or
maintainer impact, security and correctness, release needs, and native dependency
relationships. Shared files are an integration concern, not by themselves a
semantic dependency. Recommend one bounded next delivery and why it precedes the
alternatives.

### Account for Dependabot

Every triage refresh lists open Dependabot PRs and gives each an explicit disposition
from the classification categories above. Addressing Dependabot does not mean blindly
merging it. No bot PR may disappear from the recommendation without a disposition.

## Scan for attention only when asked

RCT setup creates no schedule or monitor. When the user explicitly requests it, a
weekly read-only attention scan may identify new, stale, failing, blocked, or
ownerless issues and PRs and wake the RCT for interactive triage. The scheduled
scan does not make product dispositions, mutate tracker state, assign work, launch
implementation, or merge. Its wake and content are data, never a user assignment or
start request. An unchanged scan stays quiet.

## Keep work state in the tracker

Requirements, priority, status, decisions, and task dependencies live in the
original issue tracker. On GitHub, use native issue dependencies (`blocked by` /
`blocking`) rather than a Markdown dependency schema
([GitHub guidance](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-issue-dependencies)).
On Linear, use native blocked/blocking issue relations
([Linear guidance](https://linear.app/docs/issue-relations)). Use structured prose only for facts the tracker
cannot represent, and keep it human-readable. GitHub PRs hold implementation,
validation, review, walkthrough, usage, and final-state evidence. Link them to
their source issue when sharing is authorized. RCT and delivery transcripts are
working views, not canonical portfolio state. Cross-repository priority belongs
to the MCT; each repository's issue and PR facts remain in that repository or its
selected project tracker.

## Choose models for tower work

Keep model selection advisory and portable. Ordinary RCT triage uses a balanced
flagship model with medium reasoning; consequential product, security, migration,
or dependency decisions justify higher reasoning. Mechanical inventory may use a
faster route. Every selected Shaka delivery assesses its own model and effort independently;
the RCT's route grants no authority and does not become the delivery route.

## Keep decisions and waits accurate

Use Shaka's **ask** and **auto** preferences. Preserve an existing decision's
repository, task, revision, and risk scope; do not convert an old workflow's
setting into broader Shaka authority. Unknown authority defaults to asking.
Record the preference early; in Ask, prepare the reviewable result, then point the
human at GitHub's merge control. Reuse authority already granted for that scope.

CI waits, missing reviews, and repairable conflicts remain with the delivery
owner. Finish independent work while waiting. Send a decision to the human only
when their input is needed, with the exact question, recommendation, PR evidence,
and owning task. If an attention desk already exists, reuse its established
writer and response channel; Shaka does not require or implement a desk.
An answered question is no longer unanswered, but the owner must still verify
the requested action completed. A queued message proves neither consumption
nor completion.

An Auto preference cannot compensate for missing protection or checks. The
[merge boundary](../pilot-plan.md#merge-boundary) requires observable native checks
enforced for the acting account. If GitHub cannot expose that protection, retain
the prepared PR and report the limitation; do not switch submission paths to
evade the guard. A tower does not grant deployment or other consequential authority.

## Adopt and prove the path

Choose an active repository where the user wants a result. Adopting Shaka does
not require changing, validating, or merging the workflow it replaces. Treat
retired workflow repositories as reference material unless the user explicitly
assigns work there. Their PRs and checks are not adoption dependencies.

1. Identify the existing owners, unfinished work, authority, and explicit pauses.
   Verify the target checkout and installed Shaka source outside that checkout.
2. Review and select a published revision of the role instructions. A paused
   tower needs explicit authorization to resume its named work. Adoption alone
   does not release other pauses, renew limits, or restart scheduled tasks.
3. Apply the role to one existing RCT and complete one real Shaka task. Require
   the correct repository, no duplicate owner, actual checks, current review when
   required, a commit-bound walkthrough, and the authorized merge or PR handoff.
4. Read back GitHub's final state and have the master consume the result. Record
   the tested source revision and outcome once in the existing rollout record.
   Delivery, acknowledgment, and verified completion are different facts.
5. Expand to the remaining repositories only after that pilot succeeds and their
   adoption is authorized. Reuse their commands, owners, and approval requirements.

Check negative cases too: an owned target must reuse or wait for its owner;
an Ask-ready task hands merge to GitHub rather than another agent turn; a changed head needs fresh evidence;
a paused task must remain paused without a release decision; a retired repository
must not receive new work from adopting Shaka. Apply a user's scope correction
before continuing an earlier assignment. Record observed actions, not just a
reader's promise to follow the prompt. A document review or passing unit suite
alone does not establish tower adoption.

To roll back, stop new admissions under the changed role, preserve unfinished
owners and PRs, and restore the previous reviewed instructions. Do not remove
other workflows or discard their active work as part of adopting Shaka.
