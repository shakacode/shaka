# Releasing the Gem

Shaka uses an explicit RubyGems release flow adapted from
`shakacode/control-plane-flow`. The source prepares `1.0.0`.
Gem versions before `1.0.0` lack the current workflow.
A release starts from an approved version on `main`, validates the packaged artifact,
tags that exact commit, publishes the gem, and creates the matching GitHub release.
Registry publication requires explicit maintainer approval because a published version
cannot be replaced. A version change does not close pilot acceptance or qualify a host.

## Release process

1. Change `Shaka::VERSION` in `skills/shaka/lib/shaka/version.rb` through a reviewed pull
   request and merge it. The gemspec reads that constant, and `shaka seam init` stamps it
   into the `.agents/shaka.md` it generates. In the same PR, write the version's
   `CHANGELOG.md` entry. Feature PRs leave that file alone and put their note in the
   description's Changelog section. List the PRs merged since the previous tag:

   ```bash
   git log --first-parent --format=%s PREVIOUS_TAG..origin/main
   ```

   Each subject ends with `(#N)`. Read each PR's Changelog section with
   `gh pr view N --repo shakacode/shaka --json body`. Check the note against what the
   PR merged, and skip notes that say `None`. When a PR has no Changelog section or
   left it blank, check `## [Unreleased]` before writing a note: PRs merged before
   this process recorded their notes there. Merge the notes with any entries already
   under `## [Unreleased]`, grouped as the file's header format asks. Rename that heading
   to `## [VERSION] - YYYY-MM-DD` with the planned publication date,
   and add an empty `## [Unreleased]` above it. At the bottom, add a `[VERSION]` link
   comparing the previous tag to the intended tag, and change `[Unreleased]` to compare
   the intended tag to `HEAD`. If publication slips past that date, correct the heading before
   selecting the release commit.

   In the same PR, measure what Shaka's startup text costs. With Claude Code and Codex
   signed in, run `bin/report-instruction-growth --tokens PREVIOUS_TAG` on the `main` commit
   the PR starts from, and add a row for that commit to the log in
   [startup token cost](../internal/startup-token-cost.md) with each CLI's `after` and
   `cli_prompt` counts. Compare with earlier rows, not the report's `delta`: an older tag can
   lack files the startup text now includes, such as the workflow. When a CLI shows
   `UNKNOWN`, log its reason in the row instead of a count.
2. Start from a clean, current `main` checkout after those preparation edits land, and
   run `bundle install`.
3. Run the [release behavioral gate](https://github.com/shakacode/shaka/blob/main/eval/release-behavior.md)
   for each host, model, and effort profile you intend to qualify, and keep each batch's
   records outside the checkout. To release without it, the maintainer must accept that
   first; the published release notes then say the gate did not run. The maintainer
   waived the gate for 1.0.0
   ([decision 3](https://github.com/shakacode/shaka/issues/580#issuecomment-7206389918)),
   so prepare that release with `--skip-behavior-gate`.
4. Prepare the release inputs. Use a trusted Shaka helper installed outside this checkout;
   its installation identity is part of the validation evidence:

   ```bash
   shaka_helper=/absolute/path/to/trusted/shaka
   bin/release prepare --shaka "$shaka_helper" --out /outside/checkout/release \
     --behavior-records /outside/checkout/release-records.json
   ```

   `--out` must name a directory that does not exist yet, and a refused run keeps the one it
   created, so choose a new name to retry. Repeat `--behavior-records` for each profile, or
   pass `--skip-behavior-gate` instead.

   The command first confirms a clean checkout at `shakacode/shaka`'s `main`, before it
   loads the gemspec, the behavior checker, or validation. `bin/release` itself loads from
   the checkout, which is why step 2 starts from a clean `main`. It then checks each batch
   against this commit and runs `validate` through `evidence run`, which takes a while.
   Next it builds the gem, saves the version's `CHANGELOG.md` entry as `RELEASE_NOTES.md`,
   and runs the `bin/release-preflight` checks: matching validation and settings, package
   metadata, file contents and executable modes, notes that match the changelog, and no
   existing release tag. The output directory then holds the gem, the notes, the validation
   result, each behavior result, and `approval.json`, which names the commit, version, and
   their digests. Nothing remote changes. A pass does not establish host compatibility or
   grant publication authority.
5. Ask the maintainer to approve the commit, version, and digests in `approval.json`, and
   stop until the approval is recorded.
6. Check what publication will do, then publish:

   ```bash
   bin/release publish --approval /outside/checkout/release/approval.json --dry-run
   bin/release publish --approval /outside/checkout/release/approval.json
   ```

   `publish` rechecks the gem and notes against the approved digests. While the tag does
   not exist yet, it also requires remote `main` to still be the approved commit, because
   the tag is the first step users see: `install --release` pins to it. It then pushes the
   annotated tag `vVERSION`, pushes the gem (type the RubyGems MFA code when `gem push`
   asks), and creates the GitHub release from the notes. GitHub appends the merged PRs,
   grouped by label as `.github/release.yml` defines, and a prerelease version is marked
   as one. Last, it installs the version from RubyGems into a temporary `GEM_HOME` and runs
   `shaka --help`.

## Failure recovery

Run `bin/release publish` again with the same approval file. Each run reads the remote
tag, the RubyGems version, and the GitHub release separately, and performs only the steps
that are missing. When the install check fails right after a push, RubyGems may not serve
the version yet; rerun in a few minutes.

`publish` refuses when the tag points at another commit or RubyGems holds a different gem
for the version. Never reuse or overwrite a published version; prepare a new version
through a pull request instead.

## Publish without the command

`bin/release` is the supported path; when it fails, fix it or report it. If a release
cannot wait, do by hand what `publish` does, one step at a time, and stop at the first
surprise. Run every `gh` command as `GH_HOST=github.com gh ... --repo shakacode/shaka`.

1. Read what exists: remote `main`, `refs/tags/vVERSION`, and its peeled
   `refs/tags/vVERSION^{}` with `git ls-remote`; the version at
   `https://rubygems.org/api/v2/rubygems/shaka/versions/VERSION.json`; and the GitHub
   release with `gh release view --json isDraft,isPrerelease,body`. No tag lines at all
   means the tag is not pushed yet. Stop and prepare a new version when the tag line has no
   peeled line (it is not annotated), the tag peels to another commit, or RubyGems reports
   a `sha` other than the approved gem digest. A GitHub release can be replaced: when its
   prerelease flag differs from the version or its body lacks the approved notes, delete
   it and continue. A draft with the approved notes can be published or deleted.
2. Without a remote tag, confirm remote `main` is still the approved commit, create the
   annotated tag `vVERSION` on that commit, push only that tag with `--no-follow-tags`, and
   read it back until its peeled line shows the approved commit.
3. When RubyGems lacks the version, check the gem against its approved digest, then
   `gem push --host https://rubygems.org`.
4. When no GitHub release exists, check the notes against their approved digest. Create the
   release with `gh release create --verify-tag --generate-notes --notes-file NOTES`, where
   `NOTES` is the approved notes file, or a copy with the skipped-gate line added when the
   gate did not run. Add `--prerelease` for a prerelease version.
5. Set both `GEM_HOME` and `GEM_PATH` to a new temporary directory, install the version
   with `gem install --remote --clear-sources --source https://rubygems.org`, run its
   `shaka --help`, and delete the directory.
