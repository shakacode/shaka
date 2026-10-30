# Changelog

Notable changes to Shaka, newest first. Each release lists breaking changes with
upgrade steps, then what changed for users. The GitHub release for each version
lists every merged PR.

Versions follow [Semantic Versioning](https://semver.org/). From 1.0.0, a change
that stops an existing `.agents/shaka/config.yml` or a documented `shaka` command
from working is a major version.

## [Unreleased]

### Added

- Show PR timings in a chosen time zone with `pr_description.time_zone`. A repository
  that sets none uses the zone in your `~/.agents/shaka/config.yml`, then UTC.
- Announce a task's start on its GitHub issue with the WIP Details fields: owner,
  chat, branch, state, and the prompt that resumes it.

## [1.0.0] - Unpublished

Deliver a task through a tested pull request with a code walkthrough, independent
review, and an explicit Ask or Auto merge choice.

### Upgrade from the name reservation

The published `0.1.0.pre.1` gem only reserved the name. Existing source installations
retain their registered revision choice; installing this gem does not upgrade them.
After publication, new gem installations select the matching release tag. Follow
[getting started](docs/getting-started.md) to inspect and update an existing installation.

### Release safety

- Pin release installations to an immutable tag commit and preserve rollback choices.
- Check the exact source, tested gem and release notes before publication approval.
- Check native simulated merge and release decisions without granting publication authority.
- Preserve maintainer-controlled repository settings and native GitHub checks.

Real-use acceptance and host qualification remain evidence requirements; the
version number does not establish them.

## [0.1.0.pre.1] - 2026-09-16

Reserved the `shaka` name on RubyGems. This prerelease does not include the
current workflow; install from source as described in
[getting started](docs/getting-started.md).

[Unreleased]: https://github.com/shakacode/shaka/compare/v0.1.0.pre.1...HEAD
[1.0.0]: https://github.com/shakacode/shaka/compare/v0.1.0.pre.1...HEAD
[0.1.0.pre.1]: https://github.com/shakacode/shaka/releases/tag/v0.1.0.pre.1
