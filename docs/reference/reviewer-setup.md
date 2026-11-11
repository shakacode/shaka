# Local review setup

Use this reference when you need details beyond [Coding agents](../coding-agents.md).

## Give consent once

When Shaka's local review would send your change to a provider other than your
coding agent's, Shaka asks before the first review of a task. Answer **Yes, and don't ask again** and
Shaka saves a consent statement to your own instructions file, then reuses it
on later tasks without asking. The question shows the exact statement and file
before you choose. If your agent can't write the file, it gives you the text to
add yourself.

You can also write the statement yourself: in the chat for one task, or in your
user-level instructions for every task, `~/.claude/CLAUDE.md` for Claude Code
and `~/.codex/AGENTS.md` for Codex (`AGENTS.override.md` there if you have one),
or the same file under `CLAUDE_CONFIG_DIR` or `CODEX_HOME` when you set one.
Adjust the providers, repository, and exclusions. Write `OWNER/*` in place of
`OWNER/REPO` to cover every repository that owner has. For the DeepSeek
reviewer, name OpenRouter too, because the request passes through it.

Copy the [consent template](../coding-agents.md#give-consent-once) and adjust it for your repository and reviewers.

The exclusions are your instruction to the agent, not a limit on the reviewer.
A reviewer given the checkout path can read other files its own sandbox allows,
so keep secrets out of the checkout. The Claude reviewer reads a copy of the
reviewed commit's files instead, so it never sees untracked files such as `.env`;
the Codex reviewer can.

Shaka tells the agent to read each diff for real credentials before review and to
report any it finds in chat. No scanner backs that instruction, so an unusual key
can slip through. Give your agent its own limited keys rather than admin ones. If
a key is pushed or sent to a reviewer, replace it with a new one, because deleting
it from the file leaves it in Git history and with whoever received it.

Before implementation, Shaka checks for covering consent and asks only when it
is missing. It doesn't ask about the reviewer from your coding agent's own
provider, such as the Codex reviewer in Codex or the Claude reviewer in Claude
Code, when that reviewer uses the same account and route: your agent already
sends that provider the review packet. It then runs a tiny reviewer access check,
enabled by
[`review.startup_check`](../settings.md#reviewstartup_check). Standing consent is
reused without another question. In Codex, tool approval is separate.

## Approve private-code reviews in Codex

Shaka's local review sends your change to the reviewer you configured, such as
Claude or Codex, using your own credentials. When Codex runs with
[Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review), a separate
reviewer agent evaluates eligible approval requests. Commands already allowed by
your tool rules proceed without another review. Auto-review can deny an
eligible request to send private code to another provider.

Three separate permissions apply:

- **The task.** Asking Shaka to deliver a task includes its local review.
- **Your consent.** You agree that named providers may receive this
  repository's code for review, as [Give consent once](#give-consent-once)
  describes.
- **Codex's decision.** Your sandbox, command rules, and organization policy
  determine which actions need approval. Consent to share code does not grant
  tool permission.

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
   [`review.local_review_agents`](../settings.md#reviewlocal_review_agents):

   ```yaml
   review:
     local_review_agents:
       - provider: anthropic
         model_family: claude
   ```

   Merge the change for tasks that use shared default-branch settings. To try it
   first, [select the settings PR](../settings.md#preview-settings-before-adopting-them).
   In a repository without shared settings, you can choose Claude during
   [individual setup](../settings.md#which-settings-apply).
2. **Sign in to Claude Code.** Install the `claude` CLI on the machine that runs
   Codex, run `claude`, and sign in with `/login`. The review uses that sign-in.
   It does not need `ANTHROPIC_API_KEY`.
3. **Record your consent.** Add the [consent statement](#give-consent-once),
   naming Anthropic (Claude CLI) and this repository, to `~/.codex/AGENTS.md`,
   or `$CODEX_HOME/AGENTS.md` if you set `CODEX_HOME`. That file belongs to
   you, not to any checkout, so a branch cannot change it. If an
   `AGENTS.override.md` sits beside it, Codex reads the override file and
   ignores the original. In that case, put the statement in the override file.
4. **Check the setup.** Start a fresh Codex chat in a checkout of the
   up-to-date default branch and ask:

   ```text
   $shaka doctor
   ```

   Doctor reads the settings in that checkout and shows whether the `claude` CLI
   is on your `PATH`. Claude is `configured` when the settings list it for
   routine review. If Doctor says `optional: runs only when a task names it`,
   the settings list Claude but [provider coverage](../settings.md#reviewprovider_coverage)
   excludes Anthropic. Check sign-in separately.
   On your next task, Shaka quotes your statement instead of asking. It then
   sends Claude a tiny access check that contains no code but may use quota.

Write a new statement before reviews send more than the old one covers. That
includes a new provider or relay service such as OpenRouter, a repository the
statement does not name, or more content than it lists. Changing the Claude
model or effort needs no new statement.

Consent does not let Shaka merge. With [Ask](../settings.md#mergepreference), the PR
still waits for you. The [review round limit](../settings.md#reviewlocal_max_rounds)
also stays in force.

| What you see | What it means | What to do |
| --- | --- | --- |
| A Codex reviewer runs instead of Claude | The settings omit Claude, provider coverage excludes Anthropic, or the `claude` CLI is missing | Run the step 4 check. If the settings omit Claude, follow step 1. If coverage excludes Anthropic, name Claude for this task or update coverage. If `claude` is missing, follow step 2 |
| `Not logged in · Please run /login` | The `claude` CLI is not signed in | Run `claude`, then `/login`, and retry the task. This is not a consent problem |
| Shaka asks for consent again | Your statement from step 3 does not name this provider, repository, and content, or Codex does not read the file that holds it | Fix the statement or move it to the file Codex reads, or answer the question for this task |
| Codex Auto-review denies `shaka review run` | Codex blocked the command before it started, so nothing reached Claude | Follow [When Codex denies the review](#when-codex-denies-the-review). Do not answer the consent question again or switch reviewers |
| A missing `ANTHROPIC_API_KEY` | Another tool, such as a repository script, needs an Anthropic API key. The Claude reviewer does not | Set the key for that tool. Without it, the agent reports that check as failed rather than skipping it |

Shaka cannot get around your organization's managed Codex policy. A denied
review does not count as one of its rounds.

## Cloud reviewers

Local review requires a reviewer the cloud environment can run. If none is
available, resume the PR in a local session. Cloud machines may lack the
local reviewer CLI, its sign-in, or Ruby 3.4. If GitHub GraphQL is blocked, Doctor and PR status can fall back to REST.
A review decision, merge queue state, or issue link in GitHub's Development
sidebar may be unknown. Other PR actions still need GraphQL.

The opt-in [DeepSeek reviewer](../settings.md#reviewlocal_review_agents) runs through
Shaka's Ruby OpenRouter API adapter. It does not require native DeepSeek support in
Codex, Claude Code or Cursor, and does not change the coding host's model.
To use it, add DeepSeek to the repository's reviewer list and set
`OPENROUTER_API_KEY` as a secret in the cloud environment running Shaka. It needs
Ruby and outbound HTTPS.

Try one review in the target environment before relying on it. A
[recorded Claude Code web trial](https://github.com/shakacode/shaka/issues/277#issuecomment-6541487155)
describes API, runtime and reviewer limits for that session.
