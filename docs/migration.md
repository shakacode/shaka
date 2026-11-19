# Update Shaka

## What stays compatible in 1.x

Starting with the first stable release, Shaka 1.x accepts valid
`.agents/shaka/config.yml` files written for an earlier 1.x release. It keeps the
meaning of their settings, the standard `.agents/shaka/bin/` command paths, and
documented `shaka` commands and options. The YAML field `version: 1` identifies
the configuration format. It stays `1` as you update between 1.x releases.

A 1.x release can add optional settings or commands. A rename, removal, or
default change that breaks an existing 1.x configuration or documented command
requires a major release. A breaking change to the configuration also requires
a new YAML format version. The upgrade guide for a breaking release
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

## Check your projects against 1.0

```text
Preview this project's settings against Shaka 1.0.0 and keep my active installation
Use the preview steps at https://shaka.shakacode.com/docs/migration#check-your-projects-against-10
```

Name any other projects you want checked. Your agent uses the target release in a
separate checkout and reports which projects pass. Passing projects can keep their
settings and command wrappers. If an individual setup fails, keep the current
installation while you review the reported settings or wrapper errors.

<details>
<summary>Run the checks from a terminal</summary>

Clone the official release tag in a separate directory. Use that checkout's
`skills/shaka/scripts/shaka` as the helper. Set `SHAKA_RUBY` to the absolute path
to Ruby 3.4 or later for the command. Use the project's verified default-branch
commit for `DEFAULT_SHA`.

- For team settings, run the helper with `seam check --root PROJECT --ref DEFAULT_SHA`
  in a clean checkout at that commit. Confirm it reports `trusted/ref` for the same SHA.
- For individual settings, run the helper with `seam private check --root PROJECT --ref DEFAULT_SHA`
  against the local copy that has those settings. The result reports any setting
  or wrapper that needs attention.

</details>

## Move shared pilot settings to 1.0

- For `.agents/shaka/config.yml` with retired keys, ask the agent to preview
  `shaka seam migrate` from the project's current default-branch commit. Review
  the retained settings, proposed replacements, and blockers before applying.
  The tool rewrites the YAML when applied, so restore any comments you use.
- For `.agents/agent-workflow.yml`, use the pinned converter in the
  [pilot changelog](https://github.com/shakacode/shaka/blob/b11f2f7d0d0cf3c7dd9ca78760a7a8c1eac708cb/CHANGELOG.md#removed).
  The preview identifies work you need to do before applying the conversion.

Before merging the settings PR, review its diff. In a fresh checkout of the
exact PR commit, run the target helper's `seam check --root PROJECT --local`
and the moved command wrappers. After the PR merges, check the new
default-branch commit with `--ref` as shown above before switching your active
installation.

If the old YAML maps command paths with `commands`, keep adapters at the old
paths. When the old and new paths overlap, keep the stricter checks in both.
Before merging, also validate with the previous Shaka installation and old
trusted SHA. Remove the adapters in a follow-up PR after switching installations.
