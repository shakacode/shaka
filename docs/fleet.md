# V2 test fleet

This is the public inventory of repositories used to exercise Shaka while it is
developed. It tracks adoption; it is not a deployment system, policy engine, or
permission to change a consumer repository.

## Versions

Three different versions appear in this work:

| Name | Current value | Meaning |
| --- | --- | --- |
| Shaka version | `0.1.0.pre.1` | SemVer version of the installed skill and RubyGem. This is the fleet target. |
| Seam schema | `version: 1` | Integer field in `.agents/agent-workflow.yml`; it identifies the typed contract, not the product generation. |
| Product generation | V2 | The Shaka workflow described by this repository. V1 seams have no schema version and use a different set of keys. |

`shaka seam init` records the Shaka SemVer in `.agents/README.md`. The fleet table
records the same value so that a repository remains visible even before its migration
merges. A schema-valid file alone does not prove which Shaka release last reviewed it.

## Active fleet

| Repository | Default branch | Target Shaka | Schema | State | Evidence or next action |
| --- | --- | --- | ---: | --- | --- |
| [`shakacode/shaka`](https://github.com/shakacode/shaka) | `main` | `0.1.0.pre.1` | 1 | Source | This repository defines and validates the current contract. |
| [`shakacode/react-webpack-rails-tutorial`](https://github.com/shakacode/react-webpack-rails-tutorial) | `master` | `0.1.0.pre.1` | 1 | PR open | [Adoption PR #838](https://github.com/shakacode/react-webpack-rails-tutorial/pull/838); preserve its validation split, exact required-check name, and trusted-action allowlist. |

Add a repository here only when it is intentionally part of current Shaka testing.
Record an exact Shaka version, not `latest`, and link the adoption or upgrade PR. Remove
it when testing ends; the repository's own history remains the durable delivery record.
Private consumers belong in the private repository catalog, not in this public file.

## Rollout status and selection

New consumer migrations are paused while Shaka's script contract is being redesigned.
Do not start another migration from this inventory until that work settles. Migrations
already in progress remain tracked; recheck their YAML and wrappers against the finished
script contract instead of discarding the work.

For React on Rails, the source-backed projects on
[reactonrails.com/examples](https://reactonrails.com/examples/) are the priority
candidate set. The page currently points to these public repositories, in display
order:

1. [`shakacode/react-on-rails-demo-flagship`](https://github.com/shakacode/react-on-rails-demo-flagship)
2. [`shakacode/react-on-rails-demo-marketplace-rsc`](https://github.com/shakacode/react-on-rails-demo-marketplace-rsc)
3. [`shakacode/react-on-rails-demo-hacker-news-rsc`](https://github.com/shakacode/react-on-rails-demo-hacker-news-rsc)
4. [`shakacode/react_on_rails-demo-octochangelog-on-rails-pro`](https://github.com/shakacode/react_on_rails-demo-octochangelog-on-rails-pro)
5. [`shakacode/react-on-rails-demo-gumroad-rsc`](https://github.com/shakacode/react-on-rails-demo-gumroad-rsc)
6. [`shakacode/react-on-rails-starter-tanstack`](https://github.com/shakacode/react-on-rails-starter-tanstack)
7. [`shakacode/react-webpack-rails-tutorial`](https://github.com/shakacode/react-webpack-rails-tutorial), which the page labels as the legacy tutorial and whose migration is already in progress in the active table above

Being on that page makes a repository a priority candidate or confirms the priority of
an already-active member; it does not automatically add a repository to the fleet.
Confirm that a new migration is selected and record PR evidence before adding it to the
active table. Exclude archived repositories from both the active fleet and migration
selection unless they are deliberately restored. Recheck the examples page and GitHub
archive state when choosing each next repository rather than treating this dated list
as permanent.

## Public V1 discovery inventory

The following default branches had an unversioned V1 seam when checked on
2026-09-19. This is discovery input, not a priority queue or automatic fleet membership.
Select React on Rails migrations using the rules above, move a repository to the active
table only when its migration is selected, and update it through its own PR.

| Repository | Default branch | Migration note |
| --- | --- | --- |
| `shakacode/agent-workflows` | `main` | Preserve hosted-QA, contributor-intake, reviewer, human-attention, and trusted-action policy outside the V2 seam; retire only V1 coordination machinery. |
| `shakacode/control-plane-flow` | `main` | Preserve the release-QA runbook, contributor-intake boundary, review gate, and trusted actions. |
| `shakacode/cypress-playwright-on-rails` | `master` | Add or select a setup wrapper; preserve contributor intake and the existing review gate. |
| `shakacode/react-on-rails-demo-flagship` | `main` | Confirm live protection and review policy before replacing the minimal V1 seam. |
| `shakacode/react-on-rails-demo-hacker-news-rsc` | `main` | Preserve the review-app and current-head merge conditions documented by the repository. |
| `shakacode/react-on-rails-demo-gumroad-rsc` | `main` | Preserve the full-check and resolved-thread merge gate, advisory-reviewer rule, and explicit absence of merge authority. |
| `shakacode/react-on-rails-demo-marketplace-rsc` | `main` | Keep the large QA-stress contract and operational scripts in their dedicated configuration; V2 does not replace them. |
| `shakacode/react-on-rails-demo-ssr-hmr` | `master` | Preserve the full-check and resolved-thread merge gate. |
| `shakacode/react-on-rails-starter-tanstack` | `main` | Preserve the full-check and resolved-thread gate and the risk-based distinction between low-risk automation and maintainer-gated changes. |
| `shakacode/react-on-rails-demos` | `main` | Preserve Lefthook, monorepo formatting, and review-app conditions that exceed the local validation wrapper. |
| `shakacode/react-ppr-from-scratch` | `main` | Confirm live protection and review policy before replacing the minimal V1 seam. |
| `shakacode/react_on_rails` | `main` | Do not migrate as an ordinary immediate-merge consumer: it requires a merge queue, hosted-CI routing, secret redaction, and a public-comment trust boundary. |
| `shakacode/react_on_rails-demo-octochangelog-on-rails-pro` | `main` | Preserve the full-check and resolved-thread gate and CI parity across Ruby scanning, lint, PostgreSQL, and renderer tests. |
| `shakacode/react_on_rails_rsc` | `main` | Preserve the full-check and resolved-thread merge gate and the existing hosted-CI behavior. |
| `shakacode/shakapacker` | `main` | Preserve `merge-readiness-check` and its tests by composing it into validation or retaining the repository instruction explicitly. |
| `shakacode/shakaperf` | `main` | Confirm live protection and review policy before replacing the minimal V1 seam. |

## V1 to V2 YAML map

V1 accepted open-ended prose keys. V2 rejects unknown keys and represents only the
portable delivery contract. Migration therefore means deciding where each behavior
lives; it does not mean deleting every V1 key and hoping the defaults are equivalent.

| V1 setting | V2 destination | Migration rule |
| --- | --- | --- |
| `base_branch` | `base_branch` | Copy after verifying the live default branch. |
| Command descriptions and `.agents/bin/*` | `commands` | Name executable repository paths for required `setup`, `validate`, and `test`; add optional `validate_local` and `trigger_hosted_ci` only when real wrappers exist. |
| `review_gate`, `automation_reviewers` | `review` | Translate the actual required review and ordered available reviewers. Keep richer human conditions in `AGENTS.md`. |
| `merge_submission`, `autonomous_merge`, `approval_exempt` | `merge` plus `AGENTS.md` | Choose `ask` or authorized `auto`. V2 supports immediate squash merge only; a merge-queue-only repository is not equivalent and must remain blocked or use a separately approved path. |
| Branch naming and `repo_prefix` | `branches.name` | Record the real branch template. Do not carry a coordination prefix forward unless the repository still needs it. |
| Live branch rules | `protection` | Read required checks and mutation rules from GitHub. Do not infer them from workflow filenames. |
| `trusted_actions` | `trusted_actions` | Preserve the audited allowlist exactly, then review additions or removals separately. |
| `hosted_ci_trigger`, `ci_change_detector`, `ci_parity_environment` | `commands.validate_local`, `commands.trigger_hosted_ci`, wrappers, and `AGENTS.md` | Keep executable routing in scripts and human decision rules in instructions. Do not reduce full validation to the fast local subset. |
| Changelog, benchmark, release-QA, hosted-QA, security-preflight, contributor-intake, secret-redaction, trusted-actor, and QA-stress settings | Existing dedicated files or `AGENTS.md` | These remain repository policy. V2's narrower YAML does not retire the behavior. |
| Coordination backend, claim labels, lane limits, follow-up prefixes, and V1 fleet controls | No V2 seam key | Retire them only when the repository no longer uses the V1 coordination system. Do not import that system into Shaka. |

## Script differences

V2 does not require every repository to use the same commands. It requires three
semantic roles and executes the repository-owned wrappers named by the seam:

- `setup`: prepare the checkout without inventing a new toolchain;
- `validate`: run the complete local or CI-equivalent gate used before review;
- `test`: run focused tests when the task supplies paths or arguments.

`validate_local` is an optional faster subset. `trigger_hosted_ci` is an optional
explicit hosted-CI entrance and requires `validate_local`. Existing `build`, `docs`,
`lint`, `ci-detect`, database, server, and QA scripts may remain in `.agents/bin`; V2
does not expose them as top-level contract keys. Compose them behind the three required
roles when they are part of delivery.

Repository-specific script notes found during the V1 audit:

- `react_on_rails` has seam-doctor and drift-manifest programs, `ci-detect`, and
  `shared-skill-dir`. These are V1 management or repository tooling, not generic V2
  commands. Its merge queue and hosted-CI protocol block a mechanical conversion.
- `shakapacker` has a tested `merge-readiness-check`; a migration must not leave that
  gate unreachable.
- `react-on-rails-demo-marketplace-rsc` has install, serve, seed, reset, and QA-stress
  scripts. They stay repository-owned operational tools.
- Several V1 consumers have no `.agents/bin/setup`; each needs a truthful no-op or real
  setup wrapper before its V2 seam can validate.
- The tutorial intentionally maps V2 `validate` to its existing `.agents/bin/test`
  because that wrapper owns the full CI-equivalent run. It maps `validate_local` to the
  RuboCop-only `.agents/bin/validate`. Semantic roles matter more than filenames.

## Migration checklist

For each selected repository:

1. Read the default-branch V1 YAML, `AGENTS.md`, `.agents/bin/README.md`, every wrapper
   selected for V2, and live GitHub protection.
2. Classify every V1 key using the table above. Record repository-specific behavior in
   the PR; preserve it in V2, `AGENTS.md`, or its dedicated config, or explain why it is
   intentionally retired.
3. Do not run `shaka seam init` over the existing seam: the initializer is for a new
   repository and refuses conflicting YAML or wrappers. Write the candidate V2 YAML by
   hand from the [settings guide](settings.md), retain suitable wrappers, and add only
   the missing executable roles. Record the target Shaka SemVer in the adoption PR and
   fleet table; the current initializer has no in-place migration command.
4. Validate the working tree with the trusted installed `shaka seam check --root ROOT`.
   Commit the candidate, check out that revision in a clean worktree, and run
   `shaka seam check --root ROOT --ref HEAD_SHA`. The ref pins the YAML; wrapper
   existence and executable bits come from the checkout, so it must match `HEAD_SHA`.
   Run the repository's focused checks and full validation in that worktree.
5. Open one repository PR pinned to the tested head. Update this fleet table only from
   verified PR or merge evidence.
