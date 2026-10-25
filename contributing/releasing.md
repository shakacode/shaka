# Releasing the Gem

Shaka uses a small, explicit RubyGems release flow adapted from
`shakacode/control-plane-flow`. Public product stage is `0.0.x`; the gem identifier
stays on `0.1.0.pre.N` because `0.1.0.pre.1` is already published. Do not publish a
`0.0.x` gem: RubyGems would still treat `0.1.0.pre.1` as newer for `--pre` installs.
A release starts from an approved version on `main`,
validates the packaged artifact, tags the exact source commit, publishes the gem, and
creates the matching GitHub release. Registry publication requires explicit maintainer
approval because a published version cannot be replaced.

## Release process

1. Change `Shaka::VERSION` in `skills/shaka/lib/shaka/version.rb` through a reviewed pull
   request and merge it. The gemspec reads that constant, and `shaka seam init` stamps it
   into the `.agents/shaka.md` it generates.
2. Start from a clean, current `main` checkout.
3. Install dependencies and run the repository validation:

   ```bash
   bundle install
   shaka_helper=/absolute/path/to/trusted/shaka
   "$shaka_helper" evidence run --root . --ref RELEASE_SHA \
     --repository shakacode/shaka --command validate > /outside/checkout/validation.json
   ```

4. Build and inspect the gem before changing any remote state:

   ```bash
   gem build shaka.gemspec --output /outside/checkout/shaka-VERSION.gem
   gem specification /outside/checkout/shaka-VERSION.gem
   ```

5. Confirm the version's `CHANGELOG.md` entry merged with the version change: a short
   summary, then breaking changes with upgrade steps. Save that entry's body as
   `RELEASE_NOTES.md`, then obtain explicit maintainer approval for the registry
   publication. Before requesting approval, run the maintainer preflight from the
   source checkout, with the gem, original validation JSON, and notes saved outside it:

   ```bash
   bin/release-preflight --commit RELEASE_SHA --gem /outside/checkout/shaka-VERSION.gem \
     --validation /outside/checkout/validation.json --notes /outside/checkout/RELEASE_NOTES.md \
     --shaka "$shaka_helper"
   ```

   A passing result identifies the commit, version, gem digest, validation digest and
   notes digest for approval. Ruby checks a clean checkout at `shakacode/shaka`'s `main`, matching
   validation and settings, package metadata, file contents and executable status,
   matching changelog notes, and absence of the release tag. It makes no remote changes.
   Use the same trusted helper outside the release checkout for validation and
   preflight binding; its installation identity is part of the evidence.
   Keep the JSON with the release evidence. A pass does not establish behavioral or
   host compatibility, check registry availability, or grant publication authority.
   Obtain approval for those exact inputs; stop until it is recorded. The preflight
   is repository maintenance tooling and is not included in the gem.

6. Set the approved version and confirm it is absent from RubyGems, GitHub releases,
   and remote tags. The first command lists existing prereleases; the latter commands
   should report that the target does not exist:

   ```bash
   shaka_version=0.1.0.pre.2
   gem list shaka --remote --all --exact --prerelease
   gh release view "v$shaka_version"
   git ls-remote --exit-code --tags origin "refs/tags/v$shaka_version"
   ```

7. Tag and push the validated commit:

   ```bash
   git tag -a "v$shaka_version" -m "Release shaka $shaka_version"
   git push origin "refs/tags/v$shaka_version"
   ```

8. Publish with the maintainer's RubyGems credentials and MFA code:

   ```bash
   gem push "/outside/checkout/shaka-$shaka_version.gem"
   ```

9. Create the GitHub release from the verified tag and reviewed notes. GitHub appends
   the merged PRs, grouped by label as `.github/release.yml` defines. Use
   `--prerelease` only for a prerelease version; omit it for a stable version:

   ```bash
   gh release create "v$shaka_version" --verify-tag --prerelease \
     --title "shaka $shaka_version" --notes-file /outside/checkout/RELEASE_NOTES.md --generate-notes
   ```

10. Verify RubyGems and GitHub, then install the exact version into a temporary
    `GEM_HOME` from the registry. Exercise `shaka --help`, then remove it:

    ```bash
    gem list shaka --remote --all --exact --prerelease
    gh release view "v$shaka_version"
    shaka_gem_home=$(mktemp -d)
    GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" \
      gem install shaka --version "$shaka_version" --no-document
    GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" \
      "$shaka_gem_home/bin/shaka" --help
    GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" \
      gem uninstall shaka --all --executables
    ```

## Failure recovery

Before retrying, check RubyGems, the remote tag, and the GitHub release independently.
If the gem was published but the GitHub release failed, preserve the tag and create the
release. If the tag was pushed but RubyGems rejected the upload, diagnose credentials,
MFA, or package policy before retrying the same artifact. Never reuse or overwrite a
published version; prepare a new version through a pull request instead.
