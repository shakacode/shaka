# Coding agents

Install Shaka once and use it across your repositories. Your coding agent
supplies the model, permissions, and tools.

| Coding agent | Start a task |
| --- | --- |
| Codex desktop or CLI | `$shaka` |
| Claude Code desktop or CLI | `/shaka` |
| Cursor | `/shaka` in a new Agent chat |
| OpenCode | `/shaka` |
| Pi | Load the installed Shaka skill |

Use the [installation prompt](getting-started.md), or
[install manually](manual-installation.md). On macOS, you can also
[open a Linear issue in Codex CLI](linear.md).
Optional [control towers](control-towers.md) need their host's desktop session tools.

## Cloud agents

A cloud agent needs access to a reviewer before it can complete local review.
Your local sign-ins and environment variables do not reach its machine.
The optional [DeepSeek reviewer](settings.md#reviewlocal_review_agents) needs
outbound HTTPS and an `OPENROUTER_API_KEY` secret there. It uses Shaka's Ruby
adapter and does not change the coding agent's model. Try a review before relying
on that environment.

Claude Code on the web can block GitHub's GraphQL API. Doctor reports that
failure; Shaka's GitHub PR commands cannot complete without it.
If access or review is blocked, continue in a local chat with the PR URL:

```text
/shaka https://github.com/OWNER/REPO/pull/123
```

Use `$shaka` in Codex. See [recovery](expected-experience.md#resume-or-change-your-checkout).

## Give consent once

Before sending your change to another provider for review, Shaka asks for
consent. Choose **Yes, and don't ask again** to save the displayed statement in
your own instructions file. If the agent cannot write it, it gives you the text
to add. Existing consent is reused within its stated scope.

You can also consent for one task in chat or put a statement in your user-level
instructions. For Claude Code, use `~/.claude/CLAUDE.md`. For Codex, use
`~/.codex/AGENTS.md`, or `AGENTS.override.md` if present. Custom
`CLAUDE_CONFIG_DIR` or `CODEX_HOME` locations apply.

Adapt this example to the providers, repository, and content you authorize:

```text
Shaka review consent: local reviews of OWNER/REPO may send the committed diff,
its head commit with its files and checkout path, review instructions and
criteria, the repository's review prompt, the PR description, and earlier review
findings to Anthropic (Claude CLI) and OpenAI (Codex CLI).
Never send secrets, credentials, .env files, or unrelated private data.
Approved by NAME on DATE.
```

Use `OWNER/*` to cover that owner's repositories. Name OpenRouter too if you use
the DeepSeek reviewer, because the request passes through it. A new provider,
repository, or broader payload needs consent that covers it. A different Claude
model or effort does not.

Shaka does not ask separately for a reviewer using your coding agent's own
provider through the same account and route. Before implementation, the
[startup check](settings.md#reviewstartup_check) sends reviewers a tiny prompt
without code; it may consume quota.

Consent instructs the agent; it does not restrict what the reviewer can read.
Claude receives a copy of committed files without untracked files. Codex may
read other files its sandbox allows. Keep credentials out of the checkout.
The agent inspects the diff before review, but no scanner guarantees it finds
every secret. Replace a credential if it was pushed or sent to a reviewer.

## Approve private-code reviews in Codex

Codex's [Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review) and
your organization's managed policy can deny a review command even when you
consented. Your consent provides context; it does not override those controls.

### When Codex denies the review

In Codex CLI, use `/approve` and select the denied `shaka review run` command
for one retry. Auto-review checks the retry and can still deny it.
Shaka has not verified an equivalent in Codex desktop. **Approve for me** selects
Auto-review for the chat; it does not approve one denied command.

The agent reports a denied review as not run. Ask it to identify the denied
action and the stated reason. Repeating consent or changing reviewers does not
resolve a host-policy denial. A custom Auto-review policy replaces the default
policy; preserve the complete default before editing it. Managed policy wins.

### Set up Claude reviews from Codex

Ask your agent:

```text
Configure Claude as a local reviewer for this repository.
Check its sign-in and help me record consent for future reviews.
```

For team setup, the agent proposes a [reviewer setting](settings.md#reviewlocal_review_agents)
in a PR; it takes effect after merge. Individual setup keeps the change local. The Claude CLI must be
installed and signed in on the machine running Codex; it does not need
`ANTHROPIC_API_KEY`. Record consent in the user-level file Codex reads, then
start a fresh chat and run `$shaka doctor`. Doctor checks configuration and CLI
availability. When [startup checks](settings.md#reviewstartup_check) are enabled,
the task also probes reviewer access. Otherwise, ask the agent to probe it explicitly.

| Problem | Next action |
| --- | --- |
| Codex reviews instead of Claude | Ask doctor whether Claude is configured and on `PATH`; for team setup, check that the settings PR merged. |
| `Not logged in · Please run /login` | Run `claude`, then `/login`, and retry. |
| Consent is requested again | Check that the statement covers the provider, repository, and content, and is in the instructions Codex reads. |
| A tool needs `ANTHROPIC_API_KEY` | Identify that tool; the Claude CLI reviewer uses its own sign-in. |

Consent does not authorize merging or change the [review round limit](settings.md#reviewlocal_max_rounds).
A denied review does not consume a round.

## Codex desktop follow-up

The handoff names who checks later PR feedback and how to resume the chat.
Automatic follow-up is available only when the host can resume it. Under Ask,
you still decide whether to merge.
