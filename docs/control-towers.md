# Control towers

A **Repository Control Tower (RCT)** gives you one chat for deciding what to work
on and following the PRs in a repository. Ask it to check in with the chats doing
the work and show you what needs your attention.

A **Master Control Tower (MCT)** coordinates work across repositories. For
example, it can help sequence a library fix before an application upgrade.
Each repository still has its own RCT.

Control towers are optional roles for your coding agent, guided by Shaka's
skills. Try [a few Shaka tasks](getting-started.md) before adding them.

## Set up your towers

Ask your agent to install Shaka's tower skills and help you establish a master
chat. Then open a chat in the saved project for the repository you want to work
on and invoke its repository setup skill:

| Environment | Master chat | Repository chat |
| --- | --- | --- |
| Codex app | Ask: “Set up this chat as my Master Control Tower using Shaka's instructions.” | `$rct` |
| Claude Code desktop | `/mct-claude` | `/rct-claude` |

Setup needs the app's chat tools; Codex also needs its project tools. If your
agent cannot access them, use the [manual role prompts](../skills/shaka/references/control-towers.md#role-prompts)
instead of automated tower setup.

The setup skill guides the agent to identify the repository from the chat's
project and checkout, check for an existing RCT, and register with the MCT.
Reuse an existing RCT when one is found. Setup is complete when the MCT
acknowledges the repository and its RCT chat; you then choose what work starts.

Keep your master and repository chats in the same app. Codex and Claude Code
cannot read each other's chats. The [setup and operating instructions](../skills/shaka/references/control-towers.md)
cover each environment in detail.

<a id="run-a-bounded-batch"></a>

## Choose a small batch

The RCT normally recommends one task at a time. To plan several together,
explicitly ask for a small batch.

Continue in the repository's RCT chat. It already has the repository context;
“me” refers to your signed-in GitHub account. You can ask:

```text
What should we tackle next? Look at issues assigned to me or unassigned,
and include Dependabot PRs. Suggest a batch of up to three.
```

Expect a short proposal explaining why those items matter, which already have
PRs or active chats, and which can proceed together. If one fix depends on
another, the proposal should explain the order. You can narrow the selection
with an outcome such as “Focus on checkout reliability.”

When the selection looks right, start it with **Ask** so the PRs come back to you
for a merge decision:

```text
Start those three with Shaka and Ask. Reuse the chats already working on
them, start new chats for the rest, and coordinate with them.
Bring the PRs back for review.
```

This gives the RCT permission to start the selected work and communicate with
those chats. Each task stays with one chat through implementation, testing,
review, and its PR. If a chat has stopped, ask the RCT to resume it; moving its
work to another chat should be an explicit handoff.

See [merge policies](working-with-shaka.md#choose-a-merge-policy) for Ask and Auto.
Setting up towers or starting a batch does not authorize a deployment.

## Follow the work

```text
How are those three going? Show me what's ready, what's blocked, and what
you need from me. Link each PR and its chat.
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

Replace the PR number with the one that merged. The RCT checks which chats were
waiting for that change and follows up with them. Those chats need to test their
changes together with the merged fix and refresh affected reviews and manual
checks. Wait for their updated results before treating the dependent PRs as ready.
Any outstanding security or business decision still needs to be settled.

### If your project shares one test environment

Some projects have a database or test server that only one chat can use at a
time. You can ask:

```text
Let the checkout fix test next. Tell the other chats sharing that environment
to wait until it's finished.
```

The RCT needs to notify every competing chat, so they do not all try to take the
next slot. The selected chat must still acquire the project's lock before
testing and release it afterward. Its place in line does not displace a chat
already using the environment. This depends on your project's tools; Shaka
does not include an environment scheduler.

## Decide what to merge first

```text
What order should I focus on the merges? Give me links to the PRs and their chats.
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
