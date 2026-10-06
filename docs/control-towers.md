# Control towers

Control towers are optional tools for tracking work across repositories. Try Shaka
on a few tasks first.

A **Repository Control Tower (RCT)** follows one repository's priorities and tasks.
A **Master Control Tower (MCT)** coordinates RCTs and dependencies—for example, a
library fix needed before an application upgrade.

Each delivery still has one owner. The [architecture guide](architecture.md)
explains where its records belong.

For Codex, ask in your existing portfolio chat:

```text
Install Shaka's optional Codex MCT companion and the RCT companion.
Reuse the existing master if one is established. Do not start delivery work.
```

The MCT and RCT companions can be selected independently. Installing neither keeps
the default installation to Shaka. Updates and reinstallation retain selected
companions. Ask your agent to update an older Shaka installation first, then add
a missing companion with the current installer.

Start a new chat if the skill list is stale. Invoke `$mct` in the intended master
chat, or continue in the existing master. Then open a chat in each saved repository
project and invoke its repository setup skill:

| Environment | Repository tower | Master tower |
| --- | --- | --- |
| Codex app | `$rct` | `$mct` |
| Claude Code desktop | `/rct-claude` | `/mct-claude` |

After the master acknowledges the repository tower, ask the tower what needs
attention. You choose which task starts; setup starts no backlog work or recurring
scans.

Keep each tower set in one environment: Claude and Codex cannot read each other's
sessions. See the [operating procedures](../skills/shaka/references/control-towers.md)
for setup, ownership, and handoff.
