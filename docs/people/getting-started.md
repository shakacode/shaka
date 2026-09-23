# Install Shaka and complete a first task

Shaka is a skill for coding agents. Install it from a trusted source checkout outside the repository the agent will edit.

## Before you start

You need Git, Ruby 3.4, an authenticated [GitHub CLI](https://cli.github.com/), and a supported agent host. Check:

```bash
git --version
ruby --version
gh auth status
```

Run `gh auth login` if needed. The first task below uses a repository that already has Shaka's `.agents/` configuration, such as this repository. For another repository, [add its configuration](#initialize-a-repository-seam) first.

## Install in Codex

Inspect the source and installer before running them. Clone outside the repository you will edit:

```bash
mkdir -p "$HOME/agent-tools"
git clone https://github.com/shakacode/shaka.git "$HOME/agent-tools/shaka"
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills"
```

Open a new Codex task in the repository. The Shaka skill should appear on the next turn; restart Codex if it does not.

<a id="use-shaka-in-claude-code"></a>
## Other hosts

Use the same trusted checkout and `bin/install`, changing only `--skills-dir`:

| Host | Skills directory | Invoke |
| --- | --- | --- |
| Claude Code | `$HOME/.claude/skills` | `/shaka` |
| Cursor | `$HOME/.cursor/skills` | `/shaka` in a new Agent chat |
| OpenCode | `$HOME/.config/opencode/skills` | `/shaka` in a new session |

For Codex terminal use, Pi, control towers, Cursor usage hooks, and host limitations, see [host support](host-support.md). Keep the installed source outside candidate checkouts and other writable agent directories.

<a id="use-shaka-in-cursor"></a>
<a id="use-shaka-in-opencode"></a>

## Complete the task

Send this in a task opened in a configured repository:

```text
$shaka Fix the failing search test. Bring the finished PR back so I can merge it on GitHub.
```

Use `/shaka` in Claude Code, Cursor, or OpenCode. Replace the example with an issue number, task URL, or description. For an issue number, Shaka uses the current repository. For a URL pointing elsewhere, it asks for that checkout if needed.

Shaka may ask you to confirm the recommended model and effort before editing. Then it creates a branch, verifies the change, opens a PR, handles review, and reports the result. This example uses **Ask**, so you make the final GitHub merge click when the PR is ready. Say “Merge when checks and required approvals pass” to choose **Auto** for the task.

<a id="initialize-a-repository-seam"></a>
## Configure a repository

A repository needs three executable scripts and a small policy file under `.agents/`. The scripts have fixed purposes: `setup` prepares a checkout, `test` runs focused tests, and `validate` runs the full gate. The YAML records review policy and merge preference. GitHub still decides which checks and approvals are required.

After identifying the repository's actual commands and policy, an agent can run:

```bash
"$HOME/.agents/skills/shaka/scripts/shaka" seam init \
  --root /path/to/repository \
  --setup-command "bin/setup" \
  --test-command "bundle exec rake test" \
  --validate-command "bin/validate" \
  --review-policy meaningful_changes \
  --ci-review-job claude-review
```

Replace each example command with a real command for that repository. The default merge preference is **Ask**. Use `--ci-review-job` only for a real CI review job; choose `--review-policy none` if the repository has no such review. The initializer refuses to overwrite repository-owned files. See the [configuration reference](../agents/settings.md) for values, validation, and existing-repository migration.

<a id="migrate-an-existing-seam"></a>
An existing repository contract needs [migration planning](../project/fleet.md#migration-checklist), not another `seam init` run.

## Check your setup

```bash
"$HOME/.agents/skills/shaka/scripts/shaka" doctor --root /path/to/repository
```

Doctor reports what is healthy, degraded, or failed and gives a next step. A failed check blocks publication. It does not edit the repository.

## Upgrade

Inspect local changes in the trusted source checkout, then fast-forward it and start a new task:

```bash
git -C "$HOME/agent-tools/shaka" status --short
git -C "$HOME/agent-tools/shaka" switch main
git -C "$HOME/agent-tools/shaka" pull --ff-only
```

The installer creates links to that checkout, so existing skills use the new code. Run `bin/install` again with your original `--skills-dir` and options if the release adds a skill you want. [Host support](host-support.md) explains host-specific setup.

## Remove

Inspect the installed links and remove only links that point to your Shaka checkout. For the Codex installation above:

```bash
ls -l "$HOME/.agents/skills/shaka"
test -L "$HOME/.agents/skills/shaka" && unlink "$HOME/.agents/skills/shaka"
```

For other hosts, use the skills directory in the table above. Removing the link leaves your repository, GitHub PRs, and trusted source checkout intact.
