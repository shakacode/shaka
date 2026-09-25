# Settings

Settings live in `.agents/agent-workflow.yml`. Ask your agent to
[configure the repository](configure-repository.md), or edit the file in a PR.
Policy comes from the default branch; settings changed in a PR do not govern
that PR.

## `merge.preference`

**Required.** Values: `ask` or `auto`. Setup defaults to `ask`.

```yaml
merge:
  preference: ask
```

With `ask`, merge the ready PR on GitHub or tell the agent to merge the reviewed
commit. With `auto`, the agent merges after required checks, reviews, and approvals,
subject to the repository's restrictions.

Set a task's preference with `Use merge policy auto`. This is a task instruction;
editing the PR's settings does not change its own merge authority. Required human
approvals still apply. See [merge policy](working-with-shaka.md#choose-a-merge-policy).

## `merge.limits`

**Optional.** Size limits for a merge the agent submits. A PR at a limit still
merges; one past it goes back to you.

```yaml
merge:
  preference: auto
  limits:
    max_changed_files: 29
    max_changed_lines: 999
    max_commits: 9
```

The values above are the defaults. Set any key to a positive integer to change
it; omitted keys keep their default. Changed lines are additions plus deletions.

When a PR is past a limit, or GitHub does not report its size, `merge` refuses
it. The agent then reports the counts and hands the PR back as Ask. To let the
agent merge it, confirm that commit in chat or
[approve it](working-with-shaka.md#find-prs-waiting-on-you). The confirmation
still counts after a clean rebase, or after conflict fixes that change no
behavior; any other new commit needs another confirmation. Required checks,
reviews, and approvals still apply.

`merge` checks the counts and that a confirmation names the commit being
merged. Whether you actually confirmed it is the agent's responsibility; the
[enforcement reference](workflow.md#what-is-enforced) explains the boundary.
Put other project restrictions in `AGENTS.md`.

## `review.required`

**Required.** Values: `meaningful_changes`, `always`, or `none`.

This controls when configured CI review reports are required. Options:

- `meaningful_changes`: implementation changes; trivial prose can skip with a reason.
- `always`: every PR, including trivial changes.
- `none`: no configured CI review backstop, and `shaka merge` does not check for a
  local review. Omit `ci_review_jobs` with this setting.

Meaningful implementation also gets a local adversarial review before push:

- Use a separate session without the implementation conversation.
- Prefer a different provider and model. If other reviewers are unavailable, the
  current workflow allows the implementation model in a fresh session.
- Address findings before pushing.

`shaka review run` verifies the reviewer process completed and returned a report
for the expected commit. `shaka review check` validates a supplied report but does
not prove a reviewer process ran.

Before it merges, `shaka merge` checks that the PR has a local review of the
commit being merged. The agent posts the review report as a PR comment, and the
report's last line names the commit and the reviewer:

```text
REVIEWED <commit> BY <provider>/<family> EFFORT <effort> FINDINGS <count>
```

`merge` counts only comments from the GitHub account running the merge, and only
when that line ends the comment. Any reviewer counts, including the
implementation model in a fresh session.

A review of an earlier commit still counts in two cases:

- **Updated from the base branch.** Bringing the branch up to date with the base,
  by merge or rebase, keeps the review when there were no conflicts and nothing
  else changed. `merge` checks this with Git in the local checkout: the head must
  match, file for file, what merging the reviewed commit with the new base
  produces. The check runs Git's built-in merge in a temporary repository, so no
  merge driver or script runs and nothing is written to your repository. If Git
  is older than 2.40 or those commits are not in the checkout, `merge` asks for a
  new review or a waiver instead.
- **Ordinary Markdown since.** Every later change is ordinary Markdown. Agent
  instructions are not ordinary Markdown: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
  `SKILL.md`, and files under `.agents/`, `.claude/`, `.cursor/`, `.github/`, or
  `skills/` need a new review.

When no review applies, `merge` stops before merging. Pass
`--review-waiver REASON` when review was skipped on purpose, a later commit only
fixed nits, or a CI review covered the commit. The waiver also covers a PR whose
comments GitHub cannot list. With `review.required: none`, `merge` skips this check.

The merge result shows the review it relied on, or the waiver reason, under
`review_evidence`. That records what the posted line says. It does not prove a
reviewer process ran or that its findings were fixed.

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

The agent reads reports according to `ci_review_wait`; a green job alone does not
prove review completed. GitHub's required merge checks are configured separately.

## `review.ci_review_wait`

**Optional. Default: `one`.** Values: `none`, `one`, or `all`.

| Value | Wait before merging |
| --- | --- |
| `none` | No CI review report; local review still applies |
| `one` | At least one configured reviewer reports on the current commit |
| `all` | Every configured reviewer reports on the current commit |

Local review does not waive `one` or `all`. With `review.required: none`, no
configured review jobs apply. GitHub's required checks and approvals apply in
every mode. A task can increase the wait, but cannot lower the repository minimum.

The agent counts verified reports. The merge helper permits optional pending
checks (`UNSTABLE`) for `none` and `one`; `all` requires `CLEAN`.

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

Use stable provider/family names; model releases do not require list updates.
The agent prefers a different provider and chooses the review model and effort
separately. Put custom review criteria in trusted `AGENTS.md`.
See [reviewer selection](../skills/shaka/references/review.md#choose-a-local-reviewer).

## Standard command scripts

Connect your existing tools at these fixed paths:

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

`exec` preserves the command's exit status and signals. A symlink to a tracked
executable also works if its directory, environment, and arguments already match.

Scripts must be executable and resolve within the repository. `.agents` and
`.agents/bin` must be real directories. Removing an optional check already on the
default branch requires an explicit, maintainer-approved policy change.

## `base_branch`

**Optional. Default: the repository's default branch.**

Use `base_branch: develop` to start from and target `develop`. An explicit task
choice or existing PR target takes precedence. A base outside the configured or
default branch needs confirmation and uses Ask. Policy always comes from the
default branch.

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

For example: `alex-codex/42-fix-search`.

## `wip.include_locations`

**Optional. Default: `true`.**

```yaml
wip:
  include_locations: false
```

Include the checkout path and session link in **WIP Details**. With `false`,
both appear as `UNKNOWN`; ownership, state, and next action remain visible.

Locations can reveal local names or identifiers. The agent must inspect them for
private information before publishing; Ruby does not check for it. Expandable
sections on public PRs are public too.

## `repo_prefix`

**Optional. Default: a label derived from the repository name.**

Use 1–6 uppercase ASCII letters or digits, such as `repo_prefix: SHOP`, to label
chat titles: `SHOP PR #42 · Fix checkout`. The
[repository catalog](repository-catalog.md) reports duplicate prefixes.

## `version`

**Required. Currently `1`.** This identifies the configuration format, not the
installed Shaka release.

Unknown keys and invalid values produce an error. Link requirements and design
plans from `AGENTS.md`.
