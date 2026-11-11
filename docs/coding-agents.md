# Coding agents

Your coding agent supplies the model, tools, and permissions. Shaka supplies the
workflow that checks, reviews, and explains your pull request. Install it for
each coding agent you use. Each project keeps its own settings.

| Coding agent | Start a task | Where to use it |
| --- | --- | --- |
| Codex | `$shaka` | Desktop app or CLI |
| Claude Code | `/shaka` | Desktop app or CLI |
| Cursor | `/shaka` | Start a new Agent chat after installation |
| GitHub Copilot | `/shaka` | Copilot CLI or VS Code Agent chat; see [Copilot setup](#github-copilot) |
| OpenCode | `/shaka` | Use the installed skill in a session; an optional launcher is available |
| Pi | Load the installed Shaka skill | Uses Pi's existing permissions |

Use the [installation prompt](getting-started.md#1-install-shaka), or follow
[manual installation](manual-installation.md). On macOS, you can also
[start a task from Linear](linear.md) in Codex CLI. For multi-repository coordination, see [control towers](control-towers.md).

## Name your machines

If you use Shaka on several computers, give each one a short public name so
**WIP Details → Owner** identifies where the chat is running:

```text
Help me name this machine "laptop" in Shaka.
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
[Resume locally](working-with-shaka.md#resume-unfinished-work) to finish the work.
See [cloud review options](reference/reviewer-setup.md#cloud-reviewers) for details.

## Give consent once

Shaka may ask whether it can send your change to another provider for review.
It shows which repository, provider, and information the approval covers. If you
expect to use that reviewer again, choose **Yes, and don't ask again** to save
that consent in your own instructions. See [review consent details](reference/reviewer-setup.md#give-consent-once).

<details open>
<summary>Consent template</summary>

```text
Shaka review consent: local reviews of OWNER/REPO may send the committed diff,
its head commit with its files and checkout path, the review instructions and criteria, the
repository's review prompt, the PR description, and earlier review findings to
Anthropic (Claude CLI) and OpenAI (Codex CLI).
Never send secrets, credentials, .env files, or private data unrelated to the
change. Approved by NAME on DATE.
```

</details>

### Save a tool approval for future chats

Your coding tool may separately ask to run the reviewer command.
Save a narrow
approval for future chats when you use that command regularly and understand its
scope. A saved rule can let matching commands run without another approval.
Review what it covers before saving it; organization policy still applies.

| Coding tool | Remember an approval |
| --- | --- |
| Codex | In the CLI, accept a narrow command rule when Codex offers one. It saves a user-level prefix rule that can match in other projects and with extra arguments. See [Codex command rules](https://learn.chatgpt.com/docs/agent-configuration/rules). |
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
Help me use Claude for Shaka code reviews in this project. Check that it can run.
```

The agent checks the configured reviewers, the installed tools, and sign-in. It
explains any settings PR or consent you need. See
[Claude reviews from Codex](reference/reviewer-setup.md#set-up-claude-reviews-from-codex)
and [reviewer settings](settings.md#reviewlocal_review_agents).

## Share project instructions across tools

Keep project rules in one place. Ask your agent to check the rules it loads:

```text
Check that this coding agent reads our existing AGENTS.md. Explain how to connect it if needed.
```

See the project instruction guides for
[Codex](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[Claude Code](https://code.claude.com/docs/en/memory#agents-md), and
[Cursor](https://cursor.com/docs/rules). Claude Code can import `AGENTS.md`
from `CLAUDE.md` if it does not load the existing file directly.

<a id="codex-desktop-follow-up"></a>

For PR follow-up in Codex desktop, see
[Resume unfinished work](working-with-shaka.md#resume-unfinished-work).
