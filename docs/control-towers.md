# Use control towers with Shaka

A **Master Control Tower (MCT)** keeps priorities and dependencies clear across
repositories. A **Repository Control Tower (RCT)** keeps one repository's work
moving. Each implementation or PR repair has one owner who uses the installed
`$shaka` skill through the requested outcome.

These are optional roles in your existing tasks. They need no new service,
workflow database, or scheduler. Start with one repository and one real delivery.
Keep using Shaka directly when a tower would add no value.

## Establish a repository tower

Create a Codex task in the saved project for the intended repository, then send:

```text
$rct
```

This setup entry point currently requires the Codex app's native project and task
tools. Claude Code, Cursor, and terminal-only installs receive `$shaka` without
`$rct`.

The installed RCT skill verifies the task's project, current Git root, remotes,
and live GitHub identity. It makes the current task the one RCT for that repository,
pins it, and registers it with the existing MCT. Setup is incomplete until the MCT
acknowledges the same repository and task. Missing or ambiguous repository identity,
an existing different RCT, and missing or ambiguous MCT ownership are errors rather
than guesses.

One RCT owns one repository. Closely related repositories still use separate RCTs;
the MCT coordinates their ordering and dependencies. If a saved project contains
several repositories, start the task with its current checkout rooted in the one
repository the tower will own. `$rct` takes no path or repository argument.

The setup request authorizes its native title, pin, and registration operations.
It does not assign backlog work or create delivery tasks. After registration, the
RCT gives a read-only backlog recommendation; start a selected delivery through
`$shaka`.

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

## Role prompts

Give an existing portfolio task this role and a bounded outcome:

```text
Act as the Master Control Tower for the repositories and outcome I name.
Keep priorities, cross-repository dependencies, and decisions clear. Reuse
existing repository towers and delivery owners. Route each implementation or
PR repair through the installed $shaka skill in the verified target checkout.
Keep one delivery owner per task. Follow verified PR outcomes; do not become
a second writer or merge executor for an owned PR. Preserve existing authority,
pauses, work limits, and private context. Report material results and the next
decision or blocker. This role does not authorize new tasks or scheduled work.
```

Give the repository's existing task this role and its selected work:

```text
Act as the Repository Control Tower for the repository I name. Read its trusted
AGENTS.md and reconcile the selected issue or PR with live GitHub state and
existing task ownership. Finish useful existing work before admitting more.
For each delivery, use the installed $shaka skill. Either own that bounded task
here or continue through its existing owner; do not split closeout responsibility.
Preserve the repository's commands, review requirements, and merge authority.
Use isolated worktrees for independent writers and never duplicate a target.
Keep real decisions visible and verify the final PR state before reporting done.
Preserve explicit pauses and limits; do not create background work from this role.
```

Then supply an actual assignment, replacing the brackets with verified facts:

```text
$shaka Complete [issue/PR URL or task description] in [owner/repository].
Checkout: [verified local path]. Success means [observable result].
Existing owner: [task reference, or confirmed unowned].
Merge authority: [existing decision and scope, or ask if unset].
Dependencies and limits: [known prerequisites, pauses, and stopping point].
```

The installed Shaka procedure owns model selection, intake, verification, review,
and merge handling. Reuse answers already given for the same task. A tower prompt
does not change the host's model, replace the installed skill, or authorize
delegation. Use supported host controls and the user's actual authorization.

## Keep decisions and waits accurate

Use Shaka's **ask** and **auto** preferences. Preserve an existing decision's
repository, task, revision, and risk scope; do not convert an old workflow's
setting into broader Shaka authority. Unknown authority defaults to asking.
Record the preference early; in Ask, prepare the reviewable result before seeking
the actual merge decision. Reuse authority already granted for that scope.

CI waits, missing reviews, and repairable conflicts remain with the delivery
owner. Finish independent work while waiting. Send a decision to the human only
when their input is needed, with the exact question, recommendation, PR evidence,
and owning task. If an attention desk already exists, reuse its established
writer and response channel; Shaka does not require or implement a desk.
An answered question is no longer unanswered, but the owner must still verify
the requested action completed. A queued message proves neither consumption
nor completion.

An Auto preference cannot compensate for missing protection or checks. The
[merge boundary](pilot-plan.md#merge-boundary) requires observable native checks
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
an Ask task must wait for its merge decision; a changed head needs fresh evidence;
a paused task must remain paused without a release decision; a retired repository
must not receive new work from adopting Shaka. Apply a user's scope correction
before continuing an earlier assignment. Record observed actions, not just a
reader's promise to follow the prompt. A document review or passing unit suite
alone does not establish tower adoption.

To roll back, stop new admissions under the changed role, preserve unfinished
owners and PRs, and restore the previous reviewed instructions. Do not remove
other workflows or discard their active work as part of adopting Shaka.
