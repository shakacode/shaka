# Working with Shaka

Read this page after your first task. Each section answers one question, in the
order you are likely to have it.

Examples use Codex's `$shaka`. Use `/shaka` in Claude Code, Cursor, or OpenCode;
in Pi, load the installed skill.

## What you get

A PR built to help you decide:

- **Description**: the outcome, the decisions left for you, and how the change
  was checked. Anything unproven appears as a gap.
- **Code walkthrough**: each implementation choice and the alternatives, with
  links to the reviewed lines.
- **Evidence**: tests, review findings, and screenshots for visible changes.
- **Collapsed sections**: usage, detailed checks, and **WIP Details** for
  unfinished work. Open them only when you need them.

See [where each answer lives](pr-verification.md#read-a-pr-for-your-decision) and
[what to expect](expected-experience.md) when access or checks are missing.

## Give it an outcome

Describe the result or link an issue. Add only what the agent could not infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
Go.
```

`Go` starts with your agent's current model and effort. Shaka recommends both,
but does not wait for you to match them.

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | Review the ready PR, then merge it on GitHub or approve it so the agent merges. |
| **Auto** | The agent merges after required checks, review, and approvals. |

![A ready PR follows Ask, where you merge or approve it, or Auto, where the agent merges. A PR that is too large or risky returns to you under Auto.](img/merge-policy.svg)

Say `Use merge policy auto` in your prompt to let the agent merge. Under Auto,
these still come back to you:

- a PR past the [size limits](settings.md#mergelimits);
- trust, authentication, release, and other consequential changes;
- anything your repository's rules or required approvals block.

Merging does not publish a package or deploy a release.

## Give feedback

### On GitHub or in chat

Leave PR comments and paste the review link into the chat, or describe in chat
what feels wrong.

### In your editor

Put rough notes beside the passage that needs attention; an optional `Agent:`
prefix marks them as notes.

1. Tell the agent you are editing and to keep the checkout read-only.
2. Leave your notes unstaged.
3. Hand the files over when you stop.
4. The agent backs up your notes outside the repository, applies them, and
   validates before pushing.
5. Resume editing when it hands the checkout back.

Take turns: do not write to the same checkout at the same time.

### Revise earlier guidance and try again

Shaka records your first request as checkpoint C1 on the PR, and your later
steering or review as C2, C3, and so on. See [checkpoints](pr-verification.md#checkpoint).
To go back:

```text
$shaka Return to C2. Use the simpler approach.
```

The agent keeps the rejected attempt and restores the work from that point. It
cannot undo deployments or other outside effects. Recovery uses Git and task
records rather than saved snapshots, so ask what it can restore before rewinding.
See [recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Find PRs waiting on you

Search your repository's PR list on GitHub:

| Search | What to do |
| --- | --- |
| `is:open label:awaiting-answer` | Answer **Decisions to make** in the description. |
| `is:open label:awaiting-merge-approval` | Merge with GitHub's offered control, or tell the agent to merge that commit. |
| `is:open label:awaiting-resume` | Paste **WIP Details → Next action** into the owning chat. |

Answer in the chat unless the handoff says automatic follow-up is active. A
label does not wake a chat or prove checks passed.

If the agent posts with your GitHub account, a review you started but never
submitted blocks its walkthrough. Submit or discard it. Until you do, the PR shows
`awaiting-answer`, unless it was already waiting for merge.

If a label looks stale, resume the owning chat from **WIP Details → Chat link**.
Removing a label by hand does not restart work or authorize merging. See
[approval details](pr-verification.md#approval-and-attention-labels).

## Resume unfinished work

You can comment on any open PR, even one awaiting merge. Wait for the agent to
answer before merging.

The handoff says whether **automatic follow-up** is active. When it is, the agent
watches the PR and responds to new comments; keep its chat unarchived. When the
handoff says **Automatic feedback intake unavailable**, a comment alone does not
wake the agent. The person it names opens **WIP Details → Chat link** and sends the
resume prompt, for example `$shaka https://github.com/OWNER/REPO/pull/N`.

After a crash or in a new chat, paste **WIP Details → Next action**. The agent
checks the live PR before continuing. Without a PR, give it the original task and
checkout. Before another agent takes over, confirm the previous one has stopped.
See [recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Choose the outcome you need

State the stopping point in your prompt.

### Get a plan before implementing

```text
$shaka Plan CSV export for the orders page. Compare a simple download with
a background export. Planning only.
```

The agent returns the scope, tradeoffs, and a prompt you can use to start delivery.

### Keep a plan across chats

For work that needs several PRs, Shaka saves the plan in the original issue,
asking first if it needs permission to write there. To continue in a new chat,
give it the same task link after the previous agent has stopped.

### Review an existing PR

```text
$shaka Review https://github.com/OWNER/REPO/pull/N. Review only.
```

The agent reports findings and verification gaps, then stops without editing.

### Review documentation together

```text
$shaka Review docs with me: https://github.com/OWNER/REPO/pull/N
```

Give a PR or a documentation path. The agent explains one topic at a time and
pauses; say `continue` for the next. It flags where the docs and code disagree,
and ends with the wording you agreed on. It does not edit or comment unless you
ask. This is agent guidance, not enforced by code.

### Resume a PR you already started

```text
$shaka Resume https://github.com/OWNER/REPO/pull/N. The previous owner has
stopped and handed this work to me. Keep merge policy ask. Go.
```

Confirm the handoff first. The agent reads **WIP Details**, checks the PR's
current state, and finishes the work. Under Ask, it returns the PR for your merge
decision or explains what still blocks it.

### Configure a repository for your team

```text
$shaka Set up Shaka for this repository.
```

The agent opens a setup PR for you to merge on GitHub, then stops. See
[repository setup](configure-repository.md#set-up), or
[individual setup](expected-experience.md#individual-setup) to try Shaka without
team settings.

### Split a large change

Ask for independently useful changes as separate PRs. For example, merge a
React 19 update first, then the integration that needs it. Each PR gets its own
tests and review, and the original chat keeps the remaining branch current.

## Useful tips

- **Start small.** Pick a fix whose result you can recognize.
- **Choose a model when you need to.** Activate it in your coding agent, then
  name it, for example `Use Sol, medium effort. Go.` A prompt cannot switch the
  model, and a setting that differs from Shaka's recommendation can cause a pause.
- **Keep public PRs public-safe.** Tell the agent before publishing if local
  paths or chat links should be hidden. [WIP settings](settings.md#wipinclude_checkout_path)
  hide the checkout path.

## Squash with a useful commit message

When you squash-merge on GitHub, copy the agent's prepared message; see
[squash merge details](pr-verification.md#squash-merge-details). With a merge
queue, add the PR to the queue instead; see [merge queues](pr-verification.md#merge-queues).

## Combine Shaka with other skills

Use other skills for planning and technique, and let Shaka deliver the result.
Examples:

- [AI Hero's skills](https://www.aihero.dev/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md)
  turn an idea into a spec and tickets.
- [pstack](https://github.com/cursor/plugins/tree/main/pstack) adds engineering
  principles and parallel workers.
- [Ponytail](https://github.com/DietrichGebert/ponytail) keeps each change as
  small as it can be.
- [Addy Osmani's agent skills](https://github.com/addyosmani/agent-skills) cover
  practices from spec to launch.

pstack, Ponytail, and Addy Osmani's skills have not been tried on a full Shaka
delivery. [Try a new pack](#try-a-new-skill-pack-with-shaka) on one task first.

### Hand over a spec and tickets

```text
$shaka Deliver the spec in https://github.com/OWNER/REPO/issues/N. Go.
```

The agent orders the sub-issues by their blocked-by links and delivers each PR
the usual way. Under Ask, each PR comes back to you, and dependent PRs wait.
Tickets stay open: the agent links them without `Fixes`, because reading a
tracker gives no permission to change it.

Add a sentence to change that:

- "You may comment on the spec with your plan" skips the question about where
  to keep a multi-PR plan.
- "Close each ticket when its PR merges" lets merges close them.

On a public repository, the agent checks with you before adopting criteria from
a ticket written or edited by someone without write access.

### Use a technique skill during delivery

```text
$shaka Fix https://github.com/OWNER/REPO/issues/N in poteto mode. You may use
subagents for swarm and arena. Go.
```

The agent follows pstack while it implements. Shaka still runs your checks, gets
an independent review, writes the PR, and keeps your merge policy. Without the
subagent sentence, the agent does the fan-out steps alone or asks first. The
[community pstack port](https://github.com/michael-denyer/pstack-claude) turns
poteto mode on by itself for any multi-file task.

### Try a new skill pack with Shaka

Use a task you would merge anyway:

```text
$shaka Fix https://github.com/OWNER/REPO/issues/N using SKILL. Go.
```

When the PR is ready, ask:

```text
Which SKILL instructions did you follow, and where did they conflict with Shaka?
```

Then check:

1. **Does it turn itself on?** Ponytail and the pstack port load in every
   session, even when you do not name them.
2. **Does it change delivery?** A pack that skips checks, merges, closes tickets,
   or replaces the PR description is its own workflow. Keep it out of Shaka tasks.
3. **Does it leave marks reviewers will flag?** Look for comment markers or rule
   files it adds.
4. **Do its reports clash?** Compare its closing summary with the PR description.

Shaka's Claude and Codex reviewers start without your plugins, skills, and hooks.
The Grok reviewer has not been checked.

### What each kind of skill can do

Another skill's output is input to the task. It cannot relax a check, pick a
reviewer, or approve a merge.

| Kind of skill | Examples | With Shaka |
| --- | --- | --- |
| Planning | AI Hero `to-spec`, `to-tickets` | Its spec and tickets become the task. |
| Technique or mode | pstack `poteto-mode`, principles, `how`, `tdd` | Shapes how the agent works inside each step. |
| Parallel workers | pstack `swarm`, `arena`, `interrogate` | Runs only when you allow delegation. Workers never publish or merge. |
| Same-session review | AI Hero `code-review`, pstack `blast-radius` | Findings the agent fixes before Shaka's own review, which still runs in a separate session. |
| PR text | AI Hero `pr`, pstack `technical-writing`, `unslop` | Wording advice. The description keeps Shaka's format. |
| Its own delivery | AI Hero `implement-spec`, pstack Shipping, Babysit, Orchestrate, and Autopilot playbooks | A separate orchestrator that cannot run inside Shaka. Try it as its own experiment. |

Shaka takes its settings, such as reviewers and merge rules, from your default
branch. Rule files and check scripts a skill changes on the branch are part of
the change under review. If a skill you named is not installed, the agent says
so, continues the work that does not need it, and asks about the rest. It does
not install software for you. This is agent guidance, not enforced by code.

## Review a session for improvements

At the end of a rough session, ask in the same chat:

```text
$shaka retrospective
```

The agent lists findings with evidence, a proposed fix, and its maintenance cost,
then waits. Pick some, for example `Deliver findings 1 and 3`, and each is
delivered as an ordinary task.

To find slow steps, the agent reads a timing log Shaka keeps on your machine at
`~/.local/state/shaka/calls.jsonl`. It records each helper command's name,
timing, and exit status, plus the repository, issue or PR, and commit when the
command names them. It holds no
paths or task text and is never uploaded. Set `SHAKA_CALL_LOG=off` to stop it,
or set it to a path to keep the log elsewhere.

## Suggest improvements to Shaka

Tell your agent in chat what Shaka should do better, for example “Shaka asks too
many setup questions.” It helps refine the idea and asks before filing an issue.
