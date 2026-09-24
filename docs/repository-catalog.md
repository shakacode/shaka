# Repository catalog

A local catalog helps compare settings across projects and spot duplicate chat-title
prefixes. For example, `SHOP PR #42 · Fix checkout` is easy to distinguish from a
`DOCS` task.

```text
Refresh the Shaka catalog for my repositories. Report duplicate prefixes
and compare their review and merge settings before proposing changes.
```

The catalog reports differences; it does not synchronize settings or enforce unique
prefixes. The agent checks each repository's trusted configuration and proposes
changes through that repository's PR.

Deleting the catalog does not change repository settings. See the agent's
[catalog procedure](../skills/shaka/references/repository-catalog.md) for commands and file locations.
