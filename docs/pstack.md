# Use pstack with Shaka

[pstack](https://github.com/cursor/plugins/tree/main/pstack) is Lauren Tan's set of
engineering skills for coding agents. Install it beside Shaka to use its techniques,
such as a harness that drives your app, inside Shaka tasks. Shaka still runs the
checks, review, PR, and merge. [Working with Shaka](working-with-shaka.md#use-pstack-for-a-bounded-part-of-delivery)
shows when pstack fits a task.

Ask your agent:

```text
Install pstack from cursor/plugins for this coding agent, next to Shaka.
Tell me how it stays up to date.
```

## Install pstack

| Coding agent | Install |
| --- | --- |
| Cursor | `/add-plugin pstack` |
| Claude Code | `/plugin marketplace add cursor/plugins`, then `/plugin install pstack@cursor-plugins` |
| Codex | No official package yet. Use a community port, or link the skills with [your own updater](#build-your-own-updater). |

[cursor/plugins#1143](https://github.com/cursor/plugins/pull/1143) proposes native
Codex support. In Claude Code, pstack's commands carry a `pstack:` prefix, such as
`/pstack:poteto-mode`. For Cursor updates, read
[Cursor's plugin documentation](https://cursor.com/docs/plugins).

If you also linked a pstack skill into `~/.claude/skills`, Claude Code loads both
copies, possibly at different versions. `shaka doctor` lists each skill name that
appears in both `~/.claude/skills` and an enabled user-scope plugin. It also lists
each link in a coding agent's skills folder that points nowhere. It changes neither.
It does not read project skills or project-scope plugins.

## Keep Claude Code current

Claude Code leaves auto-update off for third-party marketplaces, so pstack stays at
the version you installed. To turn auto-update on, run `/plugin`, open
**Marketplaces**, select `cursor-plugins`, and choose **Enable auto-update**. To
update once:

```sh
claude plugin update pstack@cursor-plugins
```

A running session keeps the version it loaded. The update applies in your next
session or after `/reload-plugins`.

## Hand maintenance results back to Shaka

`/maintain-verification-skill` keeps a pstack verification harness in line with your
app. When the upstream skill finds corrections, it ends by opening its own PR.
Inside a Shaka task, Shaka publishes the PR after its checks and review. Ask for
the results in your prompt:

```text
$shaka Update this repository's verification harness with pstack's
maintain-verification-skill. Shaka publishes the PR, so return the
corrections and evidence to this task instead of opening one.
```

[cursor/plugins#781](https://github.com/cursor/plugins/pull/781) changes the skill
itself. The changed skill returns corrections and evidence when another workflow
owns delivery. The PR is a draft. Stay on upstream unless the skill opens its own
PR anyway.

To try the PR's branch in Claude Code, remove the upstream marketplace first. Both
use the name `cursor-plugins`, and Claude Code registers one marketplace per name.
Removing a marketplace also uninstalls its plugins and deletes their saved data.
Uninstall pstack, and any other plugin you installed from `cursor-plugins`, with
`--keep-data` first, so its data survives the switch. The commands below assume a
user install, the default. For a project or local install, add `--scope project`
or `--scope local` to each `uninstall`, `marketplace add`, and `install` command.
If a plugin is installed in more than one scope, uninstall and reinstall it in each.

```sh
claude plugin uninstall pstack@cursor-plugins --keep-data
claude plugin marketplace remove cursor-plugins
claude plugin marketplace add justin808/plugins#jg-codex/verification-maintenance-handoff
claude plugin install pstack@cursor-plugins
```

Before installing, [compare the branch with upstream](https://github.com/cursor/plugins/compare/main...justin808:plugins:jg-codex/verification-maintenance-handoff).
The marketplace follows the branch, so each update installs its newest commit.
Compare again before you update.

To return to upstream, reinstall from `cursor/plugins` and turn auto-update on
again if you used it:

```sh
claude plugin uninstall pstack@cursor-plugins --keep-data
claude plugin marketplace remove cursor-plugins
claude plugin marketplace add cursor/plugins
claude plugin install pstack@cursor-plugins
```

## Build your own updater

pstack is one of several skill packs you might run. A small script can keep each
pack at a commit you choose and link its skills into every coding agent. Ask your
agent:

```text
Write a script that keeps my agent skill packs current. Read a manifest
listing each pack's Git URL, its branch or pinned commit, its skill folders,
and the agent skill folders that get them. Update a checkout only when it is
clean, on the expected branch, and free of local commits. Link each skill into
~/.claude/skills, ~/.agents/skills, and ~/.cursor/skills, skipping any agent
that already has the pack installed as a plugin. When another skill already
uses a name, add a prefix such as pstack- and report the conflict instead of
overwriting. Show the planned changes before making them.
```

Codex reads skills from `~/.agents/skills`. Optional additions:

- Record each pack's installed commit, so you can say which revision a task used.
- Add a status command that reports packs behind upstream, broken links, and
  skills with the same name in two packs.
- Pin a fork at a commit you reviewed, and switch back to upstream once its
  change merges.
- Run the script on a schedule, such as a launchd agent on macOS.

After installing a pack, [try it on a task you'd merge anyway](working-with-shaka.md#try-a-new-skill-pack-with-shaka)
and ask where its instructions conflicted with Shaka.
