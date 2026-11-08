# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
From 1.0.0, a change that stops an existing `.agents/shaka/config.yml` or a
documented `shaka` command from working is a major version.

## [Unreleased]

Deliver a task through a tested pull request with a code walkthrough, independent
review, and an explicit Ask or Auto merge choice. Real-use acceptance and host
qualification remain evidence requirements; the version number does not establish them.

### Added

- Rate each PR's risk as low, medium, or high in the checkpoint, with reasons, and say
  what that rating asks of the merge: a skim for medium, a careful review that starts
  with the verification for high. A missing rating shows as unknown and counts as high. Changes to databases, persistence, infrastructure,
  CI and trust, or Shaka's settings always count as high; set `high_risk_areas` to
  change those paths. Set `merge.auto_merge_max_risk` to `low` to let Auto merge only
  low-risk PRs, or to `medium` to add medium risk, instead of using
  `merge.auto_max_review_floor`. Left unset, the floors decide and the rating stays a
  preview in the checkpoint comment.
- Keep complete usage accounting when a PR description outgrows GitHub's limit.
  The description retains its tables and pricing notes, with checksummed links to
  accounting comments. A missing or changed archive blocks later updates.
  Older helpers refuse to replace archived descriptions; update Shaka before refreshing one.
- Install pstack beside Shaka in Cursor, Claude Code, or Codex, and keep it current,
  with the [pstack guide](docs/pstack.md). The guide also gives a prompt for building
  your own updater for agent skill packs.
- Show a PR's Timings as text bars, so you can see where the time went, what ran
  together, and when the PR waited on a person. Steps that passed or finished now
  appear only in the bars, and the table keeps a row for each step that did not.
- Show PR timings in a chosen time zone with `pr_description.time_zone`. A repository
  that sets none uses the zone in your `~/.agents/shaka/config.yml`, then UTC.
- Announce a task's start on its GitHub issue with the WIP Details fields: owner,
  chat, branch, state, and the prompt that resumes it.
- Keep usage on the PR with `shaka usage publish` and `shaka usage collect`. Each
  publication appends its own comments, so contributors cannot overwrite each other,
  and a new owner recovers usage without the earlier machine's transcripts.
- Get plainer wording for terms a maintainer new to Shaka would not follow. The advisory
  opening check now also reads a description's visible Intent and Verification text and
  suggests a replacement for each term. A description with new text adds one call to the
  opening reviewer.
- Pin release installations to an immutable tag commit and preserve rollback choices.
- Check the exact source, tested gem and release notes before publication approval.
- Check native simulated merge and release decisions without granting publication authority.

### Changed

- Explain how to use a PR's evidence packet for the next decision and regular
  retrospectives, with a shorter reading path and supporting reference details.

- Clarify where to find merge choices and recovery help, and what to check in
  the playground tutorial before approving a PR.
- Task references in PR descriptions now require a link or a visible explanation
  that the URL is unavailable or cannot be shared. Previously unlinked task metadata
  needs a URL or omission reason before republishing; prompt tasks and numbered
  GitHub references keep their existing behavior.
- The `shaka` gem carries the current workflow. The published `0.1.0.pre.1` gem only
  reserved the name. New gem installations select the matching release tag. Installing
  the gem does not upgrade an existing source installation, which keeps its registered
  revision choice; follow [getting started](docs/getting-started.md) to inspect and
  update one.
- Preserve maintainer-controlled repository settings and native GitHub checks.
- A PR description lists the contributor's understanding of the task as **Goal** and
  **Done when** under the Task line, where it used to sit in a **Task as understood**
  fold. You can compare the task with the result without expanding anything, and the
  text no longer runs into **Root cause**. It now counts toward the description's
  visible word limits.

### Removed

- **Breaking:** Shaka no longer reads `.agents/agent-workflow.yml` or `.agents/bin/`;
  settings live only in `.agents/shaka/`. Convert and merge the result before
  updating: clone this repository at commit `a01a3a7e9705be165b7bf339b0cc6d2b727ce4d7`
  and run its `skills/shaka/scripts/shaka seam upgrade --root DIR` to preview, then add
  `--apply --digest PREVIEW_DIGEST`. Later commits no longer include `seam upgrade`.
- **Breaking:** The `wip.include_locations` setting is gone; set
  `wip.include_checkout_path` instead.

### Fixed

- `shaka pr` works in Claude Code cloud sessions, where GitHub refuses GraphQL. It reads
  the pull request and its required checks over REST and lists the fields REST can't
  show, such as the review decision, as unknown. Other pull request commands still need GraphQL.

- Run the installed Shaka helper from a shell that sets no locale, as some cloud containers
  do. The helper then sets a UTF-8 `LANG`, which the Ruby, Git, and GitHub CLI commands it
  starts inherit, so UTF-8 text no longer fails as invalid US-ASCII. The agent `shaka work`
  starts inherits it too. A locale you set is kept.

- Codex publications keep the model's `(configured)` label without repeating the
  served-model caveat. Missing or unreadable attribution still shows a warning.

- Give more installer refusals a next command that fixes them, or say that you must decide.
  A Shaka folder you also develop in now gets the commands that remove its clean
  worktrees and merged branches, and names any work that exists only there, instead of
  a `--take-over` that fails. A writable folder you own names `chmod go-w`, local commits name
  the step that keeps them on a branch, and a mistyped `--branch` no longer prints a
  `git switch` that fails.

- Clear the temporary worktree an interrupted `install --update` leaves in the source
  checkout. `install --status` now reports it as an interrupted update and names
  `install --update`, which removes it, instead of calling it development work with no
  command that clears it. `install --verify` no longer warns about it. A worktree left by
  an update from an earlier version still shows as development; remove it with
  `git -C SOURCE worktree remove --force --force PATH`, using the source checkout and
  worktree path status lists.

- Replace circular checkpoint links during open decisions with a waiting status.
  Decision-writing guidance now asks for options, consequences, a recommendation,
  and a clear way to answer.

- Finish a PR's description after the maintainer merges a PR whose checkpoint waited
  on their decision. The merge counts as the answer: an empty decisions list now
  publishes, and the "waiting for the maintainer's decision" warning comes off.

- Keep validation and review results valid when Shaka updates during a task, unless the
  update changes the code that runs or checks them. Rewording a description for the same
  commit now keeps results it already shows as verified instead of refusing or showing UNKNOWN.
- Say **Adequate, with gaps the reviewer judged acceptable** on a checkpoint, in place of
  **Adequate with accepted gaps**, which read as if the maintainer had accepted them.
  Published checkpoints still parse.
- Stop PR descriptions from asking for every line to be reviewed. The **Review effort** line
  is now **Human review**: it names the files that set the rating, and it
  no longer promises reproduction or a second reviewer. Settings keep their names, and Auto
  merge holds back the same PRs. See [#1001].
- Show `ready in` and `merged in` on more PRs. The description now reads the task
  start from a usage report that covers the whole task, and records the ready time
  each time it updates instead of only while a watch runs.

## [0.1.0.pre.1] - 2026-09-16

Reserved the `shaka` name on RubyGems. This prerelease does not include the
current workflow; install from source as described in
[getting started](docs/getting-started.md).

[Unreleased]: https://github.com/shakacode/shaka/compare/v0.1.0.pre.1...HEAD
[0.1.0.pre.1]: https://github.com/shakacode/shaka/releases/tag/v0.1.0.pre.1
[#1001]: https://github.com/shakacode/shaka/issues/1001
