# Control towers

When several repositories need attention, use a control tower to keep priorities
and unfinished work in one conversation.

A **Master Control Tower (MCT)** coordinates priorities across repositories.
A **Repository Control Tower (RCT)** helps you choose and follow work in one
repository. Each selected task is delivered through Shaka by one owner.

For example, a release might need a library fix before an example app can upgrade.
The master tracks that dependency; each repository tower follows its own PR.
For a single task, you can use Shaka directly.

## Set up in Codex

Install the optional repository tower skill:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills" --with-rct
```

First give an existing portfolio task the [master role prompt](#role-prompts).
Then create a task in the saved project for each repository and send `$rct`.
The skill verifies the repository, names and pins the task, and registers it with
the master. Setup finishes when the master acknowledges that repository and task.

`$rct` takes no arguments: the task's project and current checkout select the
repository. If another tower already owns it, setup directs you there.

## Set up in Claude Code desktop

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.claude/skills" --with-claude-towers
```

1. Open the session you want as master and send `/mct-claude`.
2. Open a session in each repository and send `/rct-claude`.
3. Wait for the master's acknowledgment before treating registration as complete.

Keep the `MCT — Shaka` and `RCT — Shaka` title suffixes while those sessions hold
their roles. Claude and Codex cannot see each other's sessions; keep each tower
set within one host. Terminal-only hosts use the role prompts below.

## Choose work

A repository tower reads live issues, PRs, and existing ownership, then recommends
one bounded next task. You decide whether to start it. Setting up a tower does not
start backlog work, create workers, or grant merge authority.

Ask the tower to continue an existing delivery when one already owns the work.
Confirm a handoff before assigning a replacement. A stale title or idle task is
not enough to establish that the previous owner has stopped.

You can explicitly request a weekly attention scan. It reports meaningful changes
for triage and stays quiet when nothing needs attention. It does not assign work
or launch implementation on its own.

## Role prompts

For a master task:

```text
Act as the Master Control Tower for the repositories and outcome I name.
Track priorities and cross-repository dependencies. Reuse existing repository
towers and delivery owners. Route implementation through the installed Shaka
skill in the correct checkout. Follow each delivery's result and report the
next decision or blocker. Preserve existing ownership, pauses, authority,
and private context. This role does not authorize new tasks or scheduled work.
```

For a repository task on a host without a tower setup skill:

```text
Act as the Repository Control Tower for this repository. Verify its identity
and trusted instructions. Before recommending work, refresh live issues, PRs,
dependencies, and existing ownership. Recommend one bounded task and wait for
me to assign it. Refresh ownership again before starting Shaka. Continue through
an existing owner where one exists; otherwise own the delivery here. Preserve
review requirements, merge authority, pauses, and work limits. Report verified
results and the next decision. Create no scheduled work without my request.
```

Then give it an assignment:

```text
$shaka Complete [issue URL or task description] in [owner/repository].
Checkout: [local path]. Success means [observable result].
Existing owner: [task reference, or confirmed unowned].
Merge preference: [Ask or Auto].
Dependencies and limits: [prerequisites and stopping point].
```

The agent's [operating reference](agents/control-towers.md) covers triage,
ownership, adoption trials, and handoffs.
