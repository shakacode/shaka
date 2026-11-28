# Migrate repository configuration

## Migrate an older contract

For an ordinary settings migration with an already suitable installed Shaka,
use that trusted installed helper and skip the separate checkout and
installation switch below (still coordinate the pause below if any installation
in use rejects renamed keys). For a release cutover, prepare a separate
detached tag checkout with no local branches following
[Install a published release](official-installation.md#install-a-published-release)
while the previous installation stays active, and record its `HEAD` commit. Use
the absolute path to that checkout's `skills/shaka/scripts/shaka` and set
`SHAKA_RUBY` to the absolute path to Ruby 3.4 or later for each invocation of
the target helper.

In this section, "the helper" is the target helper for a release cutover and
otherwise the trusted installed helper. Run the helper's `seam migrate --root ROOT
--from-ref OLD_DEFAULT_SHA` to preview the migration of `.agents/shaka/config.yml` at
that commit. If that
file is absent, follow the converter steps in the changelog's breaking-changes entry.
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
2. In the fresh checkout used for the target checks below, verify the retained
   adapters and validate using the previous installation's helper and old trusted SHA.
   Both validations must pass before the migration PR merges through normal gates.
3. After the merged default-branch SHA verifies with the helper as
   `trusted/ref`, and after affected users no longer need the old paths, remove
   obsolete adapters in a follow-up PR. When this migration also switches
   installations, wait until that switch finishes before the cleanup PR. The
   optional paths are `validate-local` and `trigger-hosted-ci`.

Before merging any shared settings migration, run `seam check --root ROOT --ref PR_SHA`
with the helper in a fresh checkout of the exact PR commit.
It applies the commit rules the post-merge check uses, including fixed wrapper
modes, symlink targets, and files the settings name. Treat the result as a
diagnostic only: `PR_SHA` is a candidate. Disregard the report's `trusted/ref` mode
and `grants_policy: true`; policy still comes only from the verified default-branch
SHA. The helper does not check retained adapters; check each with
`git ls-tree PR_SHA -- PATH` and require mode `100755` on the file, or on the
tracked executable a relative in-repository symlink resolves to.
Review moved wrappers and run the affected local checks. Run a
`trigger-hosted-ci` wrapper only as part of an authorized CI run. Merge the PR
after the target settings, tracked wrappers, and affected local checks pass.
After merge, check the new trusted default-branch SHA in a clean checkout with
no selected preview using the helper's `seam check --root ROOT --ref
NEW_DEFAULT_SHA`, and confirm it reports `trusted/ref` for `NEW_DEFAULT_SHA`.
During a release cutover, switch the active installation only after that check
passes: confirm the verified preview checkout's `HEAD` still matches the
recorded commit, then follow
[Install a published release](official-installation.md#install-a-published-release)
(including [Before take-over](official-installation.md#before-take-over)) with
that verified checkout as `--directory DIR`.

A newly renamed key can also make an older installation reject trusted policy.
Whenever a migration introduces renamed keys that any installation in use
rejects, finish running affected tasks on those installations and hold new ones
before merging the settings PR, then resume once the helper verifies
`trusted/ref` for the merged default-branch SHA and affected installations are
ready.

Keep `version: 1` for configurations supported by Shaka 1.x. Apply the
[published compatibility policy](https://github.com/shakacode/shaka/blob/main/docs/migration.md#what-stays-compatible-in-1x)
when planning a change to the contract.

Finish by checking the active installation against the merged default-branch
commit (confirming `trusted/ref` for that SHA). Report the installed revision,
configuration changes, and any active tasks still using a previous installation.

The old `swift` setting skipped CI review after a different-provider local review.
Migration uses `one` to preserve its CI backstop; choose `none` explicitly if you
want local review alone to satisfy review, regardless of provider.
