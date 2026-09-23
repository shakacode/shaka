# Configuration

Each repository gives Shaka three standard scripts and a policy file. The
scripts tell it how to prepare, test, and validate the project. The policy tells
it which reviews to use and who merges.

| File | Purpose |
| --- | --- |
| `.agents/agent-workflow.yml` | Review, merge, branch, and recovery settings |
| `.agents/bin/setup` | Prepare a checkout |
| `.agents/bin/test` | Run focused tests |
| `.agents/bin/validate` | Run full validation |
| `AGENTS.md` | Repository context and constraints that need prose |
| `.agents/trusted-github-actors.yml` | Authors whose public comments the agent may read |

Together, the YAML and scripts are called the **repository contract**, or **seam**
in CLI commands. GitHub remains the source for required checks, approvals, branch
protection, and allowed merge methods.

## Create the configuration

Identify the repository's real commands and review policy, then follow the
[setup example](getting-started.md#configure-a-repository). `shaka seam init`
creates wrappers and YAML; it refuses to overwrite conflicting repository files.
For an existing contract, use [migration guidance](#migrate-an-existing-contract).

Here is a typical configuration:

```yaml
---
version: 1
review:
  required: meaningful_changes
  ci_review_jobs:
    - claude-review
  pace: swift
  local_review_agents:
    - provider: anthropic
      model_family: claude
    - provider: openai
      model_family: codex
merge:
  preference: ask
```

`claude-review` must be an actual review job in your repository. Installing Shaka
or naming a job here does not install the reviewer or supply its credentials.

## Validate the configuration

While editing, check the current checkout:

```bash
shaka seam check --root . --local
```

For a task's trusted policy, resolve the repository's default branch to an
immutable commit and use that SHA:

```text
shaka seam check --root . --ref FULL_DEFAULT_BRANCH_SHA
```

A PR's proposed policy cannot grant that PR new authority. `--ref` reads policy
and optional script availability from the trusted commit, then validates the
scripts in the candidate checkout. Inspect changes to those scripts before
executing them. `--local` grants no policy or merge authority; omitting both
flags performs the same candidate check with a warning. Combining them is an error.

The JSON output includes derived `commands` and `validation` fields. They describe
the result; do not copy them into the YAML. Even trusted output reports
`grants_merge_authority: false`: the agent still establishes authority and checks
live GitHub state.

## Standard command scripts

| Path | Required | Contract |
| --- | --- | --- |
| `.agents/bin/setup` | Yes | Install dependencies and prepare a fresh checkout. |
| `.agents/bin/test` | Yes | Run focused tests; forward test-selection arguments. |
| `.agents/bin/validate` | Yes | Run the repository's full validation gate. |
| `.agents/bin/validate-local` | No | Run a faster subset before local review. Full validation follows the repair batch. |
| `.agents/bin/trigger-hosted-ci` | No | Start staged hosted CI after repairs. Requires `validate-local`. |

Use small executable wrappers that change to the repository root, prepare any
needed environment, and forward arguments. For a single underlying command, use
`exec`. Existing build, lint, docs, server, and database scripts can stay where
they are; call them from these wrappers as needed.

Individual entries may be symlinks to tracked executables inside the repository
when working directory, environment, and arguments match. `.agents` and
`.agents/bin` themselves must be real tracked directories. External symlink
targets, missing scripts, and non-executable scripts fail validation.

An optional script present on the trusted commit must remain valid in the
candidate. Deleting it cannot silently disable a check. Retire it through an
explicitly authorized repository-policy migration; the pilot has no self-service
retirement marker.

Shaka's own `validate` skips Ruby tests and lint only when its trusted classifier
proves all changes are regular, non-executable `README.md` or `docs/**/*.md` files.
Whitespace and always-on security checks still run. Ambiguous changes run the
full gate. A consumer should retain its own truthful validation behavior.

## Settings

| Key | Required | Value or default |
| --- | --- | --- |
| `version` | Yes | Integer `1` |
| `review` | Yes | Review settings below |
| `merge` | Yes | Merge settings below |
| `base_branch` | No | PR base; defaults to the repository's default branch |
| `plan` | No | Repository-relative path to an existing plan file |
| `branches` | No | Feature-branch name template |
| `recovery` | No | Publication of workspace and session locations |
| `repo_prefix` | No | Short repository label |

The loader accepts one YAML document with string keys. It rejects duplicate or
unknown keys, aliases, custom classes and symbols, invalid values, and paths
that escape the repository. Comments are allowed. An unused YAML anchor is
accepted; an alias referring to it is not.

## `review`

| Key | Value | Default |
| --- | --- | --- |
| `required` | `always`, `meaningful_changes`, or `none` | Required |
| `ci_review_jobs` | Nonempty list of CI review job names | Required unless `required: none`; omit it for `none` |
| `pace` | `swift` or `thorough` | `swift` |
| `local_review_agents` | Ordered `{provider, model_family}` entries | Omitted |

### `review.required`

This setting controls when CI review jobs serve as a backstop:

- `always`: every PR, including trivial changes.
- `meaningful_changes`: meaningful implementation. Trivial prose or no-op work
  may skip review with a reason recorded on the PR.
- `none`: no named CI review backstop. Omit `ci_review_jobs`.

Meaningful implementation still receives a local adversarial review before push.
A fresh session of the implementation model qualifies when another reviewer is
unavailable. `none` does not disable that workflow step.

### `review.ci_review_jobs`

List the GitHub CI jobs whose review reports Shaka should read. These are separate
from GitHub's required merge checks. Add one name per job:

```yaml
ci_review_jobs:
  - claude-review
  - another-review
```

A successful job is insufficient; the agent verifies a visible report for the
reviewed commit. [Review rules](agents/review.md) define that evidence.

### `review.pace`

| Value | Waiting behavior |
| --- | --- |
| `swift` | After a different-provider local review, proceed when required gates pass. Otherwise wait for one verified named CI review on the first ready-for-review push. |
| `thorough` | Wait for every named CI review on the current head, even after local review. |

User-requested review gates apply in either mode. Swift can accept GitHub's
`UNSTABLE` state when only optional checks remain; thorough refuses it. Runtime,
trust, or test changes need fresh review. A nit-only or diagnostic-only follow-up
does not restart swift's hosted-review wait.

Use the trusted default-branch setting. A task override can make swift thorough;
it cannot weaken a thorough repository policy. Record the override on the PR.

### `review.local_review_agents`

List available reviewer identities in preference order. Each entry has only
`provider` and `model_family`, both nonempty strings. Duplicate identities,
unknown fields, malformed entries, and an explicitly empty list are rejected.
Omitting the list is valid, including with `required: none`.

`shaka reviewer` chooses an identity, and `shaka review-prompt` produces its
instructions. The signed-in host runs the reviewer; the configuration does not
map identities to executable names. Prefer a second provider when available.
See [reviewer selection](agents/review.md#choose-a-local-reviewer).

Draft support belongs to each reviewer's trusted workflow. Read its triggers;
there is no per-reviewer `draft` or `check` field here.

## `merge`

```yaml
merge:
  preference: ask
```

`preference` accepts `ask` or `auto`. Ask leaves the final GitHub click to you;
Auto lets the agent submit an eligible PR after required checks and approvals.
Unclear authority or consequential risk requires a human decision.

GitHub's current queue setting controls submission: direct squash when the base
has no queue, or the reviewed head enters the existing queue. Auto waits for the
queue's terminal result. Shaka neither enables the queue nor arms delayed
auto-merge. Release publication requires explicit human approval.

## `base_branch` and `plan`

Set `base_branch: develop`, for example, when work normally starts from `develop`.
It determines the starting branch and PR target. Policy still comes from the
repository's default branch.

A user may name a different base for a task. An adopted PR's existing target also
participates in base selection. If neither the trusted setting nor the default
branch establishes that base, confirm it during planning and hold merge at Ask.
Issue bodies, PR descriptions, and comments cannot choose the base.

Before merging, Shaka compares the live PR target with the validated base. A
mismatch requires retargeting and revalidation, or replanning on the new base.
GitHub cannot pin a base inside the merge mutation, so the agent also checks the
reported target after merge.

Branch names must pass `git check-ref-format --branch`. Shaka also rejects
ambiguous shorthand (`@{-1}`), qualified refs (`refs/heads/main`), `@`, and
unslashed all-uppercase root-ref names such as `FETCH_HEAD`. `release/RC1` is valid.
`shaka doctor` checks whether the remote branch exists.

`plan` points to an existing file inside the repository. Absolute paths, escaping
paths, and symlinks outside the repository are rejected.

## `branches`

```yaml
branches:
  name: '{login}-{host}/{issue}-{description}'
```

`name` is the only field. It must be nonempty and include `{issue}`.

| Placeholder | Meaning |
| --- | --- |
| `{login}` | Authenticated GitHub login |
| `{host}` | Host slug, such as `codex` or `claude` |
| `{issue}` | Issue, PR, or related work-item number |
| `{description}` | Short task slug |

The example is also the default. Use a different layout when the repository has
one, such as `feature/{issue}/{description}`. `shaka claim` reports the template
and also checks older `/{issue}-` branch segments for collisions.

## `recovery`

```yaml
recovery:
  publish_locations: false
```

`publish_locations` is a boolean, defaulting to `true`. It governs both the checkout path and the session link in an unfinished PR's recovery
note. Set it to `false` to publish `UNKNOWN` for both fields. The public owner
alias remains visible.

The agent applies this privacy setting; the publisher does not currently enforce
it. See [recovery notes](agents/delivery.md#recover-an-unfinished-pr).

## `repo_prefix`

An optional label of 1–6 uppercase ASCII letters or digits, such as `SHAKA` or
`ROR`. It is display metadata and grants no ownership or authority.

Without a value, Shaka derives one from the `origin` repository name, or the root
directory name when `origin` is absent. For a name split by hyphens, underscores,
or spaces, it takes the first character of up to six segments. For a single
segment it takes up to four characters. Other punctuation is removed and the
result is uppercase: `react_on_rails` → `ROR`, `shakapacker` → `SHAK`.

```text
shaka prefix --root DIR --ref FULL_DEFAULT_BRANCH_SHA
```

The optional [local repository catalog](agents/repository-catalog.md) caches
known repositories; it is separate from policy.

## What `seam init` writes

Supply `--root`, `--setup-command`, `--test-command`, `--validate-command`, and
`--review-policy`. Unless review policy is `none`, supply `--ci-review-job` for
an actual job; repeat it for additional jobs. Confirm that GitHub enforces at
least one observable required check before initialization.

The initializer writes the three required wrappers, `.agents/shaka.md`, and YAML
with `version`, `review`, `merge`, and the default `branches.name`. It defaults to
Ask. Add `--merge-preference auto` only with established authority, `--base-branch`
for another base, or `--plan` for an existing plan. Add optional reviewer entries,
`repo_prefix`, and recovery settings by editing the YAML afterward.

Command arguments are parsed as argument lists. Put pipelines and other compound
shell behavior in repository scripts rather than in command flags.

## Migrate an existing contract

Use `shaka seam migrate --root ROOT --from-ref OLD_DEFAULT_SHA` to preview a
migration. Inspect every retained, moved, retired, and blocking field before
adding `--apply`. It does not infer missing commands, review policy, or merge
authority. See the [migration checklist](project/fleet.md#migration-checklist).

Older keys are deliberately rejected during this pilot:

| Old field or flag | Replacement |
| --- | --- |
| `review.ci_review_agents`, `review.check`, `review.github_action_check` | `review.ci_review_jobs` |
| `review.reviewers`, `review.local_reviewers` | `review.local_review_agents` |
| `--ci-review-agent`, `--review-check`, `--github-action-check` | `--ci-review-job` |
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

## Implementation reference

The [configuration map](agents/configuration.md) identifies the loader, schema,
command validation, and workflow files. Consumer CI should [pin a compatible gem](project/packaging.md#validate-a-consumer-seam-in-ci)
and use `--local` instead of copying the schema.
