# Control towers

Control towers are optional tools for tracking work across repositories. Try Shaka
on a few tasks first.

A **Repository Control Tower (RCT)** follows one repository's priorities and tasks.
A **Master Control Tower (MCT)** coordinates RCTs and dependencies—for example, a
library fix needed before an application upgrade.

Each delivery still has one owner. The [architecture guide](architecture.md)
explains where its records belong.

Ask your agent to install the tower skills and establish the master. Then open a
task in each repository and invoke its setup skill:

| Environment | Repository tower | Master tower |
| --- | --- | --- |
| Codex app | `$rct` | Agent follows the master role instructions |
| Claude Code desktop | `/rct-claude` | `/mct-claude` |

Use a task in the saved project for the intended repository. The Codex setup
skill instructs your agent to verify its Git root, remotes, and live GitHub
identity, and to check for an existing RCT for that repository. These are agent
steps, not an automatic registry guarantee. Reuse that tower when one exists.
Setup completes only when the MCT acknowledges the same repository and RCT task.

After the master acknowledges the repository tower, ask the tower what needs
attention. You choose which task starts; setup starts no backlog work or recurring
scans.

Keep each tower set in one environment: Claude and Codex cannot read each other's
sessions. See the [operating procedures](../skills/shaka/references/control-towers.md)
for setup, ownership, and handoff.

## Run a bounded batch

Once one RCT is registered for the verified repository, give it an explicit
assignment. The MCT coordinates work spanning repositories; each RCT retains
one repository's owners and evidence. Registration alone authorizes no backlog
execution, new delivery chats, merges, deployments, production mutations, or
arbitrary messages. Those actions need authority from your request.

For example, replace the brackets with your repository, account, and limits:

```text
In [owner/repository], select up to three issues assigned to [my account]
or unassigned that address [customer outcome]. Reconcile live PRs and existing
owners first; leave other people's assignments alone. Propose the batch and
explain dependencies before starting. Include Dependabot PRs in the triage.
```

An assignee is a selection filter, not permission to execute. Review the proposed
scope, then authorize the concrete work and any owner messages or new chats:

```text
Start that three-item batch. Resume existing delivery owners; create a Shaka
chat only for a confirmed unowned target. You may message these owners for
handoffs and prerequisite updates. Use the installed $shaka skill with Ask
merge preference in each delivery. Stop at reviewed PRs; do not merge or deploy.
```

Keep one accountable owner per issue or PR. Resume an existing owner rather than
starting a second writer because its chat is idle. If it cannot continue, explicitly
transfer ownership. Each delivery uses an isolated checkout as needed and retains
its repository's validation, review, security, and domain requirements.

Ask means the owner prepares a verified PR for your merge decision. It does not
permit delayed auto-merge or turn a prerequisite update into merge consent. See
[working with Shaka](working-with-shaka.md) for merge preferences and resumption.

## Read evidence before recommending a merge

Ask the RCT to read current owner handoffs and compare them with live GitHub
state. A launch that succeeded proves only that a chat started. A green review
job without a review artifact, an old check, or a report for another commit does
not establish readiness. Owners remain responsible for current evidence.

| State | What the RCT should establish | Next action |
| --- | --- | --- |
| Verified ready | Current PR head, applicable checks, actual review report, manual QA, and required domain decisions agree | Bring the PR to the authorized merge decision |
| Blocked | A named prerequisite, failed check, missing review, QA gap, or unresolved decision remains | Give the blocker and its responsible owner |
| Superseded | Live evidence shows another change replaces the work | Explain the replacement; obtain authority for any closure |
| Merged | GitHub confirms the merge and resulting base revision | Report the result and reassess affected dependencies |

These are evidence-based recommendations by the agent, not an automated Shaka
readiness guarantee. A ready recommendation still respects native GitHub gates,
Ask, and any separate security or domain approval.

Require the owner to exercise the changed behavior, not just run unit tests.
Use positive cases and **negative controls**: cases that should fail or remain
unaffected, showing the check can detect the defect without false alarms. For
example, a repaired smoke test should pass on a healthy page and fail when the
required content is deliberately absent.

