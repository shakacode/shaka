# Delivery and communication

This is an operational reference used by the installed Shaka skill in any
repository. Read it when the workflow calls for planning, communication, PR
publication, or resuming unfinished work. Shaka contributor instructions live in
[contributor documentation](../../../contributing/README.md).

Follow the installed Shaka workflow for execution order. Use this reference when
planning a task, splitting PRs, writing delivery updates, or recovering unfinished
work. For the product introduction, see [working with Shaka](../../../docs/working-with-shaka.md).

## When the agent asks questions

Ask before an answer becomes expensive to change. Use existing context and earlier
answers, recommend a path, and continue independent work while a question is pending.
Silence is not approval.

| Situation | Action |
| --- | --- |
| Task or checkout is missing | Ask for the description or repository path. |
| Another PR or owner covers the work | Report it and stop unless the user authorized comparison or takeover. |
| Repository policy is missing | Inspect scripts and CI; ask only for choices the evidence cannot establish. |
| Merge preference is unset | Ask early; default to Ask without an answer. Reuse authority already granted for this scope. |
| Model or effort needs selection | Follow the planning checkpoint below. |
| Routine, reversible implementation choice | Choose and continue; state assumptions that affect the result. |
| Product behavior, scope, or consequential risk is unclear | Explain the consequence, recommend a path, and wait before dependent work. |

For an import fix: “Some rows contain invalid dates. I recommend importing valid
rows and showing the rest for correction. Should an invalid row instead reject
the whole file?” This asks for a product decision while there is still time to
shape the implementation.

## Choose a small execution context

Assess scope and risk, recommend an available model and effort, and explain the
choice. Honor explicit user settings. Consider total planning, implementation,
retries, and review; waiting or a tool error alone does not justify more effort.

Use the workflow's `recommendation` and `checkpoint` commands. Proceed without
another response only when the user explicitly supplied matching model and
effort, clearly asked to start, and those settings are active and usable. Otherwise
pause with one next action. Check the actual host setting on resume when available;
a prompt cannot change the runner. Planning-only work returns its plan and usage
without an implementation checkpoint.

