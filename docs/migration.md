# Update Shaka

## What stays compatible in 1.x

Starting with the first stable release, Shaka 1.x accepts valid
`.agents/shaka/config.yml` files written for an earlier 1.x release. It keeps the
meaning of their settings, the standard `.agents/shaka/bin/` command paths, and
documented `shaka` commands and options. The YAML field `version: 1` identifies
the configuration format. It stays `1` as you update between 1.x releases.

A 1.x release can add optional settings or commands. A rename, removal, or
default change that breaks an existing 1.x configuration or documented command
requires a major release. A breaking change to a setting's meaning or default
also requires a new YAML format version. The upgrade guide for a breaking release
will name the affected settings and show how to check the proposed changes before
switching. This is the release policy. Before switching, your agent can validate
your configuration and command wrappers with the target release, using the check
for your team or individual settings.

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

## Move pilot settings to 1.0

Before switching your active installation, ask your agent to check your project
settings against Shaka 1.0 in a separate checkout. If the check passes, you can
keep the file and its command wrappers as they are.

- For `.agents/shaka/config.yml` with retired keys, ask the agent to preview
  `shaka seam migrate` from the project's current default-branch commit. Review
  the retained settings, proposed replacements, and blockers before applying.
  The tool rewrites the YAML when applied, so restore any comments you use.
- For `.agents/agent-workflow.yml`, use the pinned converter in the
  [pilot changelog](https://github.com/shakacode/shaka/blob/b11f2f7d0d0cf3c7dd9ca78760a7a8c1eac708cb/CHANGELOG.md#removed).
  The preview identifies work you need to do before applying the conversion.

Review the configuration diff, validate the new settings with the target release,
and merge the settings PR before switching your active installation. Check the
merged default-branch configuration with the target release before switching.

## Switch to a published release

Ask for a compatibility check before switching.

```text
Check this project's settings against Shaka 1.0.0 and report whether they are ready for an upgrade
```

The switch affects every project that uses the moved skill links. Name any other
projects you want checked. The check keeps your current installation active.

Once the selected projects are ready, ask your agent to switch to the checked
release and keep the previous installation available for rollback.

If you need to go back, ask the agent to restore the previous links. Roll back
any settings changes through the project's usual review process.
