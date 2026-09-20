# Install-local repository catalog

Shaka does not keep a central fleet registry. Each repository owns its display prefix
in the trusted `.agents/agent-workflow.yml` seam. An installation may rebuild a local
catalog of repositories it already knows about. That catalog is convenience data: it
is safe to delete, and missing or stale entries must not block `shaka seam check`,
`shaka prefix`, or other work inside a checkout.

## Location

Default home is `$SHAKA_HOME`, or `~/.shaka` when that variable is unset.

| Path | Role |
| --- | --- |
| `$SHAKA_HOME/repos.yml` | Registered checkout roots. Discovery source. |
| `$SHAKA_HOME/catalog.json` | Rebuilt index. Safe to delete. |

Neither file belongs in a public repository. Do not copy private repository names
into public artifacts.

## Discovery

`shaka repos add --root DIR` appends a realpath to `repos.yml`. Hosts may write the
same file themselves. Discovery stays in this install-local command; it does not
live in the portable GitHub or merge modules, and it does not scrape GitHub orgs.

A missing `repos.yml` is an empty root list. Refreshing then writes an empty
catalog.

## Refresh

```bash
shaka repos refresh
```

For each registered root, refresh reads `origin` for identity and canonical URL,
then loads the trusted default-branch seam through `origin/HEAD`. It does not trust
a candidate working tree. The effective prefix is the seam `repo_prefix` when
present, otherwise the [documented fallback](settings.md#repo_prefix).

Stdout and `catalog.json` use the same object:

```json
{
  "version": 1,
  "repositories": [
    {
      "identity": "shakacode/shaka",
      "url": "https://github.com/shakacode/shaka",
      "root": "/path/to/shaka",
      "prefix": "SHAKA",
      "prefix_source": "seam"
    }
  ],
  "duplicate_prefixes": {}
}
```

`identity` is always `owner/name`. Duplicate prefixes across **distinct**
`host/owner/name` keys are listed under `duplicate_prefixes` and printed on stderr;
refresh still writes the catalog and exits non-zero so a collision cannot silently
select the wrong repository. Two checkouts of the same host and identity with the
same prefix are not a collision. The same `owner/name` on different hosts is a
collision when the prefixes match. Catalog `url` values never keep remote userinfo.

## Direct operation

`shaka prefix --root DIR --ref REF` resolves one repository without reading the
catalog. Removing `catalog.json` does not remove seam metadata.
