# Migrate repository configuration

Use `shaka seam migrate --root ROOT --from-ref OLD_DEFAULT_SHA` to preview a
migration. Inspect every retained, moved, retired, and blocking field before
adding `--apply`. It does not infer missing commands, review policy, or merge
authority. See the [migration checklist](../contributing/fleet.md#migration-checklist).

Older keys are deliberately rejected during this pilot:

| Old field or flag | Replacement |
| --- | --- |
| `review.ci_review_agents`, `review.check`, `review.github_action_check` | `review.ci_review_jobs` |
| `review.reviewers`, `review.local_reviewers` | `review.local_review_agents` |
| `--ci-review-agent`, `--review-check`, `--github-action-check` | `--ci-review-job` |
| `review.pace` | `review.ci_review_wait`; `swift` becomes `one`, `thorough` becomes `all` |
| `--pace swift` / `--pace thorough` | `--ci-review-wait one` / `--ci-review-wait all` |
| `recovery.workspace_path` | `recovery.publish_locations`; migration preserves the boolean value |
| YAML `commands` mapping | Fixed `.agents/bin/` scripts |
| `protection`, `trusted_actions`, `merge.method`, `merge.release` | Live GitHub settings, workflow files, or the repository's actual security tooling |

For the old command-path mapping, migrate in this order:

1. With the previous Shaka still installed, prepare the mapping-free YAML and fixed
   scripts. Preserve adapters at old paths. Where old and new roles conflict,
   make both run the stricter checks until the new contract is trusted.
2. Validate the candidate with the previous installation and old trusted SHA.
   Separately validate it with the target Shaka using `--local`. Both must pass
   before the migration PR merges through normal gates.
3. Upgrade Shaka, load the new default-branch SHA with `--ref`, then remove obsolete
   adapters in a follow-up PR. Optional names use hyphens: `validate-local` and
   `trigger-hosted-ci`.

A newly renamed key can also make an older installation reject trusted policy.
Coordinate the contract change with the installation upgrade, including tasks
already running when the change merges.

`version` remains `1` for pilot changes that reject old keys loudly. It becomes
`2` when an otherwise valid key changes meaning or default, or when repositories
outside the pilot depend on the contract. Unknown keys never silently take a
new meaning.


Finish by checking the new installation against the merged default-branch commit.
Report the installed revision, configuration changes, and any active tasks still
using the previous installation.

The old `swift` setting skipped CI review after a different-provider local review.
Migration uses `one` to preserve its CI backstop; choose `none` explicitly if you
want local review alone to satisfy review, regardless of provider.
