# Build and test the pilot gem

The gem packages the same skills, workflow configuration, installer, and Ruby helpers
as the source checkout. The `shaka` skill is a small trust bootstrap: `shaka workflow`
strictly validates and renders its packaged `skills/shaka/config/workflow.yml` before
an agent follows the procedure.
It adds no runtime gems and does not install a global agent profile. Public product
stage is `0.0.x`. Version
`0.1.0.pre.1` is [published on RubyGems.org](https://rubygems.org/gems/shaka) to reserve the `shaka` name;
later registry artifacts stay on `0.1.0.pre.N`. Do not publish a `0.0.x` gem:
`gem install shaka --pre` would still prefer `0.1.0.pre.1` over any `0.0.x`
version. The source
installation remains the verified pilot path; registry publication does not establish
broader host compatibility.

Build from the trusted source directory; RubyGems reads package files relative
to the working directory. With the source installation from the first-use guide:

```bash
cd "$HOME/agent-tools/shaka"
gem build shaka.gemspec
```

To try the built package without changing your application bundle or normal gem
installation, use a separate gem home. These environment values apply only to the
individual commands:

```bash
shaka_gem_home=$(mktemp -d)
GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" gem install --local --no-document ./shaka-0.1.0.pre.1.gem
GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" "$shaka_gem_home/bin/shaka" --help
GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" "$shaka_gem_home/bin/shaka" workflow
```

Keep this temporary home for packaging checks only. A real pilot installation must
keep its trusted source outside the agent's writable directories, including any
temporary directories the host allows. Do not export the test gem environment into
your application's shell or add the pilot to its Gemfile.

Applications that only need the experimental public-comment screen can load
`shaka/public_comments` from this package without the skill; see
[screen public comments from Ruby](public-comments.md).

The package also contains `shaka-install --skills-dir DIR`, which calls
the existing explicit-directory installer. It installs the portable `shaka` skill
by default; add `--with-rct` only for a Codex app skills directory, or
`--with-claude-towers` only for a Claude Code desktop skills directory. It preserves
existing content and refuses to replace a different source. The
[first-use guide](getting-started.md) explains the trusted source and host startup
boundaries.

## Upgrade, rollback, and removal

RubyGems installs each version in its own directory. A manually installed skill
link keeps pointing to its original version. To change that link, inspect its
destination, remove only the known pilot symlinks, then run the new version's
installer. Do not remove a foreign directory or silently repoint another skill.
You can retain the prior gem version and relink it for rollback.

Remove the pilot `shaka`, `rct`, `mct-claude`, and `rct-claude` skill links before uninstalling the
version they point to. For the
isolated packaging check above:

```bash
GEM_HOME="$shaka_gem_home" GEM_PATH="$shaka_gem_home" gem uninstall shaka --all --executables
```

A two-version artifact trial also confirmed explicit upgrade and rollback while
preserving an existing skill link. The package test builds and installs the actual gem into a temporary home, runs
the installed helper and installer from outside the source checkout, then removes
the package. Existing installer tests cover repeat installation, collisions, and
source updates. These checks validate the artifact; they do not establish host
compatibility or authorize a registry release.

The prerelease package is `shaka` version `0.1.0.pre.1`, distributed under the
[MIT license](../LICENSE). The gem includes the license and declares it in its metadata.
Future registry publication still requires separate maintainer approval and follows
the [release process](releasing.md). Packaging uses
[standard RubyGems tooling](https://guides.rubygems.org/make-your-own-gem/).