A useful review app runs the tested revision with the routes, data, and services
needed to exercise the change. Record desktop and mobile results where relevant.
An empty preview, an unavailable backend, or a deployment for an earlier commit
is a gap to report. See [PR verification](pr-verification.md) for evidence choices.

AI review can handle routine diff analysis and evidence reconciliation. Keep
human ownership for decisions requiring domain knowledge, such as whether data
provenance is acceptable or a billing rule matches the contract. Use the least
costly review route that can answer the question, and name what remains for the
human; more AI review cannot substitute for that decision.

## Resume after a shared prerequisite

When a shared fix lands, verify its merge and wake only the owners whose blockers
it actually resolves, within your messaging authorization. Other owners retain
their existing state. Use a prompt like this:

```text
[Prerequisite PR URL] merged at [base SHA]. Resume your existing delivery for
[affected PR URL] through $shaka. Integrate the new base, rerun affected checks
and real manual QA, and renew review evidence for your current head or exact
merge result as the repository requires. Report remaining blockers and evidence
links. Preserve Ask and the separate security/domain gates; this update waives none.
```

A wake-up is not proof that the owner read it or completed the work. Confirm the
new handoff and live state before changing the recommendation. A prior report does
not establish that the updated branch works with the prerequisite.

### Coordinate a scarce test environment

Some repositories require a serial database or runtime claim because owners
share one integration environment. That is repository-specific policy, not a
universal Shaka requirement. Follow that repository's backend claim mechanism
and respect its live holder.

One real batch repeatedly raced when owners all tried to claim the released
slot. The RCT resolved the handoff by telling **all competing owners** to defer
new claims for the next selected owner, then waiting for that owner's successful
backend claim. Notifying only the selected owner left competitors free to race.

A scheduling reservation gives an owner the next turn; it grants no lease and
cannot displace a live holder. The selected owner must acquire the backend claim
before using the environment and release it according to repository policy.
Shaka provides no built-in FIFO scheduler or blanket background autonomy.

```text
For the authorized batch, tell every competing owner to defer new claims while
[owner A] gets the next turn. Respect any live holder. Owner A must confirm a
successful backend claim before testing, then report results and release it.
Continue other work only within each owner's existing scope and limits.
```

## Ask for merge priorities with links

Request a recommendation you can act on:

```text
Read current owner handoffs and live PR state for this batch. What order should
I focus on the merges? Rank customer impact and readiness together. Give each
PR link, clickable owner-chat link, evidence revision, reason, and remaining
blocker. Separate verified ready, blocked, superseded, and merged work.
```

A production correctness fix with demonstrated QA may deserve attention before
a setup convenience change. An urgent but blocked change needs its decision or
repair first. Explain that tradeoff rather than ranking by PR number or green
status alone. Keep a clickable PR link beside its owner-chat link so you can
inspect evidence and resume the accountable owner.

![RCT merge-priority answer with ranked PR links and owner-chat links, followed by blocked PRs and their remaining blockers.](https://raw.githubusercontent.com/shakacode/shaka/025f0d04132786e880d422d11409e6d5ddef93d7/docs/images/rct-merge-priorities.png)

*Illustrative snapshot from an authorized RCT batch, published with the user's
approval. The PR numbers, owners, and readiness statements show the answer's
format; they are not current status or merge instructions.*

Codex chat deep links open local navigation in the Codex app. They are not public
share links and do not grant another reader access to the conversation. Supply
links from the actual owner's host metadata; do not invent chat IDs. Keep private
tracker bodies and coordination records out of public artifacts. The screenshot
above is a specifically approved example, not permission to publish other chats.

Merge one PR at a time when the required authority and gates are satisfied. After
each merge advances the base, have the next owner integrate it and confirm
validation against the updated base or exact merge result, renewing affected
review and QA evidence. Ask still requires your explicit merge decision; Auto
continues only within its authorized scope. Verify GitHub's actual merged state
before reporting completion or waking dependent owners.
