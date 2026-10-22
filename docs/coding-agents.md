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

## Codex desktop follow-up

Shaka tells you who will handle later PR feedback. If automatic follow-up
is unavailable, the handoff names someone to check feedback and gives them
a prompt to resume the chat. Ask merging still waits for your decision.
