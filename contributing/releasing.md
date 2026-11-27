# Releasing the Gem

Shaka uses an explicit RubyGems release flow adapted from
`shakacode/control-plane-flow`. The source prepares `1.0.0`; it is not published.
The existing `0.1.0.pre.1` gem only reserves the name and lacks the current workflow.
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
   first; the published release notes then say the gate did not run.
4. Prepare the release inputs. Use a trusted Shaka helper installed outside this checkout;
   its installation identity is part of the validation evidence:

   ```bash
   shaka_helper=/absolute/path/to/trusted/shaka
   bin/release prepare --shaka "$shaka_helper" --out /outside/checkout/release \
     --behavior-records /outside/checkout/release-records.json
   ```

   `--out` must name a directory that does not exist yet. Repeat `--behavior-records` for
   each profile, or pass `--skip-behavior-gate` instead.

   The command first confirms a clean checkout at `shakacode/shaka`'s `main`, before any
   checkout code runs. It then checks each batch against this commit and runs `validate`
   through `evidence run`, which takes a while. Pass `--validation FILE` to reuse a completed
   result for the same commit; prepare copies it into the output directory. Next it builds
   the gem, saves the version's `CHANGELOG.md` entry as `RELEASE_NOTES.md`, and runs the
   `bin/release-preflight` checks: matching validation and settings, package metadata, file
   contents and executable modes, notes that match the changelog, and no existing release
   tag. The output directory then holds the gem, the notes, the validation result, each
   behavior result, and `approval.json`, which names the commit, version, and their digests.
   Nothing remote changes. A pass does not establish host compatibility or grant
   publication authority.
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

If `bin/release` cannot run, publish the approved files by hand. Before the tag, confirm
that remote `main` is still the approved commit and that RubyGems, the remote tags, and
GitHub releases do not have the version yet:

```bash
shaka_version=VERSION
git ls-remote https://github.com/shakacode/shaka.git refs/heads/main
curl -fsS "https://rubygems.org/api/v2/rubygems/shaka/versions/$shaka_version.json"
git ls-remote --exit-code --tags https://github.com/shakacode/shaka.git "refs/tags/v$shaka_version"
gh release view "v$shaka_version" --repo shakacode/shaka
```

The first command should print the approved commit, and the other three should report
that the version does not exist. Then publish with one command chain, so a failed step stops
every step after it:

```bash
git tag -a "v$shaka_version" APPROVED_COMMIT -m "Release shaka $shaka_version" &&
  git push https://github.com/shakacode/shaka.git "refs/tags/v$shaka_version" &&
  ruby -rdigest -e 'abort "Gem differs from approval" unless
    Digest::SHA256.file(ARGV[0]).hexdigest == ARGV[1]' GEM_PATH APPROVED_GEM_SHA256 &&
  gem push --host https://rubygems.org GEM_PATH &&
  ruby -rdigest -e 'abort "Notes differ from approval" unless
    Digest::SHA256.file(ARGV[0]).hexdigest == ARGV[1]' NOTES_PATH APPROVED_NOTES_SHA256 &&
  gh release create "v$shaka_version" --repo shakacode/shaka --verify-tag \
    --title "shaka $shaka_version" --notes-file NOTES_PATH --generate-notes
```

Add `--prerelease` to `gh release create` for a prerelease version. When the behavior gate
was skipped, the notes check still reads the approved file; pass a copy with this line
added as `--notes-file`: `The release behavior gate did not run for this release.` Last,
set `GEM_HOME` and `GEM_PATH` to a new temporary directory, run
`gem install shaka --version "$shaka_version" --remote --clear-sources --source https://rubygems.org`
and its `shaka --help`, then delete the directory.
