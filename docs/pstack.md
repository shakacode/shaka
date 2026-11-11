# Use pstack with Shaka

[pstack](https://github.com/cursor/plugins/tree/main/pstack) is an optional set of
engineering skills from Lauren Tan. Use a skill for a specific part of a Shaka
task, such as checking how your app behaves. Shaka still owns checks, review,
the PR, and your merge choice. See [an example](working-with-shaka.md#use-pstack-for-verification).

## Install pstack

Ask your coding agent:

```text
Install pstack from cursor/plugins alongside Shaka. Preserve my existing skills
and tell me how pstack stays up to date in this coding agent.
```

Cursor and Claude Code can install pstack as a plugin. In Codex, use selected
skills through a compatible installation or [your own updater](#build-your-own-updater).
[Native Codex support](https://github.com/cursor/plugins/pull/1143) is still proposed.
See [Cursor's plugin guide](https://cursor.com/docs/plugins) and
[Claude Code's plugin guide](https://code.claude.com/docs/en/discover-plugins).

If a skill is missing or appears twice, ask Shaka to check:

```text
/shaka doctor
```

In Codex, use `$shaka`. Doctor reports broken skill links and duplicate names
between Claude's user plugins and personal skills folder. It leaves both in place
so you can choose what to keep. It does not inspect project skills or plugins.

## Build your own updater

Use one updater when you install several skill packs or use more than one coding
agent. Ask your agent to build it around the sources you choose:

```text
Build a script to update my coding-agent skill packs. Read a manifest of each
pack's repository URL, branch or pinned commit, skill folders, and destinations
for each coding agent. Show the plan before applying it.

Only update a checkout when it is clean, on the expected branch, and has no
unpushed commits. Preserve local changes. Skip any coding agent that already
loads the pack as a plugin. If a skill name is taken, report the conflict and
use a distinct prefix rather than overwriting it.

Add a status command that shows the installed revision, whether it is behind
its source, broken links, and duplicate names. Let me choose which packs track
upstream and which use a pinned release, commit, or fork.
```

Have the agent check the actual skills directories your tools read. Start with
a plan and a manual update. Once you trust the result, you can ask for a scheduled
run. For a new pack, [try a small task](working-with-shaka.md#try-a-new-skill-pack-with-shaka)
before relying on it.

## Keep Claude Code current

Claude Code leaves auto-update off for third-party marketplaces by default.
To enable it for pstack, open `/plugin`, choose **Marketplaces**, select
`cursor-plugins`, then choose **Enable auto-update**. To update once, choose
**Update now** for pstack on the **Installed** tab. A running session keeps the
version it loaded until you reload plugins or start a new chat. See
[Claude Code's update guide](https://code.claude.com/docs/en/discover-plugins#keep-plugins-updated).

## Hand maintenance results back to Shaka

Ask pstack to update the checks that exercise your app, then let Shaka deliver
any changes:

```text
/shaka Use pstack's maintain-verification-skill to update this project's app checks.
Return the changes, evidence, and remaining gaps to Shaka for the PR.
```

If the checks still match the app, the agent can report that and stop. If it finds
corrections, Shaka checks and reviews them before opening its PR. Avoid running a
second delivery workflow on the same work. The
[upstream handoff proposal](https://github.com/cursor/plugins/pull/781) is a draft;
use the installed skill only where it can hand the results back to Shaka.

For the experimental branch switch and rollback, see the
[recorded trial](https://github.com/shakacode/shaka/blob/8217cfe3ed4e6cce89f4b182a8c0bec1e2b0cb81/docs/pstack.md#hand-maintenance-results-back-to-shaka).