Work solo unless delegation is authorized and useful. Obtain a fresh-context
review before pushing meaningful implementation, using [reviewer selection](review.md#choose-a-local-reviewer).
A different provider is preferred; the implementation model in a fresh session
also qualifies. Missing local review capability is reported explicitly.

Use a new task for a new objective. Keep the existing task while it owns unfinished
work, or transfer ownership with its branch, revision, checks, remaining work, and
authority. Recheck live state on resume. Name tasks by repository, verified issue
or PR, and outcome; preserve user-chosen titles.

### Say what the work is worth

Before recommending settings, write one line naming the user problem and the
cheaper alternative considered: a guide sentence, setting, clearer error, or no
change. The helper renders the line; it does not judge its truth.

When the user named the task, its value is settled. When the agent proposed it or
found it in an unverified report, say so and wait for the user to accept the work.
That decision precedes any request to change model settings. Once accepted, reuse
the decision unless scope or expected cost materially changes.

### Recover an unfinished PR

Keep a collapsed **WIP Details** entry in the PR description until GitHub confirms
the outcome. Publish it through `description` using the `details` list. Refresh at
meaningful progress and every stopping point, with all other description fields
still accurate for the named head. An Ask handoff leaves the note in place with
state “waiting for GitHub merge” and the expected SHA. A failed merge also retains it.

| Field | Content |
| --- | --- |
| Owner | Public machine alias, host, and a random owner tag, such as `m5 · Codex desktop · k7q2` |
| Task | Searchable task title or shareable tracker locator |
| Thread | Raw host session URL, using the rules below; otherwise `UNKNOWN` |
| Last observed activity | Observed time and timezone; otherwise `UNKNOWN` |
| Revision | Branch and current head |
| Workspace | Checkout directory, subject to the privacy setting below |
| Unfinished work | Uncommitted, untracked, deleted, stashed, or unpushed work; `none` only after inspection proves the branch holds everything |
| Stopped because | `running`, `paused`, or `interrupted` |
| Merge authority | Previously established `ask` or `auto`, or `UNKNOWN`; this field grants no authority |
| State | In progress, named check/review wait, blocker, decision, GitHub merge of a named head, or handoff to a named successor |
| Next action | One step that continues the task |

Use safe filenames or counts for unfinished work; use `UNKNOWN` if the previous
checkout has not been inspected or cannot be reached. A fresh clone cannot prove
that another checkout has no unpushed work. An interrupted note may be stale;
its publication time does not prove subsequent activity. Keep private operational
details, tracker links, prompts, credentials, and customer information out of it.

**Session locators:** publish a raw URL, without Markdown or code formatting.
For Codex, require a UUID in `CODEX_THREAD_ID` and use `codex://threads/<thread-id>`.
For Claude Code, require `CLAUDE_CODE_HOST_SESSION_ID`, ask the host for that
session's metadata, and copy its `link` verbatim. The host session ID differs from
`CLAUDE_CODE_SESSION_ID`, which identifies the usage transcript. Terminal sessions,
disabled app links, and other hosts use `UNKNOWN` until a supported locator exists.
A link's availability depends on the owner's machine being reachable.

**Privacy:** the trusted `wip.include_locations` setting defaults to `true`.
When false, publish `UNKNOWN` for both Workspace and Thread. The publishing command
does not read this setting; check the content before submitting it. Retain the fields and
public owner alias. The publisher does not enforce this setting; the agent must.
A repository where even the owner alias is sensitive should not publish these notes.
See [configuration](../../../docs/settings.md#wipinclude_locations).

**Resume as the original owner:** read the live note before writing. If it names
another owner or tag, preserve local work without pushing, report the transfer,
and stop. Otherwise refresh the PR and continue. A missing or outdated note after
a crash is a reason to inspect live state, not to abandon recovery.

**Take over in a new task:** require maintainer confirmation that the previous
owner stopped or is handing over. An idle task, old timestamp, or missing note
is insufficient. Then read the live head and publish a complete note with a new
owner tag before other work. Recheck checks, review, and merge authority. Inspect
and preserve staged, unstaged, untracked, stashed, and unpushed work when the old
checkout is reachable; record it as `UNKNOWN` when it is not.

The note records state. It is not a lock or authorization, and the read/write gap
still allows a race. Maintainer confirmation prevents competing owners.

## When a task needs several PRs

Default to one PR. Split for useful separate outcomes, different risks, or a diff
that is difficult to review. Around 500 changed lines is a reason to reconsider
scope, not a quota. Keep tests with the behavior they verify.

Recommend a short ordered list of outcomes, dependencies, and verification. Make
routine splits within the authorized task; ask about changed product scope or
risky partial releases. Each slice must be safe with its prerequisites.

Keep one task owner. Record dependencies and remaining scope on the PRs, and link
them from the original work item when sharing is authorized. A partial merge does
not finish the task. Report shared planning and review usage once with its commit
mappings.

Use ordinary PRs against the task's base. For dependent slices, merge the first
before publishing the dependent PR under the same Ask/Auto workflow.

If the work already exists on a large branch, extract an independently useful
prerequisite onto a branch from the validated base. Keep its tests with it and
review that PR on its own. After it merges, update the remaining branch and check
that the main PR no longer repeats the prerequisite changes. For example, extract
a required React upgrade before the React on Rails integration. Preserve the
original work while moving commits or hunks; never discard unrelated edits.

Native stacked PRs are not required or supported by this workflow.

## A short message, with evidence available

One owner communicates progress, decisions, and results. The final message names
the outcome, PR links, validation, and remaining action. Keep material risks,
required decisions, and missing evidence visible; link to supporting detail.

### Identify AI-authored posts

Begin GitHub descriptions, comments, and reviews with actual agent, provider,
model, and effort, for example:

> 🤖 Codex · OpenAI · gpt-6-astra · medium

Use `UNKNOWN` for unavailable values. This identifies the writer; reviewer and
contributor usage belongs in details. Preserve human text and label mixed work
AI-edited rather than claiming full authorship.

### Make the PR description useful first

Write for someone deciding whether to merge without reading the diff. State the
outcome and why it matters. Show blockers, decisions, and missing required review.
Include the check table, provenance, usage tables, and WIP Details note while unfinished.
Keep optional review history and routine rollback detail collapsed.

Supply the current COMMENT review URL in the `walkthrough` field. The helper
renders its link after the summary, or `_Not published yet._` until it exists.
Supply the live preview or deployment URL in the required `deployment` field, or
`none` when the change deploys nowhere. The helper links it beside the walkthrough.
Also link to the current review result. Self-edit the content JSON before
publication; let the helper render headings, tables, and details.

### Why the description and the walkthrough differ

The description explains the outcome and delivery decision. The walkthrough
explains why the implementation looks as it does. Each needs enough context to
stand alone, but copying sentences between them creates two versions to maintain.

Use these questions to place detail:

- Does it affect whether to merge or what to do afterward? Put it in the description.
- Does it explain a design choice or make the diff easier to understand? Put it in the walkthrough.
- Would a later reader need it from the merged PR alone? Keep it in the description.

A rollback may need an operational summary in the description and code-level
reasoning in the walkthrough. File paths alone do not decide placement.

### How a walkthrough is ordered

Start with the earlier behavior and what now works. Then explain changes in the
order that makes them understandable: usually contract or data model, core
behavior, integrations, and finally tests, documentation, and migration.

Explain unfamiliar terms on first use. Distinguish mechanical moves and generated
output from behavior changes. Cover purpose, choices, validation, risks, and
rollback consequences where they fit; avoid a heading for every checklist item.
Use commit-pinned code links. Cover the change completely, then stop.

### Keep one current walkthrough

Edit wording at the same revision in place. For a new commit, publish a walkthrough
for that head and update the description's link. Keep review history in the
description's details rather than appending it to the walkthrough.

The walkthrough command collapses your older walkthroughs after it confirms the new
review. Each one leads with “Superseded — read the current walkthrough:” and that
review's link, and the old body and revision stay inside details. Other authors'
reviews and independent reports stay as they are. When the edit is unavailable,
the new walkthrough still stands and the command reports the limitation. This
cleanup does not block merge.

Collapsed PR content is still public and still costs tokens when loaded. Store
useful evidence once; retrieve and link it as needed.

## Writing preferences

Before publishing, read [writing guidance](writing.md) and apply trusted repository
preferences.

## What the helpers protect

| Boundary | Responsible layer |
| --- | --- |
| GitHub argument handling, JSON parsing, and identifier checks | Ruby helpers |
| Expected commit, observable required checks, and supported merge state | Helpers and native GitHub enforcement |
| Which public comment bodies reach the agent | [Public-comment reader](public-comments-safety.md) |
| Task authority, execution safety, and adequate verification | Agent following trusted instructions |
| File, network, and credential access while running candidate code | Host permissions and execution environment |

The helpers do not prove the agent's judgments or create a sandbox. Review what
will be published and use restricted execution for untrusted contributions.
Private repositories can contain unsafe text and code too.

## Knowing whether communication improved

Use actual task and PR history to assess reading, repeated explanation, late
questions, and corrective work. Human active time needs a human estimate;
elapsed timestamps cannot establish it.

Check that the outcome is understandable without opening every detail, questions
arrived in time, and model/token evidence remains findable. Compare similar
accepted changes using the [pilot criteria](https://github.com/shakacode/shaka/blob/main/internal/requirements.md#success-evidence-and-commit-attribution).
A shorter document or a passing prose review does not establish better usability.
