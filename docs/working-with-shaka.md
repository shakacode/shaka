# Working with Shaka

Ask the agent about anything this page leaves out. Code enforces only what
[what is enforced](workflow.md#what-is-enforced) lists. The rest follows Shaka's
instructions.

Use `$shaka` in Codex and `/shaka` in Claude Code, Cursor, or OpenCode
([other agents](coding-agents.md)).

<a id="what-you-get"></a>

For what each PR shows, see [what a PR answers](pr-verification.md#answers-for-your-next-decision).

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

For Auto on one task, add `Use merge policy auto` to your prompt. To make it the
repository default, ask the agent to change the
[merge preference](settings.md#mergepreference). Under Auto, the agent still hands
back large PRs ([size limits](settings.md#mergelimits)) and risky ones, such as
changes to authentication, permissions, releases, deployments, or stored data, or
ones that make users act after merge.

## Give feedback

<a id="on-github-or-in-chat"></a>
<a id="in-your-editor"></a>

Comment on the PR and paste the link into the chat. Or say in chat what's wrong.

To edit files yourself, tell the agent first. Tell it again when you're done.
Don't both write at once.

### Revise earlier guidance and try again

The PR description lists your instructions as [return points](pr-verification.md#return-points)
C1, C2, and so on. To go back to one:

```text
$shaka Return to C2. Use the simpler approach.
```

The agent rewinds with Git and task records, not snapshots, so work that was never
committed or saved may not come back. Ask what it can restore first. It can't undo
deployments.

## Find PRs waiting on you

<a id="squash-with-a-useful-commit-message"></a>

Search your PR list on GitHub:

| Search | What to do |
| --- | --- |
| `is:open label:awaiting-answer` | Answer **Decisions to make** in the description. |
| `is:open label:awaiting-merge-approval` | Merge with the prepared [commit message](pr-verification.md#squash-merge-details). Or add the PR to your [merge queue](pr-verification.md#merge-queues), or tell the agent to merge that commit. |
| `is:open label:awaiting-resume` | Open **WIP Details → Chat link** and paste **Next action** there. |

A label doesn't wake a chat. See [approval details](pr-verification.md#approval-and-attention-labels).

## Resume unfinished work

When work on a GitHub issue starts, the agent comments on the issue with the same
fields as **WIP Details**, so people watching it see who took it and how to resume.
The branch isn't pushed yet, so **Owner** names the machine that holds it.

Comment on any open PR. Wait for an answer before merging.

A comment wakes the agent only while automatic follow-up is on. The handoff says
whether it is, and **WIP Details** shows when it expires. Until then, don't archive
the owning chat.

After that, or after a crash, make sure the previous agent has stopped. Then paste
**WIP Details → Next action** into a chat, such as
`$shaka https://github.com/OWNER/REPO/pull/N`. See
[recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Choose the outcome you need

Say where to stop.

### Get a plan before implementing

```text
$shaka Plan CSV export for the orders page. Planning only.
```

<a id="keep-a-plan-across-chats"></a>

For work that needs several PRs, the agent keeps the plan in the issue. It asks
first if it needs permission. Once the previous agent stops, a new chat continues
from the same link.

### Agree on a design before implementing

When a task leaves design choices open, Shaka offers to agree on the design first.
It writes the design in the issue. If your repository keeps architecture decision
records (ADRs), it opens a design PR instead. It writes no code until you approve.

To ask up front:

```text
$shaka https://github.com/OWNER/REPO/issues/N
Agree on the design first. Wait for my approval before implementing.
```

Add `Use a design PR.` to get one in any repository. Approve the design in chat.
For a design PR, you can also name a teammate whose approving review counts.

### Review an existing PR

```text
$shaka Review https://github.com/OWNER/REPO/pull/N. Review only.
```

### Review documentation together

```text
$shaka Review docs with me: https://github.com/OWNER/REPO/pull/N
```

The agent explains one topic at a time. Say `continue` for the next. It changes
nothing, and ends with the wording you agreed on, ready to apply as a task.

### Resume a PR you already started

Confirm the handoff first. Then:

```text
$shaka Resume https://github.com/OWNER/REPO/pull/N. The previous owner has
stopped and handed this work to me. Keep merge policy ask. Go.
```

The new chat comments on the PR that it took over, so the previous chat and
reviewers see the handoff.

<a id="configure-a-repository-for-your-team"></a>

### Split a large change

Ask for separate PRs, such as "Update React first, then the code that needs it."

## Useful tips

- **Pick a model.** Switch to it in your coding agent, then name it:
  `Use Sol, medium effort. Go.` A prompt can't switch models.
- **Hide your checkout path.** Public PRs show it in WIP Details. To hide it, ask
  the agent to turn off [`wip.include_checkout_path`](settings.md#wipinclude_checkout_path).
  The chat link stays.
- **Name your machines.** If you work on more than one, set `SHAKA_MACHINE_ALIAS`
  to a short public name, such as `mini`. WIP Details then shows which machine
  holds the chat. `$shaka doctor` suggests a name.

## Combine Shaka with other skills

Name another skill in your prompt. Shaka still runs your checks and review, writes
the PR, and keeps your merge policy. Its instructions don't let another skill skip
a check or approve a merge.

Your check scripts run from the PR branch. Review changes to them like other code.

<a id="hand-over-a-spec-and-tickets"></a>
<a id="what-each-kind-of-skill-can-do"></a>

[AI Hero's skills](https://www.aihero.dev/skills-changelog-v13-implement-spec-pr-retro-and-glossary-md)
turn an idea into a spec and tickets:

```text
$shaka Deliver the spec in https://github.com/OWNER/REPO/issues/N. Go.
```

Tickets stay open unless you add "Close each ticket when its PR merges."

<a id="use-a-technique-skill-during-delivery"></a>
<a id="use-pstack-for-a-bounded-part-of-delivery"></a>

[pstack](https://github.com/cursor/plugins/tree/main/pstack) can build a harness
that drives your app the way a user does, to prove what tests alone can't:

```text
$shaka Fix https://github.com/OWNER/REPO/issues/N. Use pstack's
create-verification-skill to prove searching for O'Brien finds the order. Go.
```

Shaka uses pstack's techniques inside its own steps. pstack's Shipping, Babysit,
and Autopilot playbooks run their own delivery, so Shaka leaves them out and
offers to try one separately. On Codex, install a community port of pstack.

<a id="hand-verification-evidence-back-to-shaka"></a>

The PR's verification lists the harness command, the commit it ran on, what it
showed, its screenshots or logs, and what it didn't cover. After a later commit,
the agent reruns any check that commit affects.

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
It records which helper commands ran, how long they took, and whether they passed,
with IDs such as the repository, PR, and commit. It never records paths or task
text, and Shaka doesn't upload it. Each PR's description shows that PR's own
[timings](reference/timings.md). To stop recording, set `SHAKA_CALL_LOG=off`. To
move the log, set it to a path.

## Suggest improvements to Shaka

Tell your agent what Shaka should do better. It asks before filing an issue.
