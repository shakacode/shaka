# Upgrade an installation

Ask your agent:

```text
Update my Shaka installation. Preserve my customizations and check whether
this repository needs configuration changes. Keep its review and merge choices.
```

Updates follow the recorded origin, branch, location, and links; dirty or unexpected
checkouts stop them. Pause active chats first and keep development separate.

## Move from managed copies

Ask your agent:

```text
Move my default Shaka installation to one dedicated checkout. Respect my
chosen location, or use the default. Preserve towers, separate PR trials,
and every retained copy. Verify it and confirm one default Shaka entry.
```

Follow the [installation and migration procedure](../skills/shaka/references/official-installation.md).
Default: `~/.local/share/shaka/source`; `~/agent-tools/shaka` is an optional example.
It changes recognized links and retires the standard duplicate Codex alias.
Older copies remain for active chats, with no automatic cleanup or expiry.

## Teams and forks

Each machine registers its directory and follows the same procedure. Agree on
the origin and branch; directory choices and synchronization remain separate.
For a fork, integrate upstream changes in a development checkout and publish to
its selected branch before updating. Project configuration follows the separate
[upgrade procedure](../skills/shaka/references/migration.md).

If the repository already has a valid version-one Shaka configuration under
`.agents/`, ask: “Upgrade this repository's Shaka configuration layout.” The agent
will preview the moves and repairs for review before applying them. The
[layout upgrade procedure](../skills/shaka/references/migration.md#upgrade-the-configuration-layout)
explains recovery and validation. Existing legacy layouts remain readable while a
migration PR is under review.

Automatic update notifications are not currently implemented.
