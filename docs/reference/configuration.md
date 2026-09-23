# Configuration reference

This is the shared reference for `.agents/agent-workflow.yml` and `.agents/bin/`.
For setup, [ask your agent to configure the repository](../configuration.md).

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
| `version` | Yes | Configuration format version: integer `1`. Independent of the Shaka release version. |
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
| `wait_for_all_ci_reviewers` | Boolean | `false` |
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
reviewed commit. [Review rules](../agents/review.md) define that evidence.

### `review.wait_for_all_ci_reviewers`

| Value | Waiting behavior |
| --- | --- |
| `false` | After a different-provider local review, proceed when required gates pass. Otherwise wait for one verified named CI review on the first ready-for-review push. |
| `true` | Wait for every named CI review on the current head, even after local review. |

User-requested review gates apply with either value. With `false`, GitHub's
`UNSTABLE` state is allowed when only optional checks remain; `true` refuses it. Runtime,
trust, or test changes need fresh review. A nit-only or diagnostic-only follow-up
does not restart the CI review wait when this setting is `false`.

Use the trusted default-branch setting. A task may request `true`; it cannot
override a trusted `true` with `false`. Record a task override on the PR.

### `review.local_review_agents`

List available reviewer identities in preference order. Each entry has only
`provider` and `model_family`, both nonempty strings. Duplicate identities,
unknown fields, malformed entries, and an explicitly empty list are rejected.
Omitting the list is valid, including with `required: none`.

`shaka reviewer` chooses an identity, and `shaka review-prompt` produces its
instructions. The signed-in host runs the reviewer; the configuration does not
map identities to executable names. Prefer a second provider when available.
See [reviewer selection](../agents/review.md#choose-a-local-reviewer).

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

`plan` identifies the product requirements or implementation plan the agent should read during planning. For Shaka itself, it points to `docs/pilot-plan.md`, which defines pilot scope and acceptance. `AGENTS.md` supplies standing repository instructions; `plan` supplies the work's requirements. Omit it if the repository has no shared plan.

The path must name an existing file inside the repository. Absolute paths, escaping
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
it. See [recovery notes](../agents/delivery.md#recover-an-unfinished-pr).

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

The optional [local repository catalog](../agents/repository-catalog.md) caches
known repositories; it is separate from policy.

