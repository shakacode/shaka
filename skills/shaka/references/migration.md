# Migrate repository configuration

## Migrate an older contract

Use `shaka seam migrate --root ROOT --from-ref OLD_DEFAULT_SHA` to preview a
migration of `.agents/shaka/config.yml` at that commit. A repository without that
file at the commit first converts with the steps in the changelog's breaking-changes entry.
Inspect every retained, moved, retired, and blocking field before
adding `--apply`. Settings the current contract accepts carry over unchanged, but
`--apply` rewrites the YAML, so restore any comments before committing. An existing
`.agents/shaka.md` stays as it is. It does not infer missing commands, review policy,
or merge authority. See the [migration checklist](https://github.com/shakacode/shaka/blob/main/internal/fleet.md#migration-checklist).

Older keys are deliberately rejected during this pilot:

| Old field | Replacement |
| --- | --- |
| `review.ci_review_agents`, `review.check`, `review.github_action_check` | `review.ci_review_jobs` |
| `review.reviewers`, `review.local_reviewers` | `review.local_review_agents` |
| `review.pace` | `review.ci_review_wait`; `swift` becomes `one`, `thorough` becomes `all` |
| `recovery.workspace_path`, `recovery.publish_locations`, `wip.include_locations` | `wip.include_checkout_path`; migration preserves the boolean value |
| `plan` | Point to the requirements document from `AGENTS.md` |
| YAML `commands` mapping | Fixed `.agents/shaka/bin/` scripts |
| `protection`, `trusted_actions`, `merge.method`, `merge.release` | Live GitHub settings, workflow files, or the repository's actual security tooling |
| `merge.auto_max_review_floor` | `merge.auto_merge_max_risk` (default `low`); move the paths its floors held into `high_risk_areas` or `medium_risk_areas`, then remove the old key |
| `pr_description.human_review_floors` | `high_risk_areas` for paths that must reach a person, or `medium_risk_areas` for paths that raise the risk to medium; remove the old key |

For the old command-path mapping, migrate in this order:

1. With the previous Shaka still installed, prepare the mapping-free YAML and fixed
   scripts. Preserve adapters at old paths. Where old and new roles conflict,
   make both run the stricter checks until the new contract is trusted.
2. Validate the candidate with the previous installation and old trusted SHA.
   Both this validation and the target checks below must pass before the
   migration PR merges through normal gates.
3. After switching to the verified target installation, remove obsolete adapters
   in a follow-up PR. The optional paths are `validate-local` and `trigger-hosted-ci`.

Before merging any shared settings migration, run the target helper's
`seam check --root ROOT --local` in a fresh checkout of the exact PR commit.
Review moved wrappers and run the affected local checks. Run a
`trigger-hosted-ci` wrapper only as part of an authorized CI run. Merge the PR
after the target settings and affected local checks pass. After merge,
check the new trusted default-branch SHA using the target helper's `seam check
--root ROOT --ref NEW_DEFAULT_SHA` before switching the active installation.

A newly renamed key can also make an older installation reject trusted policy.
Coordinate the contract change with the installation upgrade, including tasks
already running when the change merges.

Keep `version: 1` for configurations supported by Shaka 1.x. Apply the
[published compatibility policy](https://github.com/shakacode/shaka/blob/main/docs/migration.md#what-stays-compatible-in-1x)
when planning a change to the contract.

Finish by checking the new installation against the merged default-branch commit.
Report the installed revision, configuration changes, and any active tasks still
using the previous installation.

The old `swift` setting skipped CI review after a different-provider local review.
Migration uses `one` to preserve its CI backstop; choose `none` explicitly if you
want local review alone to satisfy review, regardless of provider.
