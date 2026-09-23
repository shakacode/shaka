# Control towers (advanced pilot)

Use Shaka for a few tasks before trying control towers. They are optional,
experimental tools for keeping track of work across repositories.

A **Repository Control Tower (RCT)** follows one repository's priorities and
unfinished tasks. A **Master Control Tower (MCT)** coordinates several RCTs and
their dependencies. For example, it can track a library fix that must land before
an application upgrade.

Ask your agent to install the optional tower skills for your environment and
establish the master. Then open a task in each repository and invoke its setup skill:

| Environment | Repository tower | Master tower |
| --- | --- | --- |
| Codex app | `$rct` | Agent follows the master role instructions |
| Claude Code desktop | `/rct-claude` | `/mct-claude` |

Wait for the master to acknowledge the repository tower. Then ask the repository
tower what needs attention; you choose which task starts. Setup itself starts no
backlog work or recurring scans.

Keep each tower set within one environment: Claude and Codex cannot read each
other's sessions. The [agent reference](agents/control-towers.md) retains setup,
ownership, triage, handoff, and adoption instructions.
