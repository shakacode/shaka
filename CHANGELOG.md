# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
From 1.0.0, a change that stops an existing `.agents/shaka/config.yml` or a
command listed in [what stays compatible in 1.x](https://shaka.shakacode.com/docs/migration#what-stays-compatible-in-1x)
from working is a major version.

## [Unreleased]

## [1.0.0] - 2026-11-27

Shaka 1.0 is the first stable release of the Shaka skill for AI coding agents.
Give your agent a task and get a pull request with the checks it ran, an
independent review for substantial changes, and any gaps you still need to assess.
Use [Ask or Auto](https://shaka.shakacode.com/docs/working-with-shaka#choose-a-merge-policy) to choose how
Shaka handles merging. Repository checks and approvals still apply.

The [release behavioral gate](https://github.com/shakacode/shaka/blob/main/eval/release-behavior.md)
did not run for 1.0.0; it applies again to later releases.

### Added

- Install Shaka and run local validation and review from a native Windows
  shell. `bin/install` accepts and later verifies a fresh checkout.
  `shaka evidence run` starts repository commands. `shaka review run` finds
  `git.exe` and reviewer `.exe` files. An interrupted or timed-out review or
  `shaka doctor` check tries to stop its processes, and a review warns when
  some may still be running. Windows checks run in CI but do not yet block
  merges. See
  [manual installation](https://shaka.shakacode.com/docs/manual-installation)
  for the PowerShell steps.
- For a fresh install on Ruby 3.4 or later, run `gem install shaka --version 1.0.0`
  and `shaka-install _1.0.0_ --agent codex`. The installer links the skill to the matching
  GitHub release. Existing installations keep their registered branch or release.
  See [manual installation](https://shaka.shakacode.com/docs/manual-installation)
  for source installs and how to switch to a published release. The installer can
  link the skill for GitHub Copilot. Copilot installation has been tested, and
  a full Copilot delivery remains unverified.
- Try Shaka on a small task with individual settings kept in your local clone.
  Teams can review shared settings in a PR and try that PR's pinned settings
  before adopting them. You can also try an unmerged Shaka revision without
  changing your normal installation.
- Resume unfinished PRs from the recorded revision, checks, and next action.
  Use `install --status` and `install --repair` for installation recovery. You
  can retain the old checkout when you switch releases and restore its skill
  links if needed.
- See evidence on the PR for what changed, what passed, and what the reviewer
  found. Ask for a code walkthrough, use interactive mode to steer a draft PR,
  and use timing and token estimates to review your delivery process. Usage
  reports cover Antigravity and price GPT-6.2 and Gemini models. When the agent has
  published a UI check, the description links it as **Screenshots**. Shaka's
  own records sit under **Shaka metrics** in one 🤙 Shaka details fold, led by
  a copyable Claude or Codex chat link when one is available. Shaka asks the
  agent for squash messages that lead with the outcome, draw on the whole PR
  description, and list changes, limits, and follow-ups as bullets.
- With team settings, list your team's skills in `.agents/shaka/packs/` on the
  default branch so Shaka offers each one at the step where it helps. PRs show
  the results of those companion skills, including whether their findings were
  applied. See
  [offer your team's skills](https://shaka.shakacode.com/docs/working-with-shaka#offer-your-teams-skills-at-the-right-step).
- With `project_guidance.pr_evidence` set, add a `<!-- shaka -->` line to your
  pull request template to choose where Shaka's sections appear. See [use your pull request template](https://shaka.shakacode.com/docs/pr-template).
- Make and validate a change in Claude Code on the web, then continue in a local
  session to open and finish its PR. See
  [cloud sessions](https://shaka.shakacode.com/docs/cloud-sessions).

### Changed

- A PR description for a task other than a prompt or a numbered GitHub issue
  or PR in the same repository needs exactly one of a safe https task link or a
  visible omission reason. Common description input errors are reported
  together, with each exact overage. When a description has no validation or
  review results of its own and Shaka finds a review the same GitHub account
  published that still covers its commit, it links that review and says why
  it still applies. Descriptions and walkthroughs refuse a bare finding ID such
  as `N3` in visible prose; describe the finding in words.
  When an identity field is unknown, the first line keeps the agent and drops
  the other unknown fields; the full identity appears under **Missing values**.
- Local Codex reviews run without connected ChatGPT apps, web search, or image
  viewing. Read-only shell inspection remains available. With file-backed
  sign-in, they also skip your global `AGENTS.md`.
- Existing 1.x `.agents/shaka/config.yml` files and the commands
  [Update Shaka](https://shaka.shakacode.com/docs/migration#what-stays-compatible-in-1x)
  lists keep working across 1.x updates. Commands Shaka runs for the agent can
  change within 1.x. Use the target release to check settings before
  switching. For team settings, run `shaka seam check --root DIR --ref DEFAULT_SHA`
  and confirm it reports `trusted/ref` for that commit. For individual settings,
  run `shaka seam private check --root DIR --ref DEFAULT_SHA`.
  Follow [Update Shaka](https://shaka.shakacode.com/docs/migration) for upgrade guidance.
- Risk ratings use low, medium, and high. Auto defaults to low-risk changes.
  Higher risk or a missing rating requires explicit attention under the merge
  policy. Required checks and approvals take precedence.
- New individual setups hide the checkout path in unfinished PRs. Your personal
  settings can also hide your checkout path when shared settings would show it.
- Branch installs reuse recent successful update checks. Claude Code installs add
  a chat-start reminder unless you select `--no-session-hook`.
  Published releases stay pinned to the release commit you chose.

### Removed

- **Breaking:** Migrate the pilot layout `.agents/agent-workflow.yml` and
  `.agents/bin/` to `.agents/shaka/` before switching to 1.0. Check out Shaka at
  [`a01a3a7`](https://github.com/shakacode/shaka/tree/a01a3a7e9705be165b7bf339b0cc6d2b727ce4d7).
  From that checkout, run `skills/shaka/scripts/shaka seam upgrade --root DIR`
  to preview, then add `--apply --digest PREVIEW_DIGEST`. Validate the converted
  settings with Shaka 1.0 and run the moved commands before merging the settings PR.
- **Breaking:** Replace `wip.include_locations` with `wip.include_checkout_path`.
- **Breaking:** Move paths covered by `merge.auto_max_review_floor` or
  `pr_description.human_review_floors` to `high_risk_areas` or `medium_risk_areas`.
  Then remove those retired keys. Use `merge.auto_merge_max_risk` to set the
  highest risk eligible for Auto. Shaka 1.0 rejects the retired keys. See
  [`merge.auto_merge_max_risk`](https://shaka.shakacode.com/docs/settings#mergeauto_merge_max_risk).

### Fixed

- Installer diagnostics give a recovery command or explain which decision you
  need to make. `shaka doctor --brief` and `shaka install --status` show the main
  issue and its next step; `shaka install --status --json` lists every finding.
  On an older Ruby, the installer suggests mise or rbenv. Interrupted branch
  updates can clean up their temporary worktree. `bin/install --directory`
  aimed at a worktree of the default install gives a next step that works for
  that worktree's state.
- In a public repository, `shaka reply` links a cited comment whose author
  `shaka comments` would withhold instead of quoting it. Your own comments
  are still quoted.
- Validation keeps evidence tied to the tested tree and settings. Fixes to a base
  branch are tracked separately when that branch already fails a check.
- Claude Code cloud sessions can read PR status and publish PR descriptions when
  GitHub's GraphQL transport is unavailable. Some other commands still require it.

## [0.1.0.pre.1] - 2026-09-16

Reserved the `shaka` name on RubyGems. This prerelease does not include the
current workflow; install from source as described in
[getting started](https://shaka.shakacode.com/docs/getting-started).

[Unreleased]: https://github.com/shakacode/shaka/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/shakacode/shaka/compare/v0.1.0.pre.1...v1.0.0
[0.1.0.pre.1]: https://github.com/shakacode/shaka/releases/tag/v0.1.0.pre.1
