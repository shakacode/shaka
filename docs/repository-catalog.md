# Repository catalog

When you use Shaka across projects, a local catalog helps you find their settings
and avoid confusing repository prefixes. For example, `SHOP` and `DOCS` make
agent chat titles such as `SHOP PR #42 · Fix checkout` easy to distinguish.

Ask your agent:

```text
Refresh the Shaka catalog for my repositories. Report duplicate prefixes
and compare their review and merge settings before proposing changes.
```

The catalog records known repositories and reports duplicate prefixes. It does
not enforce globally unique names or synchronize settings automatically. The
agent checks each repository's trusted configuration and proposes any changes
through its own PR.

The catalog is local convenience data, not authority. Deleting it does not change
repository settings. Agents use the [catalog procedure](../skills/shaka/references/repository-catalog.md)
for paths, commands, and output fields.
