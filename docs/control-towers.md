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

This setup entry point requires the Codex app's native project and task tools.
Claude Code desktop establishes its towers with its own skills, described below.
Cursor, OpenCode, and terminal-only installs receive `$shaka` and use the
[role prompts](#role-prompts).

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

## Establish a master tower in Claude Code

Install the tower skills with `--with-claude-towers`, open the Claude Code desktop
session you want to hold the master role, and send:

```text
/mct-claude
```

The skill searches your active sessions for one already holding the role and stops
with `MCT setup error: master control tower already exists` when it finds one, or
`master control tower is ambiguous` when several carry the title. Otherwise it
renames the session to end in `MCT — Shaka`, pins it, reads both changes back, and
reports the result.

One master per installation is a rule you keep, not something the skill enforces.
Searching the session list and renaming a session are separate calls, so two setups
started at the same moment can both succeed. The skill reports that on its next read
and asks you to resolve it; it never picks a winner, and it never renames, unpins,
or ends another session. A title left behind by an abandoned setup is a stale hint
you can clear, not a corrupt registry.

Repository towers find the master by that suffix, so keep it while the session holds
the role. Each registration lives in its own tower's transcript, and the master
derives the current tower set by reading live sessions, so the role adds no file,
database, or scheduler, and towers survive replacing the master itself. This skill
needs the desktop app's session tools; a terminal `claude` stops with `MCT setup
error: host session tools are unavailable`, and the role prompt below remains the
supported fallback.

Establishing the master authorizes its own title, pin, and acknowledgment
operations. It assigns no backlog, creates no worker session, and grants no merge
authority. A repository tower registers by message; the master verifies the
repository, session, and default branch from its own reads before acknowledging,
and refuses a repository that already has a tower. A delivered or queued message is
not acknowledgment in either direction.

## Establish a repository tower in Claude Code

With a master established, open a Claude Code desktop session in the repository you
want the tower to own, and send:

```text
/rct-claude
```

It takes no arguments: the session's own checkout selects the repository. The skill
confirms the Git root containing the session's working directory, the remotes, and live
GitHub identity. That working directory alone selects the repository, and a linked
worktree is valid wherever it lives. A session opened somewhere Git knows nothing about
is refused rather than guessed at. Missing or ambiguous repository identity, an
existing tower for the same repository, and a missing or ambiguous master are errors
rather than guesses.

The skill resolves the display prefix with `shaka prefix`, renames the session to
`<PREFIX> RCT — Shaka`, pins it, and then states the
completed setup in the session itself: the repository, session, default branch, and
one-repository scope. That written record, not the title, is what makes the role
durable — the master establishes ownership by reading the tower's session, and towers
outlive the master that acknowledged them.

Registration is a message, and this host has no bounded wait for another session, so
the tower reports `awaiting acknowledgment` and ends its turn. The master's answer
arrives as an ordinary labelled turn. Setup is complete only when that answer names
the same repository and session; a delivered or queued message is not acknowledgment,
and a refusal comes back the same way rather than leaving the tower waiting.

The two hosts cannot see each other's sessions, so a Claude master coordinates Claude
repository towers and a Codex master coordinates Codex ones. Do not mix hosts within
one tower set.

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
an Ask-ready task hands merge to GitHub rather than another agent turn; a changed head needs fresh evidence;
a paused task must remain paused without a release decision; a retired repository
must not receive new work from adopting Shaka. Apply a user's scope correction
before continuing an earlier assignment. Record observed actions, not just a
reader's promise to follow the prompt. A document review or passing unit suite
alone does not establish tower adoption.

To roll back, stop new admissions under the changed role, preserve unfinished
owners and PRs, and restore the previous reviewed instructions. Do not remove
other workflows or discard their active work as part of adopting Shaka.
