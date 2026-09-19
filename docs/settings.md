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
| `recovery` | no | mapping | [Recovery note and snapshot policy](#recovery). |

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

| Setting | Required | Allowed values |
| --- | --- | --- |
| `required` | yes | `always`, `meaningful_changes`, `none` |
| `check` | when `required` is not `none` | Non-empty string |
| `model_family` | all-or-nothing | Non-empty string |
| `provider` | all-or-nothing | Non-empty string |
| `draft` | all-or-nothing | `true` or `false` |

Two conditional rules matter:

- When `required` is `none`, then `check`, `model_family`, `provider`, and `draft` must
  all be **omitted**. Leaving one behind fails validation.
- `model_family`, `provider`, and `draft` are a single group. Supply all three or none;
  supplying one or two fails validation.

The metadata group exists so Shaka can tell reviewer identity from implementer identity.
A review from the implementer's own model family does not satisfy the gate, and a check
name alone is not evidence that a review happened. `draft` records whether that reviewer
runs on draft pull requests; when it is `false`, Shaka uses the review-ready path instead.

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

Optional mapping. Both keys are booleans and both default to `true` when the section or
the key is absent. They govern the
[recovery note](working-with-your-agent.md#recover-an-unfinished-pr) a pull request carries
while it is unfinished, and the unfinished work that note describes.

| Setting | Allowed values | Meaning |
| --- | --- | --- |
| `workspace_path` | `true` or `false` | `true` lets the note carry the checkout path. `false` tells the workflow to omit the `Workspace` field. The owner alias and the `Thread` locator follow their own rules either way. Read the note below on what enforces this. |
| `snapshot` | `true` or `false` | `true` lets `shaka snapshot` push the working tree's unfinished files to a `wip/` branch when a task stops, holding back credential-like paths first. The commit has no parent, so no history leaves with it. `false` makes the command itself refuse, so unfinished work stays on the machine that made it. |

Set `workspace_path: false` where contributor paths are sensitive. Set `snapshot: false`
where unfinished work must not reach the remote at all, or where CI runs on every pushed
branch. `seam init` writes neither key, so a repository that says nothing gets both
defaults.

The two keys are enforced in different places, and the difference matters. `snapshot` is
enforced by the command: it reads the key from the remote's own default branch before it
pushes anything, so editing or deleting the checkout's copy changes nothing, and a remote
it cannot read refuses. That remote contract is validated whole before the key is read,
because reading one section out of a document nothing has checked assumes the rest of it.
Only its command and `plan` paths go unchecked, since those name files in the repository
the seam came from rather than the checkout reading it. `workspace_path` still tells only the workflow what a note may
carry; the publisher does not refuse a note that ignores it. Enforcing it means teaching
the description publisher to read the same remote seam on every publication, which is a
change to the publication boundary and is not part of the snapshot command.

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

It omits the `model_family`, `provider`, and `draft` group, which is valid — the group is
optional as a whole. Add all three by hand when you want Shaka to compare reviewer
identity. The generated merge preference is `ask` unless you pass `--merge-preference auto`.

## Where each rule is enforced

| Area | Source |
| --- | --- |
| Whole-file and top-level rules | `skills/shaka/lib/shaka/repository_config/schema.rb` |
| Reviewer policy | `skills/shaka/lib/shaka/repository_config/review_schema.rb` |
| Feature-branch layout | `skills/shaka/lib/shaka/repository_config/branch_schema.rb` |
| Recovery note policy | `skills/shaka/lib/shaka/repository_config/recovery_schema.rb` |
| Snapshot refusal | `skills/shaka/lib/shaka/snapshot/policy.rb` |
| One document, no duplicate keys | `skills/shaka/lib/shaka/repository_config/duplicate_keys.rb` |
| Generated contract | `skills/shaka/lib/shaka/seam/initializer.rb` |
