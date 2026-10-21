# Working with Shaka

Read this page after your first task. It covers the choices only you can make and
the prompts for other kinds of work. For everything else, ask the agent.

Examples use Codex's `$shaka`. Use `/shaka` in Claude Code, Cursor, or OpenCode;
in Pi, load the installed skill.

## What you get

A PR built to help you decide:

- **Description**: the outcome, the decisions left for you, how the change was
  checked, and what went unproven.
- **Code walkthrough**: each implementation choice and the alternatives, with
  links to the reviewed lines.
- **Evidence**: tests, review findings, and screenshots for visible changes.
- **Collapsed sections**: detail you can skip, such as usage and **WIP Details**.

See [where each answer lives](pr-verification.md#read-a-pr-for-your-decision).

## Give it an outcome

Describe the result or link an issue. Add only what the agent could not infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
Go.
```

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | Review the ready PR, then merge it on GitHub or approve it so the agent merges. |
| **Auto** | The agent merges after required checks, review, and approvals. |

![A ready PR follows Ask, where you merge or approve it, or Auto, where the agent merges. A PR that is too large or risky returns to you under Auto.](img/merge-policy.svg)

Say `Use merge policy auto` in your prompt to let the agent merge. Large or
consequential changes still come back to you; see [size limits](settings.md#mergelimits).

## Give feedback

Leave PR comments and paste the review link into the chat, or say in chat what
feels wrong.

To edit files yourself, tell the agent first so it keeps the checkout read-only,
and hand the files back when you stop. Take turns; do not both write at once.

### Revise earlier guidance and try again

Shaka numbers your instructions on the PR as checkpoints: C1 is your first
request. To go back to one:

```text
$shaka Return to C2. Use the simpler approach.
```

The agent rewinds from Git and task records, not saved snapshots, so ask what it
can restore first. It does not undo deployments or other outside effects. See [checkpoints](pr-verification.md#checkpoint).

## Find PRs waiting on you

Search your repository's PR list on GitHub:

| Search | What to do |
| --- | --- |
| `is:open label:awaiting-answer` | Answer **Decisions to make** in the description. |
| `is:open label:awaiting-merge-approval` | Merge on GitHub with the [commit message](pr-verification.md#squash-merge-details) the checkpoint comment gives, or tell the agent to merge that commit. |
| `is:open label:awaiting-resume` | Paste **WIP Details → Next action** into the owning chat. |

A label does not wake a chat. Answer in the chat unless the handoff says automatic
follow-up is active. See [approval details](pr-verification.md#approval-and-attention-labels).

## Resume unfinished work

You can comment on any open PR; wait for the agent to answer before merging. A
comment wakes the agent only while the handoff says automatic follow-up is active.
Otherwise, or after a crash or in a new chat, paste **WIP Details → Next action**,
for example `$shaka https://github.com/OWNER/REPO/pull/N`. Before another agent
takes over, confirm the previous one has stopped. See
[recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Choose the outcome you need

State the stopping point in your prompt.

### Get a plan before implementing

```text
$shaka Plan CSV export for the orders page. Planning only.
```

For work that needs several PRs, Shaka keeps the plan in the original issue. Give
a new chat the same task link to continue.

### Review an existing PR

```text
$shaka Review https://github.com/OWNER/REPO/pull/N. Review only.
```

### Review documentation together

```text
$shaka Review docs with me: https://github.com/OWNER/REPO/pull/N
```

The agent explains one topic at a time; say `continue` for the next.

### Resume a PR you already started

```text
$shaka Resume https://github.com/OWNER/REPO/pull/N. The previous owner has
stopped and handed this work to me. Keep merge policy ask. Go.
```

Confirm the handoff first.

### Configure a repository for your team

```text
$shaka Set up Shaka for this repository.
```

Merge the setup PR yourself. See [repository setup](configure-repository.md#set-up),
or [individual setup](expected-experience.md#individual-setup) to try Shaka alone.

### Split a large change

Ask for independently useful changes as separate PRs, for example "Update React
first, then the integration that needs it."

## Useful tips

- **Start small.** Pick a fix whose result you can recognize.
- **Choose a model when you need to.** Activate it in your coding agent, then
  name it, for example `Use Sol, medium effort. Go.` A prompt cannot switch the model.
- **Keep public PRs public-safe.** Tell the agent before publishing if local
  paths or chat links should be hidden.
- **Name your machine.** Set `SHAKA_MACHINE_ALIAS` to a short public name such as
  `mini` so unfinished PRs show which machine holds the work.

## Combine Shaka with other skills

Name another skill in your prompt, and Shaka still delivers the result: your
checks, independent review, its PR format, and your merge policy. Shaka's
instructions tell the agent not to let another skill relax a check or approve a
merge; code does not enforce this.

```text
$shaka Deliver the spec in https://github.com/OWNER/REPO/issues/N. Go.
```

```text
$shaka Fix https://github.com/OWNER/REPO/issues/N in poteto mode. You may use
subagents for swarm and arena. Go.
```

Examples are [AI Hero's skills](https://www.aihero.dev/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md),
[pstack](https://github.com/cursor/plugins/tree/main/pstack),
[Ponytail](https://github.com/DietrichGebert/ponytail), and
[Addy Osmani's agent skills](https://github.com/addyosmani/agent-skills).
pstack, Ponytail, and Addy Osmani's skills have not been tried on a full Shaka
delivery. Try a new pack on one task you would merge anyway, then ask:

```text
Which SKILL instructions did you follow, and where did they conflict with Shaka?
```

## Review a session for improvements

```text
$shaka retrospective
```

The agent lists what would have made the session go better and should change
nothing until you pick findings to deliver. It may read the local timing log Shaka keeps at
`~/.local/state/shaka/calls.jsonl`, which holds no paths or task text and is never
uploaded. Set `SHAKA_CALL_LOG=off` to stop it, or to a path to move it.

## Suggest improvements to Shaka

Tell your agent what Shaka should do better. It helps refine the idea and asks
before filing an issue.
