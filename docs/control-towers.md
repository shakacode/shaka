# Control towers

Use Shaka for a few tasks before trying control towers. They are optional tools for keeping track of work within a repository and across projects.

A **Repository Control Tower (RCT)** follows one repository's priorities and
unfinished tasks. A **Master Control Tower (MCT)** coordinates several RCTs and
their dependencies. For example, it can track a library fix that must land before
an application upgrade.

Each delivery still has one owner. The [architecture guide](architecture.md)
explains where its records belong.

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
other's sessions. The tower skills use these [operating procedures](../skills/shaka/references/control-towers.md)
for setup, ownership, triage, and handoff.
