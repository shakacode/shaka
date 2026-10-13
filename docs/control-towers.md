# Control towers

![A central coordination tower connects three smaller towers, each with its own platform and work units.](img/coordinated-towers.webp)

Control towers are optional roles for your coding agent.
Try [a few Shaka tasks](getting-started.md) first.

A **Repository Control Tower (RCT)** gives you one chat for choosing work and
following PRs in a repository.
A **Master Control Tower (MCT)** coordinates RCTs and dependencies—for example, a
library fix needed before an application upgrade.

![A Master Control Tower coordinates Repository Control Towers. Each repository tower follows its delivery tasks, and each task has one owner.](img/control-towers.svg)

## Set up your towers

For Codex, ask your agent:

```text
Install Shaka's control towers for Codex.
```

1. If you already have a master chat, continue there. Otherwise, choose one
   chat to coordinate your projects and run `$mct` there.
2. Open a chat in each repository's Codex project and run `$rct` to connect it
   to the master.

In Claude Code, use `/mct-claude` and `/rct-claude` instead. Use the desktop apps
for tower setup; see [coding agents](coding-agents.md) for other environments.

After the master acknowledges the repository tower, ask the tower what needs
attention. You choose which task starts; setup starts no backlog work or recurring
scans.

Keep each tower set in one environment: Claude and Codex cannot read each other's
sessions. Ask the owning tower to explain its setup, ownership, or handoff before
moving work between environments.

<a id="run-a-bounded-batch"></a>

## Choose what to work on

In your repository's RCT chat, ask:

```text
What should we tackle next?
```

The RCT recommends one task and explains why it matters. To work on several
at once, follow up with:

```text
Suggest a batch of up to three.
```

Expect a short proposal showing which tasks can proceed together and which need
to wait. You can narrow it with a request such as “Focus on checkout reliability.”

When the selection looks right:

```text
Start that batch with Shaka and Ask. Coordinate the chats.
```

**Ask** brings each PR back to you for a merge decision. The RCT reuses existing
chats and creates any missing ones. Each task stays with one chat through testing,
review, and its PR. If a chat stops, ask the RCT to resume it.

See [merge policies](working-with-shaka.md#choose-a-merge-policy) for Ask and Auto.
Setting up towers or starting a batch does not authorize a deployment.

## Follow the work

```text
How is the batch going? Show what needs my attention, with PR and chat links.
```

A useful update combines the latest chat reports with the current PRs on
GitHub. It should tell you what changed and what happens next:

| Status | What to expect |
| --- | --- |
| Ready for review | A PR with completed checks, review results, and evidence that the change works |
| Blocked | The specific problem, the chat handling it, and any decision needed from you |
| Replaced by other work | A link to the replacement and a recommendation for the old issue or PR |
| Merged | The merged PR and any other work it unblocks |

Before merging, open the PR to see how the change was checked. Tests and reviews
should cover its latest code. For visible changes, look for results from using
the app, including desktop and mobile where relevant. A review app should let
you try the feature with the data and services it needs.

Good checks also show that they can catch the problem. For example, a smoke test
should pass on a healthy page and fail when required content is missing. This
is a **negative control**. [PR verification](pr-verification.md) explains what to
look for in the evidence.

Use focused AI review for code and tests, and spend human review time on decisions
that need your knowledge. An agent can check a billing calculation; someone who
knows the contract must decide whether that is the right billing rule.

## Unblock dependent work

When a prerequisite PR merges, tell the RCT:

```text
PR #123 has merged. Ask the chats that were waiting on it to update their
branches, rerun their checks, and tell me what's still blocked.
```

Those chats need to test their changes together with the merged fix and refresh
affected reviews and manual checks. Wait for their updated results before treating
the dependent PRs as ready.
Any outstanding security or business decision still needs to be settled.

### If your project shares one test environment

Some projects have a database or test server that only one chat can use at a
time. You can ask:

```text
Let the checkout fix test next. Tell the other chats sharing that environment
to wait until it's finished.
```

The RCT should tell every chat sharing the environment which one tests next.
This needs your project's existing way to reserve it. A chat already testing
finishes first. Shaka does not include an environment scheduler.

## Decide what to merge first

```text
Which PRs should I merge first? Include PR and chat links.
```

The recommendation should weigh impact and readiness together. A tested fix for
lost orders may deserve attention before a development convenience. An urgent
PR that still needs a security review should name that blocker and the next step.

Here is an example response from an RCT in Codex:

![RCT response ranking PRs for merge attention, with links to each PR and its chat and a separate list of blocked PRs.](https://github.com/user-attachments/assets/6da53ac1-efad-4146-b334-ac8546a49144)

*Example snapshot: merge priorities first, remaining blockers below.*

Open the PR to review the change, or its chat to ask questions and request more
work. Codex chat links open in your app; they are not public conversation shares.

Merge one PR at a time. After each merge, ask the RCT to have the next chat check
its PR against the updated base. A previous green result may not cover the
combined changes. Under Ask, you decide whether each PR should merge; the RCT
helps you make that decision with current results.
