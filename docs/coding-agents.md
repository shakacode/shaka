# Coding agents

Your coding agent supplies the model, permissions, and tools. Install Shaka once
and use it across your repositories.

| Coding agent | Start a task | Notes |
| --- | --- | --- |
| Codex | `$shaka` | Desktop app or CLI; the optional RCT skill needs desktop task tools |
| Claude Code | `/shaka` | Desktop app or CLI; Claude tower skills need desktop session tools |
| Cursor | `/shaka` | Start a new Agent chat after installation |
| OpenCode | `/shaka` | Use the installed skill in a session; an optional launcher is also available |
| Pi | Load the installed Shaka skill | Uses Pi's existing permissions; no separate Shaka launcher |

Use the [installation prompt](getting-started.md); your agent selects the
installation steps for its environment. To run them yourself, follow
[manual installation](manual-installation.md).

On macOS, [start a task from Linear](linear.md) with an optional adapter that
opens Codex CLI with the selected issue and repository.

The opt-in [DeepSeek reviewer](settings.md#reviewlocal_review_agents) runs through
Shaka's Ruby OpenRouter API adapter. It does not require native DeepSeek support in
Codex, Claude Code or Cursor, and does not change the coding host's model.
It needs Ruby, outbound HTTPS and `OPENROUTER_API_KEY` in the process that
runs Shaka.

To support another coding agent, [contribute](../CONTRIBUTING.md) installation
instructions, a demonstrated task, and known limitations. Keep environment-specific
code separate from the shared workflow.

## Cloud agents

A cloud agent, such as a Cursor cloud agent, can implement a task and open its
pull request. It runs no local adversarial review unless its environment provides a
reviewer. A cloud machine usually has no signed-in reviewer tools, and it can't
open the fresh chat Shaka otherwise uses as a fallback reviewer.

The DeepSeek reviewer is the one option that needs only outbound HTTPS. Add it to
your reviewer list and give the cloud agent an `OPENROUTER_API_KEY` secret; your
local environment variables don't reach a cloud machine. Try one review there
before relying on it, since Shaka's tests don't run in your cloud environment.

Without a reviewer, Shaka's review command reports after one attempt that no
reviewer can start, and the agent stops the review. Finish it from a local
session (use `$shaka` in Codex):

```text
/shaka https://github.com/OWNER/REPO/pull/123
```

## Approve private-code reviews in Codex

Shaka's local review sends your change to the reviewer you configured, such as
Claude or Codex, using your own credentials. When Codex runs with
[Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review), a separate
reviewer agent checks that command first. It can deny sending private code to
another provider.

Three separate permissions apply:

- **The task.** Asking Shaka to deliver a task includes its local review.
- **Your consent.** You agree that named providers may receive this
  repository's code for review.
- **Codex's decision.** Auto-review, or your organization's managed policy,
  still decides each command. Your consent gives it context; it does not make
  Codex run the command.

### Give consent once

Write a consent statement in the chat for one task, or in your own `AGENTS.md`
for recurring reviews. Adjust the providers, repository, and exclusions:

```text
Shaka review consent: local reviews of OWNER/REPO may send the committed diff,
its head commit and checkout path, the review instructions and criteria, the
repository's review prompt, the PR description, and earlier review findings to
Anthropic (Claude CLI) and OpenAI (Codex CLI).
Never send secrets, credentials, .env files, or private data unrelated to the
change. Approved by NAME on DATE.
```

The exclusions are your instruction to the agent. Shaka adds only the listed
items to the request. A reviewer given the checkout path can still read other
files its own sandbox allows, so keep secrets out of the checkout.

When the agent knows Auto-review checks its commands, it quotes the statement
that covers the review before starting it. It also quotes it before retrying a
denied review. OpenAI documents that Auto-review reads your messages and the
agent's visible updates, so the quote reaches it. If no statement covers the
review, the agent asks you first. It names the provider,
the repository, and what it would send.

A custom Auto-review policy, set with `[auto_review].policy` in Codex's
`config.toml`, replaces the default policy instead of adding to it. Copy the
full default policy before you edit it. Your organization's managed policy
takes precedence over yours.

### When Codex denies the review

In the Codex CLI, run `/approve` and choose the denied `shaka review run`
command. OpenAI documents that this approves that one action for one retry.
Auto-review checks the retry again and can still deny it.

Shaka has not verified an equivalent in the Codex desktop app. Its
**Approve for me** control selects Auto-review for the chat; it does not
approve one denied action. When the review stays denied, the agent records it
as not run, and the PR says so.

## Codex desktop follow-up

Shaka tells you who will handle later PR feedback. If automatic follow-up
is unavailable, the handoff names someone to check feedback and gives them
a prompt to resume the chat. Ask merging still waits for your decision.
