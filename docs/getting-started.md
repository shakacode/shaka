# Getting started

Install Shaka, connect it to your repository's checks, then give it a task.
Shaka is the successor to `shakacode/agent-workflows`; new installations need only
this repository.

## Prerequisites

You need Ruby 3.4, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
a [supported coding agent](host-support.md).

```bash
git --version
ruby --version
gh auth status
```

Use `gh auth login` if you are not signed in.

## Install

Review the source and installer, then clone into a directory outside the
repositories your agent will edit:

```bash
mkdir -p "$HOME/agent-tools"
git clone https://github.com/shakacode/shaka.git "$HOME/agent-tools/shaka"
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills"
```

This installs a link for Codex. Open a new task in your project and look for
`$shaka`; restart Codex if it does not appear.

<a id="use-shaka-in-claude-code"></a>
<a id="use-shaka-in-cursor"></a>
<a id="use-shaka-in-opencode"></a>
## Other hosts

Use the same installer with your host's skills directory:

| Host | `--skills-dir` | Invocation |
| --- | --- | --- |
| Claude Code | `"$HOME/.claude/skills"` | `/shaka` |
| Cursor | `"$HOME/.cursor/skills"` | `/shaka` in a new Agent chat |
| OpenCode | `"$HOME/.config/opencode/skills"` | `/shaka` in a new session |

Keep the source and links outside the agent's writable directories. See
[host support](host-support.md) for terminal launchers, Pi, Cursor usage hooks,
and tested limitations. [Control towers](control-towers.md) are optional.

<a id="initialize-a-repository-seam"></a>
## Configure a repository

If the repository already has `.agents/agent-workflow.yml` and executable
`.agents/bin/setup`, `test`, and `validate` scripts, continue to the first task.

Otherwise, ask your agent to inspect the repository's commands, CI, and GitHub
settings and prepare Shaka configuration. It needs your review policy and merge
preference; **Ask** is the default. A prompt can be as simple as:

```text
Configure this repository for Shaka. Use our existing setup, tests, and
validation commands. Keep merging at Ask. Check which review jobs actually
exist and ask me about any policy you cannot establish.
```

For a repository whose commands and review job match this example, the initializer
is:

```bash
"$HOME/agent-tools/shaka/skills/shaka/scripts/shaka" seam init \
  --root /path/to/repository \
  --setup-command "bin/setup" \
  --test-command "bundle exec rake test" \
  --validate-command "bin/validate" \
  --review-policy meaningful_changes \
  --ci-review-job claude-review
```

Replace every example command with the repository's actual command. If no CI
review job exists, use `--review-policy none` and omit `--ci-review-job`. Meaningful
implementation still gets local review. The initializer refuses to overwrite
conflicting files. Review and merge the setup PR before relying on its policy.
GitHub must expose required checks enforced for the account that will merge.

<a id="migrate-an-existing-seam"></a>
Existing configuration may need [migration](configuration.md#migrate-an-existing-contract).
The [configuration reference](configuration.md) defines the settings and scripts.

## Check the installation

```bash
"$HOME/agent-tools/shaka/skills/shaka/scripts/shaka" doctor --root /path/to/repository
```

Doctor reports healthy, degraded, and failed checks with next steps. Resolve
failures before publication; it does not edit the repository.

Other guides abbreviate the installed command to `shaka`. For a source
installation, use the full `skills/shaka/scripts/shaka` path shown above. The gem
also provides a `shaka` executable.

## Run your first task

Open a task in the configured repository and send:

```text
$shaka Fix search when the query contains an apostrophe.
Add a regression test and bring the PR back for me to merge.
```

Use `/shaka` in Claude Code, Cursor, or OpenCode. Replace the example with your
own task, issue number, or URL.

The agent may pause for model and effort selection. It then implements the change,
checks it, obtains review, and publishes a PR with a walkthrough. This prompt uses
Ask: the agent tells you which commit is ready, and you merge it on GitHub.
[Working with Shaka](working-with-shaka.md) explains Auto, feedback, and recovery.

## Upgrade

Inspect and preserve local changes in the trusted checkout, then fast-forward:

```bash
git -C "$HOME/agent-tools/shaka" status --short
git -C "$HOME/agent-tools/shaka" switch main
git -C "$HOME/agent-tools/shaka" pull --ff-only
```

Start a new task after upgrading. Installed links use the updated source.
Run the installer again with your original options if you want newly added skills.
Pilot configuration changes may also require a repository migration.

## Remove

Inspect the link first and confirm it points to this Shaka installation:

```bash
ls -l "$HOME/.agents/skills/shaka"
```

Then remove that link:

```bash
unlink "$HOME/.agents/skills/shaka"
```

Use the appropriate directory for other hosts. If you installed tower skills,
inspect and remove their links too: `rct`, or `mct-claude` and `rct-claude`.
Preserve unrelated files. Removing skill links leaves repositories and PRs intact.
