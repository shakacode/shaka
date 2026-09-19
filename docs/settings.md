# Repository seam settings

`.agents/agent-workflow.yml` is the machine-readable contract between a repository and
the Shaka workflow. It names the executable commands Shaka runs and records review,
merge, and branch-protection policy. Shaka reads it from the trusted default branch, so
a candidate pull request cannot grant itself authority by editing its own copy.

Create it with [`shaka seam init`](getting-started.md#initialize-a-repository-seam) and
validate any change with `shaka seam check --root .`. Validation is strict and local:
unknown keys, duplicate keys, unsafe paths, missing or non-executable scripts, and
out-of-range values all fail rather than being ignored.

Keep human-only constraints in `AGENTS.md`. This file holds only typed policy.

## Every setting in one file

This is a complete seam using every setting, including the two optional ones. Each section is
explained below.

```yaml
---
version: 1
base_branch: main
plan: docs/pilot-plan.md
commands:
  setup: .agents/bin/setup
  validate: .agents/bin/validate
  test: .agents/bin/test
  validate_local: .agents/bin/validate_local
  trigger_hosted_ci: .agents/bin/trigger_hosted_ci
review:
  required: meaningful_changes
  check: claude-review
  reviewers:
    - provider: anthropic
      model_family: claude
    - provider: openai
      model_family: codex
    - provider: xai
      model_family: grok
merge:
  preference: ask
  method: squash
  release: explicit_approval
protection:
  required_checks:
    - validate
  direct_push: false
  force_push: false
  branch_deletion: false
trusted_actions:
  - actions/checkout
  - anthropics/claude-code-action
  - ruby/setup-ruby
```

The smallest valid seam drops every optional setting — `plan`, `trusted_actions`,
`reviewers`, and the two optional commands:

```yaml
---
version: 1
base_branch: main
commands:
  setup: .agents/bin/setup
  validate: .agents/bin/validate
  test: .agents/bin/test
review:
  required: none
merge:
  preference: ask
  method: squash
  release: explicit_approval
protection:
  required_checks:
    - validate
  direct_push: false
  force_push: false
  branch_deletion: false
```

## File rules

These apply to the whole document, whatever the settings are.

| Rule | Why it exists |
| --- | --- |
| Path is exactly `.agents/agent-workflow.yml` | Shaka looks nowhere else. |
| Exactly one YAML document | A second document could hide alternate policy. |
| No duplicate keys, at any depth | YAML would silently keep the last value. |
| All mapping keys must be strings | Keeps the contract typed and comparable. |
| No aliases, no custom classes or symbols | Loaded with `safe_load`. An anchor is accepted while nothing references it; an alias is rejected. |
| Unknown keys are rejected at every level | A typo fails loudly instead of disabling a gate. |
| Comments are ignored | Safe to document the file inline; they never reach the parsed contract. |

## Top-level settings

| Setting | Required | Type | Value |
| --- | --- | --- | --- |
| `version` | yes | integer | Exactly `1`. |
| `base_branch` | yes | string | Non-empty string naming the branch work starts from. See the note below. |
| `commands` | yes | mapping | [Executable paths](#commands). |
| `review` | yes | mapping | [Reviewer policy](#review). |
| `merge` | yes | mapping | [Merge authority](#merge). |
| `protection` | yes | mapping | [Expected branch protection](#protection). |
| `plan` | no | string | Repository-relative path to an existing file. |
| `trusted_actions` | no | list of strings | Non-empty when present. |
| `branches` | no | mapping | [Feature-branch layout](#branches). |
| `recovery` | no | mapping | [Recovery note policy](#recovery). |

### When `version` changes

`version` stays `1` while the pilot revises this contract. A revision that removes or renames
a key makes an older seam fail `seam check` loudly, with a non-zero exit and the offending key
named, so nothing is silently misread and no version bump is needed to stay safe. The
`review.reviewers` list replacing the earlier flat `model_family`, `provider`, and `draft`
fields is such a revision.

`version` becomes `2` on the first change that could let an existing seam be read as something
it does not mean — a key whose meaning or default changes while its name and shape stay valid —
or once repositories outside this pilot depend on the contract, whichever comes first. Until
then a bump would force every consumer to edit a file for no behavioral difference.

Repository-relative means exactly that: an absolute path, a path that escapes the
repository, or a symlink resolving outside it is rejected.

`base_branch` is checked only as a non-empty string. `shaka seam check` does not test it
against Git's branch-name rules, so a hand-edited value such as `-not-a-branch`,
`has space`, or `a..b` passes validation and fails later, when the workflow tries to use
the branch. `shaka seam init` is stricter: it rejects any value that
`git check-ref-format --branch` does not accept. Prefer initializing the seam, and check
a hand-edited `base_branch` yourself.

## `commands`

Shaka executes these paths. It does not reconstruct their behavior from prose, so put
pipelines, environment setup, and other compound logic inside the scripts themselves.

| Command | Required | Purpose |
| --- | --- | --- |
| `setup` | yes | Install dependencies for a fresh checkout. |
| `validate` | yes | Full validation, as CI would run it. |
| `test` | yes | Focused tests for the files being changed. |
| `validate_local` | no | Faster pre-review subset. When present, the full `validate` is deferred until the repair batch is complete. |
| `trigger_hosted_ci` | no | Starts hosted CI after repairs. Requires `validate_local`. |

Every value must be a repository-relative path to a file that exists and is
**executable**. A readable-but-not-executable script fails validation.

## `review`

`required` is the only mandatory key. `check` names the reviewer's status check.

The three `required` values record when the gate named by `check` should apply, and `check` is
bound to them: validation requires it for `always` and `meaningful_changes`, and rejects it for
`none`. Choosing `none` therefore leaves no named gate to satisfy.

`always` is the exception. The workflow's review phase lets trivial prose or no-op work omit
review with a recorded reason whatever is set here, and nothing consumes this value to withdraw
that exemption, so `always` currently behaves exactly like `meaningful_changes`.

| Value | Trigger for the named gate |
| --- | --- |
| `always` | Every pull request, with no exemption for trivial work. Not yet distinguished from `meaningful_changes`. |
| `meaningful_changes` | Meaningful implementation only. Trivial prose or no-op work may omit the named gate when the reason is recorded on the pull request. |
| `none` | Never. Validation rejects `check`, so the repository declares no named gate. |

One rule holds whatever this value says: meaningful implementation gets an adversarial review
before the branch is pushed, and `none` does not switch that off. What makes the review
adversarial is the context rather than the model, so a fresh session of the implementation model
qualifies; a different provider is preferred, not required.
[Review](review.md) defines the baseline and the rest of the review procedure.

| Setting | Required | Allowed values |
| --- | --- | --- |
| `required` | yes | `always`, `meaningful_changes`, `none` |
| `check` | when `required` is not `none` | Non-empty string |
| `reviewers` | no | Ordered non-empty list of reviewer entries |

When `required` is `none`, `check` must be **omitted**; leaving it behind fails validation.
`reviewers` stays valid there, because `none` drops the repository's named check and not the
alternate-review baseline. Declaring it is not enforced — a seam with `required: none` and no
`reviewers` loads — but it is the only way that seam expresses reviewer order, and the baseline
applies either way.

### `review.reviewers`

`reviewers` is an ordered preference list. Each entry is one reviewer identity and nothing else:

| Setting | Required | Allowed values |
| --- | --- | --- |
| `provider` | yes | Non-empty string, such as `anthropic`, `openai`, `xai` |
| `model_family` | yes | Non-empty string, such as `claude`, `codex`, `grok` |

```yaml
review:
  required: meaningful_changes
  check: claude-review
  reviewers:
    - provider: anthropic
      model_family: claude
    - provider: openai
      model_family: codex
    - provider: xai
      model_family: grok
```

Validation rejects an empty list, a malformed entry, an unknown key, and a repeated identity. It
does **not** check that the list can survive exhaustion, because that depends on who implements a
change and the schema cannot know.

An entry carries no `draft` flag and no per-entry `check`. Whether a reviewer runs on draft pull
requests is decided by its own trigger — the standard reviewer workflow guards on
`draft == false` — so read the trusted workflow rather than a copy in the seam that can drift
from it. Identity is compared through review metadata or a trusted workflow, never a check name,
so a per-entry check name would have no job to do. The top-level `review.check` still names the
required native gate, and that gate need not belong to any listed reviewer.

#### Sizing the list

The list names the local reviewers to try, in preference order. One entry is enough; none is also
valid, since the implementation model in a fresh context still reviews and the GitHub reviews still
run on the pushed branch.

A second provider is worth listing because different providers notice different things. Count
providers rather than families for that: `anthropic/claude` plus `openai/codex` gives a Claude
implementation a different provider to try, and a Codex implementation one too. List a reviewer you
cannot run locally as well — one that runs on GitHub needs no local credentials.

#### Choosing from the list

`shaka reviewer` applies the preference, so neither this document nor the workflow restates it:

```text
shaka reviewer --root . --ref origin/main --implementer anthropic/claude
shaka reviewer --root . --ref origin/main --implementer openai/codex --unavailable anthropic/claude
```

It returns `different_provider`, `same_provider`, or `same_model`, with the reason it assigned every
entry. None is an error.
[Choose a local reviewer](review.md#choose-a-local-reviewer) explains the outcomes and what counts
as unavailable, and [invoke a reviewer locally](review.md#invoke-a-reviewer-locally) renders the
reviewer's instructions.

## `merge`

All three keys are required and no others are accepted.

| Setting | Allowed values | Meaning |
| --- | --- | --- |
| `preference` | `ask`, `auto` | `ask` brings the ready PR back for a human merge decision. `auto` merges an eligible change once the same gates pass. |
| `method` | `squash` | The only supported method. |
| `release` | `explicit_approval` | Release changes always need a human decision. |

`auto` is not a bypass. Required checks, required approvals, and branch protection still
apply, and uncertain authority or consequential risk falls back to `ask`.

## `protection`

All four keys are required and no others are accepted. This section records what Shaka
expects GitHub to enforce; Shaka never edits protection and never bypasses it.

| Setting | Allowed values | Meaning |
| --- | --- | --- |
| `required_checks` | non-empty list of non-empty strings | Checks that must pass before merge. |
| `direct_push` | `false` | Direct pushes to the base branch are not permitted. |
| `force_push` | `false` | Force pushes are not permitted. |
| `branch_deletion` | `false` | Branch deletion is not permitted. |

The three booleans must each be `false`. They are present so the contract states the
expectation explicitly rather than leaving it implied.

## `trusted_actions`

Optional allowlist of GitHub Actions used by the repository's trusted workflows, such as
`actions/checkout`. When the key is present it must hold at least one non-empty string.

## `branches`

Optional feature-branch layout for this repository. When present it is a mapping whose
only key is `name`, a non-empty template that **must** include `{issue}`.

Allowed placeholders:

| Placeholder | Meaning |
| --- | --- |
| `{login}` | GitHub account running the task (`gh api user --jq .login`) |
| `{host}` | Host slug such as `cursor`, `claude`, `codex`, or `opencode` |
| `{issue}` | Issue, PR, or related work-item number |
| `{description}` | Short slug |

The template is repository policy, not a per-machine guess. Do not put a person's
initials or a host-local naming convention in Shaka's code. A consumer that already
uses another layout, such as `feature/{issue}/{description}`, sets that string here.
`shaka claim` reports `branch_name` from this setting, or
`{login}-{host}/{issue}-{description}` when the key is omitted, and still treats a
`/{issue}-` path segment as a collision so older branches remain visible.

This repository sets `branches.name` to that default, so a GitHub login is the
person token rather than a hardcoded maintainer prefix. Change the mapping when a
consumer's layout differs.

`seam init` writes `branches.name` as `{login}-{host}/{issue}-{description}` so a new
repository has an explicit layout. Change that string when the repo already names
branches differently.

## `recovery`

Optional mapping. Its one key, `workspace_path`, is a boolean and defaults to `true` when
the section or the key is absent. It governs the
[recovery note](working-with-your-agent.md#recover-an-unfinished-pr) a pull request carries
while it is unfinished.

| Setting | Allowed values | Meaning |
| --- | --- | --- |
| `workspace_path` | `true` or `false` | `true` lets the note carry the checkout path and the host's link back to the session. `false` tells the workflow to publish `UNKNOWN` for both the `Workspace` and `Thread` fields, which are the two that name the owner's machine; the fields stay, so a withheld value reads differently from a missing one. The owner alias stays either way. Read the note below on what enforces this. |

Set `workspace_path: false` where contributor paths or session links are sensitive.
`seam init` does not write the key, so a repository that says nothing gets the default.

The key governs both fields rather than one each, because they answer the same question
and a repository that hides one has little reason to publish the other. Split it if a
repository ever needs them apart.

The setting tells the workflow what a recovery note may carry. The publisher does not yet
refuse a note that ignores it, so today it binds the agent rather than the publication
boundary. Enforcement belongs with the same trusted-seam reading the snapshot command
introduces, and lands with it.

## What `seam init` writes

The initializer produces the smallest complete contract: `version`, `base_branch`, the
three required commands as `.agents/bin/` wrappers, `review`, `merge`, `protection`, and
`branches.name` set to `{login}-{host}/{issue}-{description}` so the layout is visible in
the seam instead of only in Ruby. It adds `plan` and `trusted_actions` only when you pass
them. Edit `branches.name` afterward when the repository already uses a different layout.

The generated `review` section depends on the policy. With `always` or
`meaningful_changes` it holds `required` and `check`, and `--review-check` is mandatory.
With `--review-policy none` it holds `required` alone, and passing `--review-check` is
rejected — matching the rule above that the other review keys must be absent.

It omits `reviewers`, which is valid — the list is optional. Add it by hand when you want
Shaka to choose a reviewer and substitute an exhausted provider; the initializer has no flags
for reviewer entries yet. The generated merge preference is `ask` unless you pass
`--merge-preference auto`.

## Where each rule is enforced

| Area | Source |
| --- | --- |
| Contract path, and the `safe_load` limits on aliases, classes, and symbols | `skills/shaka/lib/shaka/repository_config.rb` |
| Top-level keys and section values | `skills/shaka/lib/shaka/repository_config/schema.rb` |
| Reviewer list shape | `skills/shaka/lib/shaka/repository_config/review_schema.rb` |
| Reviewer choice | `skills/shaka/lib/shaka/reviewer_selection.rb` |
| Feature-branch layout | `skills/shaka/lib/shaka/repository_config/branch_schema.rb` |
| Recovery note policy | `skills/shaka/lib/shaka/repository_config/recovery_schema.rb` |
| One document, no duplicate keys | `skills/shaka/lib/shaka/repository_config/duplicate_keys.rb` |
| Generated contract | `skills/shaka/lib/shaka/seam/initializer.rb` |
