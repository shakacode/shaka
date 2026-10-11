# Upgrade an installation

Ask your agent:

```text
Update my Shaka installation. Preserve my customizations and check whether
this repository needs configuration changes. Keep its review and merge choices.
```

Shaka updates the installation in place from the Git repository and branch chosen
when you installed it. Your installation directory and agent links stay the same.
If files have local edits or the checkout no longer matches its installation
record, the update stops and leaves those changes for you to review.

Finish active Shaka chats before updating, because they may still need
its current files. Make customizations in a separate development checkout and
publish them to your fork before updating the installation.
Start a new chat after the update so it loads the updated skill.

## Replace managed copies with one dedicated installation

Earlier installers linked agents to separate copies of Shaka under versioned
directories. You can now point your agents directly at one dedicated checkout
that stays at the same path through updates.

Ask your agent:

```text
Move my default Shaka installation to one dedicated checkout. Respect my
chosen location, or use the default. Preserve towers, separate PR trials,
and every retained copy. Verify it and confirm one default Shaka entry.
```

Your agent creates or registers that checkout and redirects the selected agents' skill links.
It also removes a verified duplicate default Codex link, while preserving control
tower skills and separate PR trials. Choose a directory or use
`~/.agents/shaka`; `~/agent-tools/shaka` is one alternative.

Older copies stay where they are so active chats can continue using them.
Shaka does not automatically delete or expire them.

## Teams and forks

Agree on which Shaka repository and branch the team will use. Each person installs
it on their machine, chooses a directory, and asks their agent to update it using
the prompt above. The team does not need matching home-directory layouts.

If the team uses a fork, a maintainer first brings upstream changes into a
development checkout, reviews them, and pushes them to the team's chosen branch.
Team members can then update their installations from that branch.

## Upgrade a project's Shaka settings

Updating the installed tool does not move the Shaka configuration files committed
in your projects. Those changes belong in a separate PR for each affected project.

If a project still uses `.agents/agent-workflow.yml` and `.agents/bin/`, ask:

```text
Upgrade this repository's Shaka configuration to the .agents/shaka/ layout.
Preserve its review and merge choices, and prepare the change as a PR.
```

The agent previews the moves and repairs for review before applying them and
validates the new layout. Existing legacy layouts remain readable while a
migration PR is under review.

Shaka instructs your agent to check for updates once per new chat and tell you
when newer official commits are available. The installer also prints an update
reminder. These checks provide advice; they do not update your installation.
