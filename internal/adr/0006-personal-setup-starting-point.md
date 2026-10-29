# 0006: Start new individual setups from personal preferences

Status: proposed.
Date: 2026-10-28. Tracks [issue #936](https://github.com/shakacode/shaka/issues/936).

## Context

Individual setup writes a clone's settings to its `.agents/shaka/`, kept out of Git.
A developer who tries Shaka on several repositories answers the same questions each time
and copies the same choices from one clone to the next. Nothing records them once.

`shaka seam private setup` (`Seam::PrivateSetup`, a subclass of `Seam::Initializer`)
writes only part of a configuration: the command wrappers, `review.required`,
`review.ci_review_jobs`, `review.local_review_agents`, `merge.preference: ask`, the default
`branches.name`, and `wip.include_checkout_path: true`. Everything else a developer wants,
such as `prose_limits`, `pr_description.opening_check`, `checkpoint`, or
`review.provider_coverage`, is a manual edit to `.agents/shaka/config.yml` after setup.
`--from ID` copies another worktree of the same clone, not another repository.

Two facts bound the design:

- **One settings source per task.** `Configuration.resolve_source` picks a selected settings
  PR, otherwise team settings on the default branch, otherwise complete individual settings.
  Sources never fill each other's gaps ([which settings apply](../../docs/settings.md#which-settings-apply),
  #715).
- **Machine files already exist.** `~/.agents/trusted-github-actors.yml` and, since
  [ADR 0005](0005-per-machine-reviewers.md), `~/.agents/shaka/local-reviewers.yml` are read
  with every settings source because they describe the machine. ADR 0005 rejected folding
  reviewer choices into individual settings, because those cannot describe a machine
  working across repositories that have team settings.

[ADR 0002](0002-install-locations-and-no-compatibility.md) refuses install directories
under `~/.agents/`, so `~/.agents/shaka/config.yml` is free and mirrors the repository's
`.agents/shaka/config.yml`.

`internal/requirements.md` covers private setup but not a personal starting point, so this
is a small scope extension the maintainer accepts by approving this record.

### Predecessor check

Checked at `shakacode/agent-workflows` `d85eceae` (2026-09-28). It has one user-global
file, `~/.agents/agent-workflow.yml`, used for one key: `writing_style`
(`docs/adoption.md`). It resolves at run time, repository then user-global then the packaged
default, and an invalid user-global value warns and falls back. That is the "fourth
source" alternative below, applied per key, and the one-source rule here rules it out.
Nothing is reused; the shared idea is only the `~/.agents/` home for personal files.

## Decisions

1. **The personal file is setup input, not a settings source.** `seam private setup` reads
   `~/.agents/shaka/config.yml` through `Dir.home` when it generates a clone's settings, and
   writes the merged result to the clone's `.agents/shaka/config.yml` as today. No other
   command reads it. Task-time resolution, `seam check`, `seam private check`, status, and
   the PR settings block keep reporting the clone's file only. Editing the personal file
   later changes no existing clone. The one-source rule and the #715 precedence docs stay
   true.

2. **The file may set only preference keys.** It uses the repository schema: `version: 1`
   and the same key paths, validated by the existing `RepositoryConfig` sub-schemas
   (`ReviewSchema`, `PrDescriptionSchema`, `OpeningSchema`, `WipSchema`, `BranchSchema`, and
   `PostImplementationSchema` for `checkpoint`) and by `ProseLimits` for `prose_limits`.
   Allowed keys:

   | Key | Why it is a preference |
   | --- | --- |
   | `review.local_review_agents`, `review.provider_coverage`, `review.local_review_count`, `review.local_max_rounds`, `review.startup_check` | Which local reviewers the developer runs and how often |
   | `checkpoint` (without `custom_instructions_file`) | The developer's checkpoint reviewer, model, and effort |
   | `pr_description.opening_check` (without prompt files), `pr_description.show_shaka_credit`, `pr_description.show_human_comments`, `pr_description.max_human_comments` | How the developer's PR descriptions read |
   | `prose_limits` | Writing limits |
   | `branches.name` | Branch naming |
   | `wip.include_checkout_path` | What WIP Details publish |

   Any other key stops setup, naming the file and the key, before anything is written.
   That covers repository facts setup infers from the repository (commands, `base_branch`,
   `review.ci_review_jobs`, `merge.*`, `project_guidance`,
   `pr_description.human_review_floors`, `repo_prefix`) and every prompt-file path, because
   a path in the personal file would name a file in a repository the file was not written
   for. An invalid value stops setup the same way, with the schema's own message.

   `review.required` is excluded too, although the developer chooses it with
   `--review-policy`: it is coupled to the repository's CI review jobs.
   `Initializer#ci_review_jobs` requires `--ci-review-job` for `always` and
   `meaningful_changes` and refuses it for `none`, so a personal value would make setup fail
   in a repository whose CI review jobs do not match it.

3. **Explicit choices win, then the personal file, then setup's defaults.** A command-line
   flag for the same value, such as `--local-review-agent`, replaces the personal value.
   Keys the personal file omits keep what setup writes today. Lists replace, not append:
   personal `local_review_agents` is the whole list unless a flag supplies one. `--from`
   ignores the personal file, because it copies this clone's own earlier settings.

4. **Setup reports what it used.** The setup result gains `prefilled_from` (the file path)
   and `prefilled_keys` (the dotted keys it took), or omits both when the file is absent.
   The private-setup procedure in `skills/shaka/references/repository-setup.md` tells the
   agent to show those values with the inferred commands before running setup, so the
   developer reviews one proposal. Without the file, setup's output and files are unchanged.

5. **No new repository setting and no configuration migration.** The personal file, like
   `local-reviewers.yml`, is not a key in `defaults.yml` and does not appear in
   `.agents/shaka/config.yml`. This repository's team settings do not change, so the
   implementation PR is a feature PR and the feature guard applies unchanged. A
   per-machine environment override of the path is not added; tests set `HOME`.

6. **Team setup is unchanged.** `seam init` ignores the personal file, so one developer's
   preferences never reach committed team settings through setup.

### How it fits with the machine reviewer list

`local-reviewers.yml` and the personal file both mention reviewers but answer different
questions. The personal file's `review.local_review_agents` becomes the clone's
reviewer list, used only when that clone has no team settings. `local-reviewers.yml`
fills model and effort for matching entries at review time, in every repository, under the
precedence ADR 0005 set. A developer who wants the same reviewers everywhere puts the list
in the personal file and the model and effort in `local-reviewers.yml`; `docs/settings.md`
says so beside both.

## Alternatives considered

- **No personal file (today).** Simplest; setup and the post-setup edits repeat per clone.
- **A fourth settings source when a repository has no settings.** Applies preferences
  without setup, but adds a source every report has to name, and a clone's behavior would
  change when the home file changes.
- **Personal values fill team gaps.** Rejected in the issue: it breaks the one-source rule
  and hides which settings governed a task.
- **A denylist of repository facts instead of an allowlist.** Shorter today, but every new
  setting would become personal-file input by default, including ones that describe the
  repository. The allowlist makes each new preference an explicit choice.
- **Copy prompt files from `~/.agents/shaka/`.** It would carry custom review and checkpoint
  instructions too, but adds file copying, size and symlink checks, and a second place a
  prompt can come from. Deferred until someone asks; the developer can still copy a
  prompt into the clone's `.agents/shaka/` after setup.
- **Read the file in the agent and pass flags.** No Ruby change, but setup has no flags for
  most allowed keys, and validation would move into prose.
- **Pre-fill team setup too.** Saves the same questions for a team's first PR, but puts one
  person's preferences into committed settings without anyone asking for them.

## Consequences

- `PrivateSetup#config_hash` merges allowed personal values under explicit options; a small
  loader validates the file against the allowlist and the existing sub-schemas. No new gem,
  no change to `Configuration`, `resolve_source`, or evidence fingerprints.
- Behavioral tests cover: a present file pre-filling allowed keys while commands come from
  flags; an absent file producing today's files byte for byte; a disallowed key and an
  invalid value each stopping setup with the file and key named and nothing written; a flag
  overriding a personal value; `--from` ignoring the file; and task-time resolution not
  reading the file when a clone has individual settings or the repository has team
  settings.
- `docs/settings-guide.md` and `docs/settings.md` describe the personal starting point, say
  it is read only when individual setup starts, and name it as a third home-directory file
  in "Which settings apply?". The private-setup procedure gains the proposal step in
  decision 4.
- A malformed personal file blocks individual setup on that machine until it is fixed or
  removed. It never blocks a task, because nothing else reads it.

## Delivery

Two PRs in order: this record, then the implementation after the maintainer approves it.
