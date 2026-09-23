# Upgrade an existing installation

Ask your agent to update Shaka and adapt the repository configuration together:

```text
Upgrade this repository to the current Shaka pilot. Inspect the installed
version and our configuration, preserve local customizations, and prepare any
configuration changes as a PR. Tell me whether active tasks need to restart.
Keep our current review and merge choices.
```

Shaka is still a pilot, so settings can change between revisions. Let the agent
follow the [migration procedure](agents/migration.md) and review its diff before
merging. An installation upgrade alone may leave a repository's settings outdated.
