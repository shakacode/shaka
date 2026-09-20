# Repository seam settings

`.agents/agent-workflow.yml` is the machine-readable contract between a repository and
the Shaka workflow. It records review, merge-authority, branch-naming, and recovery policy.
Executable commands use the fixed `.agents/bin/` interface described below. Shaka reads
policy and optional-command availability from the trusted default branch, so a candidate
pull request cannot grant itself authority by editing its own copy. GitHub remains
authoritative for live protection, required checks, allowed merge methods, and workflow
action references.

Create it with [`shaka seam init`](getting-started.md#initialize-a-repository-seam) and
validate any change with `shaka seam check --root .`. Validation is strict and local:
unknown keys, duplicate keys, unsafe paths, missing or non-executable scripts, and
out-of-range values all fail rather than being ignored.

Keep human-only constraints in `AGENTS.md`. This file holds only typed policy.

## Every setting in one file

This is a complete seam using every YAML setting. Each section is explained below.

```yaml
---
version: 1
base_branch: main
plan: docs/pilot-plan.md
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
branches:
  name: '{login}-{host}/{issue}-{description}'
recovery:
  workspace_path: false
```

The smallest valid YAML seam drops every optional setting — `plan`, `reviewers`,
`branches`, and `recovery` — and does not provide either optional command entry point:

```yaml
---
version: 1
base_branch: main
review:
  required: none
merge:
  preference: ask
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
| `review` | yes | mapping | [Reviewer policy](#review). |
| `merge` | yes | mapping | [Merge authority](#merge). |
| `plan` | no | string | Repository-relative path to an existing file. |
| `branches` | no | mapping | [Feature-branch layout](#branches). |
| `recovery` | no | mapping | [Recovery note policy](#recovery). |

### What is intentionally absent

Older seams must remove `protection` and `trusted_actions`; `merge.method` and
`merge.release` are retired too.

The seam does not copy GitHub's complete required-check list, direct-push, force-push,
branch-deletion, allowed-merge-method, or workflow-action state. Shaka reads current
mergeability, whether native protection binds the acting account, approvals, and required
checks from GitHub before merging. Trusted workflow files carry their own pinned action
references. A second unchecked copy in YAML would not enforce any boundary and could disagree
with the service that does.

`review.check` serves a different purpose: it selects the reviewer result that the Shaka
workflow must wait for whenever repository policy requires review, even if GitHub branch
protection does not require that check. GitHub remains authoritative for the native check list;
the seam remains authoritative for Shaka's review choice.

Repositories that use an action allowlist as input to a real security scanner should keep it
in that scanner's supported policy file. Shaka V2 has no such consumer, so it does not accept
an inert `trusted_actions` field.

### When `version` changes

`version` stays `1` while the pilot revises this contract. A revision that removes or renames
a key makes an older seam fail `seam check` loudly, with a non-zero exit and the offending key
named and a migration pointer where one exists, so nothing is silently misread and no version
bump is needed to stay safe. The `review.reviewers` list replacing the earlier flat
`model_family`, `provider`, and `draft` fields and the retired GitHub-fact fields described
above are such revisions.

`version` becomes `2` on the first change that could let an existing seam be read as something
it does not mean — a key whose meaning or default changes while its name and shape stay valid —
or once repositories outside this pilot depend on the contract, whichever comes first. Until
then a bump would force every consumer to edit a file for no behavioral difference.

### Path and branch validation

Repository-relative means exactly that: an absolute path, a path that escapes the
repository, or a symlink resolving outside it is rejected.

`base_branch` is checked only as a non-empty string. `shaka seam check` does not test it
against Git's branch-name rules, so a hand-edited value such as `-not-a-branch`,
`has space`, or `a..b` passes validation and fails later, when the workflow tries to use
the branch. `shaka seam init` is stricter: it rejects any value that
`git check-ref-format --branch` does not accept. Prefer initializing the seam, and check
a hand-edited `base_branch` yourself.

## Standard command scripts

Shaka follows GitHub's [Scripts to Rule Them All](https://github.blog/engineering/engineering-principles/scripts-to-rule-them-all/)
philosophy: every repository exposes common engineering operations through predictable,
language-independent names. A new contributor or portable tool should not have to parse a
second routing table before it can set up, test, or validate a project.

| Path | Required | Purpose |
| --- | --- | --- |
| `.agents/bin/setup` | yes | Install dependencies and prepare a fresh checkout. |
| `.agents/bin/validate` | yes | Run full validation, as CI would. |
| `.agents/bin/test` | yes | Run focused tests and forward selection arguments. |
| `.agents/bin/validate-local` | no | Run a faster pre-review subset. Its presence defers full validation until the repair batch is complete. |
| `.agents/bin/trigger-hosted-ci` | no | Start staged hosted CI after repairs. It requires `validate-local`. |

These names are the interface; repository-specific commands stay behind them. Prefer a small
wrapper script that changes to the repository root, establishes any required environment,
forwards arguments, and uses `exec` for a single underlying command. Wrappers remain clear when
the operation later needs composition or setup. A symlink is acceptable when the target is a
stable tracked executable inside the same repository and needs exactly the same working
directory, environment, and arguments. Shaka rejects links that resolve outside the repository.
The `.agents` and `.agents/bin` interface directories themselves must be real tracked
directories; only individual command entries may be symlinks. The initializer always creates
wrappers because that is the portable default.

Required scripts must exist and be executable. When the workflow supplies `--ref`, as it must
for trusted decisions, optional capability comes from the script's presence on that resolved
default-branch commit, never merely from a candidate pull request. Shaka then validates and runs
the candidate checkout's version at the same fixed path. A no-`--ref` check intentionally
inspects the current checkout for local editing or initialization; it supplies no trusted policy
authority. A readable but non-executable script fails validation.

`shaka seam check` prints an effective JSON view that includes the derived `commands` map for
workflow consumers. That output is diagnostic, not a YAML seam template; do not copy its
`commands` key back into `.agents/agent-workflow.yml`.

An optional command that exists on the trusted ref is intentionally sticky for the candidate:
deleting it fails validation instead of silently removing the capability. This presence check
does not attest to a candidate script's behavior; review and validation must still catch a
wrapper that weakens or skips its work. Retiring an optional command is therefore a
repository-policy migration, not an ordinary code change. Keep its executable wrapper until the
repository has an explicitly authorized migration that changes the trusted default-branch
capability; do not bypass protection or treat candidate absence as retirement authority. The
pilot does not yet provide a self-service retirement marker.

An older pilot seam with a YAML `commands` mapping now fails with `unknown key: commands`.
This is an intentionally loud pilot-contract revision rather than a silent reinterpretation of
existing policy. Migrate across that trust boundary in this order:

1. While the previous Shaka version is still installed, prepare a seam PR that removes the
   mapping and adds the fixed scripts. Keep temporary adapters at every old mapped path that
   differs, including underscore-named optional scripts. If an old path collides with a new
   standard role, temporarily make both entry points run the stricter superset; never preserve a
   fast path by weakening full validation. The target Shaka fails when it finds an underscore-
   named optional script without its hyphenated standard entry point, preventing silent loss of
   staged validation or hosted CI.
2. Validate that candidate checkout with the previous trusted Shaka and `--ref` set to the
   pre-migration default-branch commit. It reads the old trusted mapping and proves those
   temporary paths still work. Separately run the target Shaka version without `--ref` on the
   candidate checkout; this parses the mapping-free YAML and fixed scripts but grants no policy
   authority. Both checks must pass before the seam PR merges through the repository's normal
   gates.
3. Upgrade the installed Shaka only after the default branch contains the mapping-free seam.
   Pin that new default-branch commit with `shaka seam check --ref`, then remove obsolete
   compatibility adapters in a follow-up PR. The fixed hyphenated optional paths are now the
   only ones Shaka recognizes.

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
shaka reviewer --root . --ref 889e4f1 --implementer anthropic/claude
shaka reviewer --root . --ref 889e4f1 --implementer openai/codex --unavailable anthropic/claude
```

Pass the commit intake resolved, not a branch name: a remote-tracking ref moves, and the policy
should be the snapshot the task started from.

It returns `different_provider`, `same_provider`, `same_model`, or `hosted_only` when nothing can
review locally, with the reason it assigned every entry. None is an error.
[Choose a local reviewer](review.md#choose-a-local-reviewer) explains the outcomes and what counts
as unavailable, and [invoke a reviewer locally](review.md#invoke-a-reviewer-locally) renders the
reviewer's instructions.

## `merge`

`preference` is the only accepted key. Merge Queue is live repository state rather than a
second seam setting: enabling it on the protected base opts the repository into queued
submission, while a queue-disabled base keeps direct submission.

| Setting | Allowed values | Meaning |
| --- | --- | --- |
| `preference` | `ask`, `auto` | `ask` brings the ready PR back for a human merge decision. `auto` submits an eligible change through the current native merge path once the same gates pass; queued submission still waits for terminal completion. |

`auto` is not a bypass. Required checks, required approvals, and branch protection still
apply, and uncertain authority or consequential risk falls back to `ask`.

On a queue-disabled base, the merge helper submits a squash merge. On a queue-enabled base,
it enqueues the exact reviewed head and GitHub uses the repository-configured merge method.
The helper does not enable the queue or arm auto-merge. Release changes always need explicit
human approval. Those are workflow invariants rather than configurable choices, so repeating
them in every repository seam would create data that can only drift from the implementation.
GitHub decides whether direct squash merge and queued submission are currently allowed.

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

The initializer produces the smallest complete contract: the three required `.agents/bin/`
wrappers plus YAML containing `version`, `base_branch`, `review`, `merge`, and
`branches.name` set to `{login}-{host}/{issue}-{description}` so the layout is visible in
the seam instead of only in Ruby. It adds `plan` only when you pass it. Edit
`branches.name` afterward when the repository already uses a different layout.

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
| Fixed command names and optional-command dependencies | `skills/shaka/lib/shaka/repository_config/command_paths.rb` and `command_schema.rb` |
| Trusted-ref optional-command and symlink-target authorization | `skills/shaka/lib/shaka/trusted_config_source.rb` |
| Reviewer list shape | `skills/shaka/lib/shaka/repository_config/review_schema.rb` |
| Reviewer choice | `skills/shaka/lib/shaka/reviewer_selection.rb` |
| Feature-branch layout | `skills/shaka/lib/shaka/repository_config/branch_schema.rb` |
| Recovery note policy | `skills/shaka/lib/shaka/repository_config/recovery_schema.rb` |
| One document, no duplicate keys | `skills/shaka/lib/shaka/repository_config/duplicate_keys.rb` |
| Generated contract | `skills/shaka/lib/shaka/seam/initializer.rb` |
