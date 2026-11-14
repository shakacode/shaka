# Shaka RubyGem

Shaka gives your coding agent a workflow for testing a change, getting an
independent review, and opening a pull request with evidence you can inspect.

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
