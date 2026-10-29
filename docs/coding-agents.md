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
for recurring reviews. Adjust the providers, repository, and exclusions. For the
DeepSeek reviewer, name OpenRouter too, because the request passes through it:

```text
Shaka review consent: local reviews of OWNER/REPO may send the committed diff,
its head commit and checkout path, the review instructions and criteria, the
repository's review prompt, the PR description, and earlier review findings to
Anthropic (Claude CLI) and OpenAI (Codex CLI).
Never send secrets, credentials, .env files, or private data unrelated to the
change. Approved by NAME on DATE.
```

The exclusions are your instruction to the agent, not a limit on the reviewer.
A reviewer given the checkout path can read other files its own sandbox allows,
so keep secrets out of the checkout.

Before implementation, Shaka checks for covering consent and asks only when it
is missing. It then runs a tiny reviewer access check, enabled by
[`review.startup_check`](settings.md#reviewstartup_check). Standing consent is
reused without another question. Auto-review still decides each actual command.

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
approve one denied action. When the review stays denied, the agent records on
the PR that the review did not run, unless Codex denies that command too.

### Set up Claude reviews from Codex

Set this up once so that Codex tasks have Claude review the change and do not
ask for consent each time.

1. **Choose Claude as the reviewer.** In the repository's
   `.agents/shaka/config.yml`, list Claude in
   [`review.local_review_agents`](settings.md#reviewlocal_review_agents):

   ```yaml
   review:
     local_review_agents:
       - provider: anthropic
         model_family: claude
   ```

   Shaka reads this file from the default branch, so merge the change before
   relying on it. A change on a task's own branch does not choose its reviewer.
2. **Sign in to Claude Code.** Install the `claude` CLI on the machine that runs
   Codex, run `claude`, and sign in with `/login`. The review uses that sign-in.
   It does not need `ANTHROPIC_API_KEY`.
3. **Record your consent.** Add the [consent statement](#give-consent-once),
   naming Anthropic (Claude CLI) and this repository, to `~/.codex/AGENTS.md`.
   That file belongs to you, not to any checkout, so a branch cannot change it.
   If `~/.codex/AGENTS.md` sits next to an `AGENTS.override.md`, Codex reads the
   override file and ignores the original. In that case, put the statement in
   the override file.
4. **Check the setup.** Start a fresh Codex chat in the repository and ask:

   ```text
   $shaka doctor
   ```

   Doctor marks Claude `configured` once the default branch lists it, and shows
   whether the `claude` CLI is on your `PATH`. It does not check the sign-in. On your next task,
   Shaka quotes your statement instead of asking. It then sends Claude a tiny
   access check that contains no code but may use quota.

Write a new statement before reviews send more than the old one covers. That
includes a new provider or relay service such as OpenRouter, a repository the
statement does not name, or more content than it lists. Changing the Claude
model or effort needs no new statement.

Consent does not let Shaka merge. With [Ask](settings.md#mergepreference), the PR
still waits for you. The [review round limit](settings.md#reviewlocal_max_rounds)
also stays in force.

| What you see | What it means | What to do |
| --- | --- | --- |
| A Codex reviewer runs instead of Claude, and doctor marks Claude optional | The default branch does not list Claude | Merge the setting from step 1 |
| A Codex reviewer runs instead of Claude, and doctor marks Claude configured | The `claude` CLI is missing from your `PATH` or is not signed in | Repeat step 2 |
| `Not logged in · Please run /login` | The `claude` CLI is not signed in | Run `claude`, then `/login`, and retry the task. This is not a consent problem |
| Shaka asks for consent again | No statement Codex reads names this provider, repository, and content. Codex skips `~/.codex/AGENTS.md` when an `AGENTS.override.md` sits beside it | Fix the statement or move it to the file Codex reads, or answer the question for this task |
| Codex Auto-review denies `shaka review run` | Codex blocked the command before it started, so nothing reached Claude | Follow [When Codex denies the review](#when-codex-denies-the-review). Do not answer the consent question again or switch reviewers |
| A missing `ANTHROPIC_API_KEY` | Another tool, such as a repository script, needs an Anthropic API key. The Claude reviewer does not | Set the key for that tool. Without it, the agent reports that check as failed rather than skipping it |

Shaka cannot get around your organization's managed Codex policy. A denied
review does not count as one of its rounds.

## Codex desktop follow-up

Shaka tells you who will handle later PR feedback. If automatic follow-up
is unavailable, the handoff names someone to check feedback and gives them
a prompt to resume the chat. Ask merging still waits for your decision.
