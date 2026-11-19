# Update Shaka

## What stays compatible in 1.x

Starting with the first stable release, Shaka 1.x accepts valid
`.agents/shaka/config.yml` files written for an earlier 1.x release. It keeps the
meaning of their settings, the standard `.agents/shaka/bin/` command paths, and
documented `shaka` commands and options. The YAML field `version: 1` identifies
the configuration format. It stays `1` as you update between 1.x releases.

A 1.x release can add optional settings or commands. A rename, removal, or
default change that breaks an existing 1.x configuration or documented command
requires a major release. The upgrade guide for a breaking release will name
the affected settings and show how to check the proposed changes before switching.

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

## Switch to a published release

```text
Install Shaka 1.0.0 and verify my project settings. Keep my previous installation available for rollback
```

Your agent checks the current installation and the target release. It installs
the release in a separate checkout and checks the project settings before you
start a new task. If you need to go back, ask it to restore the previous skill
links. Roll back any settings changes separately through the project's usual
review process.

## Move pilot settings to 1.0

Ask your agent to check the project's settings with the target release. If the
check passes, you can keep the file and its command wrappers as they are.

- For `.agents/shaka/config.yml` with retired keys, ask the agent to preview
  `shaka seam migrate` from the project's current default-branch commit. Review
  the retained settings, proposed replacements, and blockers before applying.
  The tool rewrites the YAML when applied, so restore any comments you use.
- For `.agents/agent-workflow.yml`, use the pinned converter in the
  [changelog's breaking changes](https://github.com/shakacode/shaka/blob/main/CHANGELOG.md#removed).
  The preview identifies work you need to do before applying the conversion.

Review the configuration diff and validate the new settings before adopting
them. Check the project again after the settings PR merges and before giving the
new installation a task.
