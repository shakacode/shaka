# Working with Shaka

Ask the agent about anything this page leaves out. When the agent merges, code
checks required checks, review evidence, and size limits. The rest of the agent
behavior here follows Shaka's instructions
([what is enforced](workflow.md#what-is-enforced)).

Examples use `$shaka` from Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode
([other agents](coding-agents.md)).

## What you get

A PR built for your decision:

- **Description**: the outcome, decisions left for you, how the change was
  checked, and what was not.
- **Code walkthrough**: each choice and its alternatives, linked to the code.
- **Evidence**: tests, review findings, and screenshots of visible changes.
- **Collapsed sections**: detail you can skip.

See [where each answer lives](pr-verification.md#read-a-pr-for-your-decision).

## Give it an outcome

Describe the result or link an issue. Add only what the agent can't infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
Go.
```

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | You merge the ready PR on GitHub, or approve it and the agent merges. |
| **Auto** | The agent merges after required checks, review, and approvals. |

![A ready PR follows Ask, where you merge or approve it, or Auto, where the agent merges. A PR that is too large or risky returns to you under Auto.](img/merge-policy.svg)

For Auto, add `Use merge policy auto` to your prompt. Large PRs still come back to
you ([size limits](settings.md#mergelimits)). The agent also hands back changes to
trust, authentication, or releases.

## Give feedback

<a id="on-github-or-in-chat"></a>
<a id="in-your-editor"></a>

Comment on the PR and paste the link into the chat. Or say in chat what's wrong.

To edit files yourself, tell the agent first. Tell it again when you're done.
Don't both write at once.

### Revise earlier guidance and try again

The PR numbers your instructions as checkpoints, starting with C1. To go back:

```text
$shaka Return to C2. Use the simpler approach.
```

The agent rewinds with Git and task records, not snapshots. This is untested in
real use. Ask what it can restore first. It can't undo deployments.
See [checkpoints](pr-verification.md#checkpoint).

## Find PRs waiting on you

<a id="squash-with-a-useful-commit-message"></a>

Search your PR list on GitHub:

| Search | What to do |
| --- | --- |
| `is:open label:awaiting-answer` | Answer **Decisions to make** in the description. Or submit or discard your own pending review. |
| `is:open label:awaiting-merge-approval` | Merge with the prepared [commit message](pr-verification.md#squash-merge-details). Or add the PR to your [merge queue](pr-verification.md#merge-queues), or tell the agent to merge that commit. |
| `is:open label:awaiting-resume` | Paste **WIP Details → Next action** into a chat. |

A label doesn't wake a chat. See [approval details](pr-verification.md#approval-and-attention-labels).

## Resume unfinished work

Comment on any open PR. Wait for an answer before merging.

A comment wakes the agent only while automatic follow-up is on. The handoff says
whether it is, and **WIP Details** shows when it expires. After that, or after a
crash, paste **WIP Details → Next action** into a chat, such as
`$shaka https://github.com/OWNER/REPO/pull/N`. Make sure the previous agent has
stopped first. See [recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Choose the outcome you need

Say where to stop.

### Get a plan before implementing

```text
$shaka Plan CSV export for the orders page. Planning only.
```

<a id="keep-a-plan-across-chats"></a>

For work that needs several PRs, the agent keeps the plan in the issue. It asks
first if it needs permission. A new chat continues from the same link.

### Review an existing PR

```text
$shaka Review https://github.com/OWNER/REPO/pull/N. Review only.
```

### Review documentation together

```text
$shaka Review docs with me: https://github.com/OWNER/REPO/pull/N
```

The agent explains one topic at a time. Say `continue` for the next.

### Resume a PR you already started

Confirm the handoff first. Then:

```text
$shaka Resume https://github.com/OWNER/REPO/pull/N. The previous owner has
stopped and handed this work to me. Keep merge policy ask. Go.
```

### Configure a repository for your team

```text
$shaka Set up Shaka for this repository.
```

See [repository setup](configure-repository.md#set-up). To try Shaka alone, see
[individual setup](expected-experience.md#individual-setup).

### Split a large change

Ask for separate PRs, such as "Update React first, then the code that needs it."

## Useful tips

- **Start small.** Pick a fix you can check yourself.
- **Pick a model.** Switch to it in your coding agent, then name it:
  `Use Sol, medium effort. Go.` A prompt can't switch models.
- **Keep public PRs public-safe.** If paths or chat links should be hidden, tell
  the agent before it publishes.
- **Name your machine.** Set `SHAKA_MACHINE_ALIAS` to a short public name, such as
  `mini`. Unfinished PRs then show where the work is.

## Combine Shaka with other skills

Name another skill in your prompt. Shaka still runs your checks and review, writes
the PR, and keeps your merge policy. Its instructions don't let another skill skip
a check or approve a merge.

Your check scripts run from the PR branch. Review changes to them like other code.
See the [trust model](workflow.md#trust-model).

<a id="hand-over-a-spec-and-tickets"></a>
<a id="what-each-kind-of-skill-can-do"></a>

[AI Hero's skills](https://www.aihero.dev/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md)
turn an idea into a spec and tickets:

```text
$shaka Deliver the spec in https://github.com/OWNER/REPO/issues/N. Go.
```

Tickets stay open unless you add "Close each ticket when its PR merges."

<a id="use-a-technique-skill-during-delivery"></a>

[pstack](https://github.com/cursor/plugins/tree/main/pstack)'s poteto mode adds
engineering principles and parallel workers:

```text
$shaka Fix https://github.com/OWNER/REPO/issues/N in poteto mode. You may use
subagents for swarm and arena. Go.
```

<a id="try-a-new-skill-pack-with-shaka"></a>

pstack, [Ponytail](https://github.com/DietrichGebert/ponytail), and
[Addy Osmani's agent skills](https://github.com/addyosmani/agent-skills) haven't
been tried on a full Shaka delivery. Try a new pack on a task you'd merge anyway.
Then ask:

```text
Which instructions from that pack did you follow, and where did they conflict with Shaka?
```

## Review a session for improvements

```text
$shaka retrospective
```

The agent lists what would have helped. It waits for you to pick what to fix.

The agent may read Shaka's local timing log, `~/.local/state/shaka/calls.jsonl`.
The log holds no paths or task text and is never uploaded. To stop recording, set
`SHAKA_CALL_LOG=off`. To move the log, set it to a path.

## Suggest improvements to Shaka

Tell your agent what Shaka should do better. It asks before filing an issue.
