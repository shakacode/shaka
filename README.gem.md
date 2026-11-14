# Shaka RubyGem

Use the Shaka gem to validate a project's team configuration in
`.agents/shaka/` before pushing a change or merging a pull request. The check
needs Ruby 3.4 or later and runs without installing a coding-agent skill.

## Validate team configuration

Once Shaka 1.0.0 is published on RubyGems, run these commands from the project
root. Use the same version for installation and execution so another installed
version cannot change the validation rules.

```sh
SHAKA_VERSION=1.0.0
gem install shaka --version "$SHAKA_VERSION" --no-document
shaka "_${SHAKA_VERSION}_" seam check --root . --local
```

In CI, check out the proposed change, set up Ruby 3.4 or later, and run the same
commands from the checkout root. If the job runs from another directory, pass
the checkout path to `--root` (for example, `--root "$GITHUB_WORKSPACE"` in GitHub
Actions).

The check validates `.agents/shaka/config.yml` and the project’s required Shaka command scripts.
It exits nonzero for invalid settings, unsafe paths, or missing or non-executable
scripts. A passing result reports `local/candidate` mode with policy and merge
authority both disabled.

## Install the skill

Use Ruby 3.4 or later, Git, and an authenticated
[GitHub CLI](https://cli.github.com/). After the release is available on RubyGems,
install the gem and link the skill to your coding agent:

```sh
gem install shaka
shaka-install --agent codex
```

Replace `codex` with `claude`, `cursor`, `opencode`, or `copilot` as needed.
The installer fetches the source checkout for the gem's release on a fresh
installation. Start a new chat and follow the
[getting-started guide](https://shaka.shakacode.com/docs/getting-started)
for your first task.

## Use the CLI

The gem installs `shaka` directly. Run `shaka --help` for available commands or
`shaka workflow` to read the workflow. You can run both from an installed gem
without network access.

See the [public guides](https://shaka.shakacode.com/docs/) for setup and
troubleshooting, or browse the [source on GitHub](https://github.com/shakacode/shaka).
The gem includes the [MIT license](https://github.com/shakacode/shaka/blob/main/LICENSE).
