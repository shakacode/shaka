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
   into the `.agents/shaka.md` it generates. Before selecting the release commit,
   finalize the changelog heading with the publication date and compare the previous
   tag to the intended release tag. Set `Unreleased` to compare the intended tag to
   `HEAD`. Merge these source edits through a reviewed preparation PR.
2. Start from a clean, current `main` checkout after those preparation edits land.
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
   `RELEASE_NOTES.md`. Before requesting publication approval, complete the
   [release behavioral gate](https://github.com/shakacode/shaka/blob/main/eval/release-behavior.md) for the intended host/model/effort
   profiles and retain its results. Then run the maintainer preflight from the
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
   Run the behavioral gate with this preflight's `commit` as its required `--commit`
   input. Ruby refuses a mismatched skill or batch. Require passing results for every
   intended profile before requesting approval.
   Obtain approval for those exact inputs; stop until it is recorded. The preflight
   is repository maintenance tooling and is not included in the gem.

6. Set the approved version and confirm it is absent from RubyGems, GitHub releases,
   and remote tags. The first command lists existing prereleases; the latter commands
   should report that the target does not exist:

   ```bash
   shaka_version=1.0.0
   gem list shaka --remote --all --exact --prerelease
   gh release view "v$shaka_version" --repo shakacode/shaka
   git ls-remote --exit-code --tags https://github.com/shakacode/shaka.git "refs/tags/v$shaka_version"
   ```

7. Tag and push the validated commit. Replace `APPROVED_COMMIT` with the `commit`
   recorded in the approval:

   ```bash
   git tag -a "v$shaka_version" APPROVED_COMMIT -m "Release shaka $shaka_version"
   git push https://github.com/shakacode/shaka.git "refs/tags/v$shaka_version"
   ```

8. Publish with the maintainer's RubyGems credentials and MFA code. Replace
   `APPROVED_GEM_SHA256` with the approved `gem_sha256`. Keep the digest check joined
   to the upload with `&&` so a changed file stops publication:

   ```bash
   ruby -rdigest -e 'abort "Gem differs from approval" unless
     Digest::SHA256.file(ARGV[0]).hexdigest == ARGV[1]' \
     "/outside/checkout/shaka-$shaka_version.gem" APPROVED_GEM_SHA256 &&
     gem push "/outside/checkout/shaka-$shaka_version.gem"
   ```

9. Create the GitHub release from the verified tag and reviewed notes. GitHub appends
   the merged PRs, grouped by label as `.github/release.yml` defines. Use
   `--prerelease` only for a prerelease version; omit it for a stable version.
   Replace `APPROVED_NOTES_SHA256` with the approved `notes_sha256` and keep its
   check joined to release creation:

   ```bash
   ruby -rdigest -e 'abort "Notes differ from approval" unless
     Digest::SHA256.file(ARGV[0]).hexdigest == ARGV[1]' \
     /outside/checkout/RELEASE_NOTES.md APPROVED_NOTES_SHA256 &&
     gh release create "v$shaka_version" --repo shakacode/shaka --verify-tag \
       --title "shaka $shaka_version" --notes-file /outside/checkout/RELEASE_NOTES.md --generate-notes
   ```

10. Verify RubyGems and GitHub, then install the exact version into a temporary
    `GEM_HOME` from the registry. Exercise `shaka --help`, then remove it:

    ```bash
    gem list shaka --remote --all --exact --prerelease
    gh release view "v$shaka_version" --repo shakacode/shaka
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
