# Settings

Repository settings live in `.agents/agent-workflow.yml`. Ask your agent to
[configure the repository](configure-repository.md) or edit the file in a PR.
Settings take authority from the default branch; a PR cannot weaken the rules
used to review itself.

## `merge.preference`

**Required.** Values: `ask` or `auto`. Setup defaults to `ask`.

```yaml
merge:
  preference: ask
```

With `ask`, the agent brings back a ready PR for you to merge on GitHub. With
`auto`, it merges after required checks, reviews, and approvals. Set a task's
preference in the prompt: `Use merge policy auto`. Repository restrictions and
required human approvals still apply. See [merge policy](working-with-shaka.md#choose-a-merge-policy).

## `review.required`

**Required.** Values: `meaningful_changes`, `always`, or `none`.

This controls when configured CI review reports are required:

- `meaningful_changes`: implementation changes; trivial prose can skip with a reason.
- `always`: every PR, including trivial changes.
- `none`: no configured CI review backstop. Omit `ci_review_jobs` with this setting.

Meaningful implementation still receives a local adversarial review before push.
That step is an agent instruction; Ruby does not prove it happened. A review
needs fresh context, and can use the implementation model if another reviewer
is unavailable.

## `review.ci_review_jobs`

**Required unless `review.required` is `none`.** List the GitHub job names that
produce review reports, such as:

```yaml
review:
  required: meaningful_changes
  ci_review_jobs:
    - claude-review
  ci_review_wait: one
```

The agent reads their reports and waits according to `ci_review_wait`. A green
job alone does not prove a review completed. These names are separate from
GitHub's required merge checks.

## `review.ci_review_wait`

**Optional. Default: `one`.** Values: `none`, `one`, or `all`.

| Value | Wait before merging |
| --- | --- |
| `none` | No CI review report; local review still applies |
| `one` | At least one configured reviewer reports on the current commit |
| `all` | Every configured reviewer reports on the current commit |

Local review does not waive `one` or `all`. With `review.required: none`, there
are no configured review jobs to wait for. GitHub's required checks and approvals
apply in every mode. A task can request more waiting, but cannot weaken the trusted
repository setting.

The agent verifies and counts reports. The merge helper checks GitHub conditions;
it permits an optional pending check (`UNSTABLE`) for `none` and `one`, but requires
`CLEAN` for `all`.

## `review.local_review_agents`

**Optional.** Ordered reviewer preferences. Without a list, selection falls back
to a fresh review context using the implementation identity.

```yaml
review:
  required: meaningful_changes
  ci_review_jobs: [claude-review]
  local_review_agents:
    - provider: anthropic
      model_family: claude
    - provider: openai
      model_family: codex
```

These are stable provider/family names, not model releases. An Opus or GPT update
does not require changing this list. The agent prefers a different provider when
available and chooses the concrete model and effort for the review. These entries
do not set either one.

Put custom review criteria in trusted `AGENTS.md`. The agent can include them in
the reviewer prompt. For invocation and supported CLIs, see the
[skill procedure](../skills/shaka/references/review.md#choose-a-local-reviewer).

## Standard command scripts

These fixed paths connect Shaka to your project's existing tools:

| Script | Required? | Purpose |
| --- | --- | --- |
| `.agents/bin/setup` | Yes | Install dependencies |
| `.agents/bin/test` | Yes | Run tests; accept focused arguments |
| `.agents/bin/validate` | Yes | Complete checks before publishing |
| `.agents/bin/validate-local` | No | Faster checks before local review |
| `.agents/bin/trigger-hosted-ci` | No | Start deferred CI after local fixes; requires `validate-local` |

A wrapper can call an existing command. For example:

```sh
#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
exec bundle exec rake test "$@"
```

`exec` replaces the wrapper process, preserving the command's exit status and
signals. A symlink to a tracked executable inside the repository also works if
the working directory, environment, and arguments already match.

Scripts must exist, be executable, and stay within the repository so the reviewed
commit determines what runs. `.agents` and `.agents/bin` must be real directories.
An optional check already present on the default branch cannot disappear just
because a PR deletes it. Removing one requires an explicit policy change approved
by the maintainer.

## `base_branch`

**Optional. Default: the repository's default branch.**

Use `base_branch: develop` when tasks normally start from and target `develop`.
An explicit task choice or an existing PR's target takes precedence. A different
base needs confirmation and uses Ask for that task. Policy still comes from the
default branch, regardless of where the PR targets.

## `branches.name`

**Optional. Default: `'{login}-{host}/{issue}-{description}'`.**

```yaml
branches:
  name: '{login}-{host}/{issue}-{description}'
```

| Placeholder | Meaning |
| --- | --- |
| `{login}` | Authenticated GitHub login |
| `{host}` | Coding-agent slug, such as `codex` or `claude` |
| `{issue}` | Issue, PR, or work-item number; required in the template |
| `{description}` | Short task description |

For example: `alex-codex/42-fix-search`. Shaka currently supports GitHub PR
delivery; this setting does not add GitLab support.

## `wip.include_locations`

**Optional. Default: `true`.**

```yaml
wip:
  include_locations: false
```

Controls whether **WIP Details** in an unfinished PR include the checkout path
and agent-session link. With `false`, both are shown as `UNKNOWN`; ownership,
state, and next action remain available.

These locations can reveal local names or identifiers. The agent must inspect
what it publishes; Ruby does not guarantee that the information is nonconfidential.
Expandable PR sections are public whenever the PR is public.

## `repo_prefix`

**Optional. Default: a label derived from the repository name.**

Use a short uppercase label, such as `repo_prefix: SHOP`. It helps distinguish
chat titles such as `SHOP PR #42 · Fix checkout`. Configured prefixes are 1–6
uppercase ASCII letters or digits.

The [repository catalog](repository-catalog.md) helps find duplicate prefixes
across your projects.

## `version`

**Required. Currently `1`.** This identifies the configuration format, not the
installed Shaka release.

The file is validated YAML: unknown keys and invalid values produce an error.
For requirements or a design plan, point to the document from `AGENTS.md`; no
separate `plan` setting is needed.
