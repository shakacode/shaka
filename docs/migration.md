# Update Shaka

## What stays compatible in 1.x

Starting with the first stable release, Shaka 1.x accepts valid
`.agents/shaka/config.yml` files written for an earlier 1.x release. It keeps the
meaning of their settings and the standard `.agents/shaka/bin/` command paths.
The YAML field `version: 1` identifies the configuration format. It stays `1` as
you update between 1.x releases.

The `/shaka` skill (`$shaka` in Codex) and the commands you, your CI, or your
scripts run directly keep the options and behavior that this documentation
(the public guides at shaka.shakacode.com) describes for them:

| Command | What you use it for |
| --- | --- |
| `shaka install`, `shaka-install` from the gem, or `bin/install` in a clone | Install, update, verify, repair, or check the installation |
| `shaka doctor` | Check the installation and the project's setup |
| `shaka update-check` | See whether a branch install is behind, or which release is pinned |
| `shaka seam check` | Check team settings at a commit or in your working tree |
| `shaka seam private check` | Check individual settings |
| `shaka configure settings` | See the settings a task in this project uses |
| `shaka enforcement` | List which rules code enforces and which rely on the agent |

The helper's path inside an installation, `skills/shaka/scripts/shaka`, also stays
the same, so a scheduled update check keeps working.

Other `shaka` commands, such as `description`, `review run`, and `merge`, are
steps the Shaka workflow runs for your agent. So are commands a guide asks your
agent to run for you, such as `shaka companions`. Each release ships them together
with the skill that calls them, so a 1.x release can change them. Don't build
your own scripts on them. Development aids for people working on Shaka itself,
such as `shaka workflow` in [fork and hack](fork-and-hack.md), can change too.

A 1.x release can add optional settings or commands. A rename, removal, or
default change that breaks an existing 1.x configuration or a command in the
table requires a major release. A breaking change to the configuration also requires
a new YAML format version. The upgrade guide for a breaking release
will name the affected settings and show how to check the proposed changes before
switching. Before switching, your agent can check your settings and wrapper paths
with the target release.

## Update a branch installation

Shaka instructs your agent to check for updates and tell you when one is available.
Finish active Shaka chats, then ask:

```text
Update my Shaka installation
```

Start a new chat after updating.

An installation from your own fork updates that fork's branch. It does not
pull upstream by itself. Bring upstream changes in by
[syncing the fork](fork-and-hack.md#keep-your-fork-current) first.

## Check your projects against 1.0

```text
Preview this project's settings against Shaka 1.0.0 and keep my active installation
Use the preview steps at https://shaka.shakacode.com/docs/migration#check-your-projects-against-10
```

Name any other projects you want checked. Your agent uses the target release in a
separate checkout to check the settings and confirm the command wrapper files are
executable. The preview leaves wrapper execution to your normal task checks. If
an individual setup fails, keep the current installation while you review the
reported errors. When every project passes, switch with the verified-checkout prompt under
[keep a tested release](manual-installation.md#keep-a-tested-release).

<details>
<summary>Ask your agent to run the checks</summary>

```text
Prepare a branchless detached checkout of Shaka 1.0.0 for this project's compatibility checks. Keep my current installation. Use the official Install a published release clone and inspect steps, then run the applicable team or individual seam check for this project's settings against its verified default-branch commit
```

Your agent prepares the checkout, records its `HEAD`, and runs the check that
matches the settings in use:

- Team settings: `seam check --root PROJECT --ref DEFAULT_SHA` in a clean
  checkout at that commit, requiring `trusted/ref` for the same SHA before a
  switch (a selected settings preview can report `preview/local` instead).
- Individual settings: `seam private check --root PROJECT --ref DEFAULT_SHA`
  against the local copy that has those settings, treating a successful private
  report as local validation for that setup.

</details>

## Move shared pilot settings to 1.0

```text
Preview a migration of this repository's shared pilot settings using the migration procedure in the official Shaka 1.0.0 tag. Keep my current installation and show me the proposed changes and blockers before applying
```

- For `.agents/shaka/config.yml` with retired keys, your agent previews
  `seam migrate` with the 1.0.0 helper against the project's current
  default-branch commit.
  Applying the migration rewrites the YAML, so restore any comments you use.
- For `.agents/agent-workflow.yml`, use the pinned converter in the
  [pilot changelog](https://github.com/shakacode/shaka/blob/b11f2f7d0d0cf3c7dd9ca78760a7a8c1eac708cb/CHANGELOG.md#removed).
  The preview identifies work you need to do before applying the conversion.

Review the settings PR and its checks. Ask your agent whether any installation
still in use would reject the merged contract (renamed keys, dropped
command-path mappings, or other validation failures). When the answer is yes or
unknown, ask it to finish running affected tasks and hold new ones before
merging, then switch with the verified-checkout prompt under
[keep a tested release](manual-installation.md#keep-a-tested-release) once the
merged commit passes.
