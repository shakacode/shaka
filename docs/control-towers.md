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

In Codex, a chat opened directly in a checkout can use the one registered project
at that repository's exact path. For example, a chat in your application's
checkout can establish its tower without first moving the chat into the project.
An ambiguous project match still stops setup.

After the master acknowledges the repository tower, ask the tower what needs
attention. You choose which task starts; setup starts no backlog work or recurring
scans.

Keep each tower set in one environment: Claude and Codex cannot read each other's
sessions. See the [operating procedures](../skills/shaka/references/control-towers.md)
for setup, ownership, and handoff.
