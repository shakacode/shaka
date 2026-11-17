# Coding agents

Your coding agent supplies the model, tools, and permissions. Shaka supplies the
workflow that checks, reviews, and explains your pull request. Install it for
each coding agent you use. Each project keeps its own settings.

| Coding agent | Start a task | Where to use it |
| --- | --- | --- |
| Codex | `$shaka` | Desktop app or CLI |
| Claude Code | `/shaka` | Desktop app or CLI; on the web, see [Claude Code on the web](#claude-code-on-the-web) |
| Cursor | `/shaka` | Start a new Agent chat after installation |
| GitHub Copilot | `/shaka` | Copilot CLI or VS Code Agent chat; see [Copilot setup](#github-copilot) |
| OpenCode | `/shaka` | Use the installed skill in a session; an optional launcher is available |
| Pi | Load the installed Shaka skill | Uses Pi's existing permissions |

Use the [installation prompt](getting-started.md#1-install-shaka), or follow
[manual installation](manual-installation.md). On macOS, you can also
[start a task from Linear](linear.md) in Codex CLI. For [control towers](control-towers.md), use the desktop app: Codex towers need
desktop task tools, and Claude Code towers need desktop session tools.

## Name your machines

If you use Shaka on several computers, give each one a short public name so
**WIP Details → Owner** identifies where the chat is running:

```text
Help me name this machine "laptop" in Shaka
```

Ask the agent to set `SHAKA_MACHINE_ALIAS` for your coding tool and check it with
Shaka's doctor. The name also appears in [PR timings](reference/timings.md).

## GitHub Copilot

Ask Copilot to install Shaka, then start a new CLI session or VS Code Agent chat:

> Install Shaka from https://github.com/shakacode/shaka for GitHub Copilot.

In Copilot CLI, project skills override personal skills with the same name.
Before using `/shaka` in an untrusted checkout, use
[`ignoredSkillsLocations`](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference)
to exclude that checkout's `.github/skills`, `.claude/skills`, and `.agents/skills`
directories, including any added project roots. Check the discovered Shaka path
with `/skills` before invoking it.

Start with `/shaka` and your task. Shaka uses Copilot's existing model, tools,
and permissions. Both [Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
and [VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills)
document personal skills in `~/.copilot/skills`.

The installer is tested for Copilot's skills directory; a real Copilot delivery
has not yet been validated. Shaka has no Copilot launcher, native token-usage
reader, or Copilot local-review adapter. Local review uses a configured reviewer
such as Codex. When none is available and the host can open a fresh chat, Shaka
uses that chat with the implementation model as the fallback reviewer.
This installation is for local use; it does not install Shaka in Copilot's cloud agent.

## Cloud agents

A cloud agent can make changes and open a PR when it has the necessary tools and
repository access. If it cannot run a required review or check, it should report
what remains and stop before calling the PR ready.
If a PR exists, [resume it locally](working-with-shaka.md#resume-unfinished-work).
Before the first push, return to the original chat and checkout to continue.
That checkout may still be on the cloud machine.
See [cloud review options](reference/reviewer-setup.md#cloud-reviewers) for details.

### Claude Code on the web

Claude Code sessions on claude.ai/code start in a fresh container each time, so
Shaka is not there unless the cloud environment installs it. The container also
ships Ruby 3.3, and Shaka needs Ruby 3.4. Give the environment a setup script so
`/shaka` is ready in every new session. Ask Claude in a cloud session:

```text
Add a setup script to this cloud environment that installs Ruby 3.4 and Shaka for Claude Code
```

You approve the change on a card. To add it yourself, open the cloud environment
menu in the session's title bar, choose **Edit**, and paste this under
**Setup script**:

```bash
#!/bin/bash
set -euo pipefail
MAKE_OPTS=-j8 RUBY_CONFIGURE_OPTS=--disable-install-doc /opt/rbenv/bin/rbenv install -s 3.4.10
export PATH=/opt/rbenv/versions/3.4.10/bin:$PATH
umask 022
mkdir -p "$HOME/.local/share/shaka"
if [ ! -d "$HOME/.local/share/shaka/source" ]; then
  git clone -q https://github.com/shakacode/shaka.git "$HOME/.local/share/shaka/source"
fi
"$HOME/.local/share/shaka/source/bin/install" --agent claude
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --update ||
  echo "Shaka update failed; continuing with the installed revision" >&2
```

Building Ruby adds a few minutes to each new container. The script installs
Shaka from its own clone, separate from your project, so the branch you are
changing cannot change the Shaka that checks it. When a container keeps an
earlier clone, the update step brings it to the latest Shaka, so it accepts
settings your repository added since. If the update fails, the session still
starts on the installed version. The script applies to new sessions; a session
that is already running keeps what it has.

Shaka runs on the Ruby that installed it, but the session's own shell still
starts on Ruby 3.3. If your project's commands need Ruby 3.4 too, add these
lines to the end of the script. They install your project's gems and put Ruby
3.4's commands, such as `ruby`, `bundle`, and `rubocop`, first on the session's
`PATH`. Replace `REPO` with the folder your repository is cloned into, usually
its name:

```bash
# Gems for your project's commands when REPO is in the session.
if [ -d REPO ]; then (cd REPO && bundle install --quiet); fi
# Session shells start on the image's Ruby 3.3; ~/.local/bin comes first on their PATH,
# so link Ruby 3.4's commands (ruby, bundle, rubocop) there.
mkdir -p "$HOME/.local/bin"
for f in /opt/rbenv/versions/3.4.10/bin/*; do ln -sf "$f" "$HOME/.local/bin/"; done
```

Skip them for a project pinned to another Ruby: the links make Ruby 3.4.10 the
session's `ruby` whatever version the project selects.

A cloud session cannot yet open or finish a Shaka PR. Claude Code blocks GitHub's
GraphQL API there, and Shaka uses it to create the PR, publish its
description and walkthrough, and merge. Shaka's doctor reports a
failed **GitHub GraphQL** check. See [cloud reviewers](reference/reviewer-setup.md#cloud-reviewers)
for what still works. Make and validate the change in the cloud session, ask it
to push the branch, then continue in a local session. Validation and review
results stay in the cloud container, so the local session runs them again on the
pushed branch before it opens the PR:

```text
/shaka Continue the pushed branch BRANCH and open its PR
```

## Give consent once

Shaka may ask whether it can send your change to another provider for review.
It shows which repository, provider, and information the approval covers. If you
expect to use that reviewer again, choose **Yes, and don't ask again** to save
that consent in your own instructions. See [review consent details](reference/reviewer-setup.md#give-consent-once).

<details open>
<summary>Consent template</summary>

Before saving this, keep only the providers and repositories you want to cover.
If the reviewer receives a checkout path, it can read other files its own
sandbox allows. Keep secrets out of the checkout.

```text
Shaka review consent: local reviews of OWNER/REPO may send the committed diff,
its head commit with its files and checkout path, the review instructions and criteria, the
repository's review prompt, the PR description, and earlier review findings to
Anthropic (Claude CLI) and OpenAI (Codex CLI).
Never send secrets, credentials, .env files, or private data unrelated to the
change. Approved by NAME on DATE.
```

</details>

## Save a tool approval for future chats

Your coding tool may separately ask to run the reviewer command.
Save a narrow
approval for future chats when you use that command regularly and understand its
scope. A saved rule can let matching commands run without another approval.
Review what it covers before saving it. For example, a prefix rule for
`git status` can also match `git status --short`. If the rule matches more
than you want, approve only this run. Organization policy still applies.

| Coding tool | Remember an approval |
| --- | --- |
| Codex | In the CLI, accept a narrow command rule when Codex offers one. A matching command can run outside the sandbox without prompting, including in other projects or with extra arguments. See [Codex command rules](https://learn.chatgpt.com/docs/agent-configuration/rules). |
| Claude Code | In the CLI, choose **Yes, and don't ask again** when the offered pattern is appropriate. Claude Code saves a project-local rule; a prefix or wildcard can match other arguments. See [Claude Code settings](https://code.claude.com/docs/en/settings). |
| Cursor | In **Settings → Agents → Approvals & Execution**, add a narrow entry to the terminal allowlist if editable. Entries match prefixes and can cover extra arguments. If the editor is read-only, see [which file or team policy controls it](https://cursor.com/docs/reference/permissions). |

**Approve for me** in Codex desktop selects automatic approval review. In the
CLI, `/approve` can approve a denied action for one retry. Neither choice saves
permission for similar future commands. See [Codex Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review).

<a id="approve-private-code-reviews-in-codex"></a>

For Codex-specific policy and denied commands, see
[review permissions in Codex](reference/reviewer-setup.md#approve-private-code-reviews-in-codex).

<a id="when-codex-denies-the-review"></a>

If a command was denied, see [retry a denied review](reference/reviewer-setup.md#when-codex-denies-the-review).

<a id="set-up-claude-reviews-from-codex"></a>

## Set up a local reviewer

Ask your agent to check the review tools in your project:

```text
Help me use Claude for Shaka code reviews in this project. Check that it can run
```

The agent checks the configured reviewers, the installed tools, and sign-in. It
explains any settings PR or consent you need. See
[Claude reviews from Codex](reference/reviewer-setup.md#set-up-claude-reviews-from-codex)
and [reviewer settings](settings.md#reviewlocal_review_agents).

## Share project instructions across tools

Keep project rules in one place. Ask your agent to check the rules it loads:

```text
Check that this coding agent reads our existing AGENTS.md. Explain how to connect it if needed
```

See the project instruction guides for
[Codex](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[Claude Code](https://code.claude.com/docs/en/memory#agents-md), and
[Cursor](https://cursor.com/docs/rules). Claude Code can import `AGENTS.md`
from `CLAUDE.md` if it does not load the existing file directly.

<a id="codex-desktop-follow-up"></a>

For PR follow-up in Codex desktop, see
[Give feedback](working-with-shaka.md#give-feedback).
