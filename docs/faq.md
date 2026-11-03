# Frequently asked questions

## What should I try first?

Pick a small bug or improvement in a project you know. Follow [Start here](getting-started.md)
to install Shaka, ask the agent to configure the repository, and run your task.
[Working with Shaka](working-with-shaka.md) has prompts for planning, feedback, and review.

## Do I need to write configuration by hand?

No. Ask the skill to inspect your project and reuse its existing checks.
For shared setup, review the agent's choices and merge the initial setup PR yourself.
See [repository setup](configure-repository.md).

## Can I try it without changing team configuration?

Yes, if the repository has no shared Shaka settings:

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

Settings stay out of commits. See [individual setup](expected-experience.md#individual-setup).
With team settings, local choices do not override them. You can explicitly
[select a settings PR](settings.md#preview-settings-before-adopting-them) for one task.
Trying a different Shaka implementation is separate: see [try a Shaka PR](trying-pr-versions.md).

## Can I use a different setting than my team?

For one task, say it in your request, such as `Use Ask for this task`, where the
setting allows it. For a lasting change, propose a settings PR and
[select it for your tasks](settings.md#preview-settings-before-adopting-them) until
it merges.

Individual settings do not apply in a repository with team settings, even for a value
the team leaves out: Shaka uses its own default there. Settings always come from one
source, so you can tell which choices governed a task. See
[which settings apply](settings.md#which-settings-apply).

## Why did the agent stop to ask about model and effort?

Before it changes code, Shaka recommends a model and effort for the task.
“Go” without naming either accepts your agent's current settings, even when
they differ from the recommendation or cannot be reported. If you name either
setting, Shaka pauses when the settings are unavailable, unverified, or differ
from its recommendation. See [give it an outcome](working-with-shaka.md#give-it-an-outcome).

## Why didn't the agent merge my PR?

Under **Ask**, the default, the agent labels the PR `awaiting-merge-approval` and
names the commit to merge. Merge it on GitHub, or approve that commit and the
agent merges it. Under **Auto**, a PR
past the [size limits](settings.md#mergelimits), or one that changes trust,
authentication, releases, or other consequential areas, still comes back to you.
See [choose a merge policy](working-with-shaka.md#choose-a-merge-policy).

## Can I make sure the agent never merges?

Under **Ask**, the agent merges only after you approve that PR's commit. To have
a task end at the PR, say so in your prompt, for example `Open a PR and stop`.
Ask relies on the agent following its instructions, and the agent acts with your
GitHub permissions. To have GitHub block the merge, protect the base branch:
require an approving review, and give no bypass to administrators or to any role,
team, or app that includes your account. The agent opens PRs as you, so someone
else then has to approve each one. An administrator can still change these rules,
so the block holds only when the agent's account is not an administrator.

## Does a green review job mean the PR was reviewed?

No. A job can pass without producing a review. The agent reads the report and
counts only one that covers the current commit. See
[`review.ci_review_jobs`](settings.md#reviewci_review_jobs).

## Can the agent review its own work?

It prefers a reviewer from a different provider, in the order set by
[`review.local_review_agents`](settings.md#reviewlocal_review_agents). Next it
uses a listed reviewer from the same provider. When no listed reviewer is
available, a fresh session with the implementation model reviews the change
without the implementation conversation.

<a id="why-does-shaka-review-with-a-separate-cli-instead-of-a-subagent"></a>

## Why does Shaka use a separate review session?

A fresh session reviews without the implementation conversation. This supplies
another perspective, without guaranteeing quality. Shaka uses a restricted CLI
or its supported API adapter and records the reviewed commit, findings, and
available usage. It does not count a same-host subagent as the local review.

Reviewers have different access to unchanged code. See
[reviewer choices and limits](settings.md#reviewlocal_review_agents) and
[what Shaka enforces](workflow.md#what-is-enforced).

## Do multiple reviews run one after another?

The agent runs them concurrently and combines their findings before repairs.
Additional reviewers add cost and may increase elapsed time.
See [reviewer count](settings.md#reviewlocal_review_count).

## Why did the agent ignore a PR comment?

Shaka trusts the people who maintain the project: anyone with write access, plus
the users, bots, and teams listed in `.agents/shaka/trusted-github-actors.yml` or your
machine's allowlist. On a public repository, anyone else can comment, and that
text could try to steer the agent. The agent withholds those comments and keeps
their links for you to read. To change the allowlist, ask:

```text
$shaka Add USER to this project's trusted GitHub actors.
```

## Where is Shaka installed, and is that my configuration?

New installs put the Shaka source in `~/.local/share/shaka/source`. That
checkout is not configuration, and you never edit it. Your settings live in
each project's `.agents/shaka/` folder and in `~/.agents/trusted-github-actors.yml`.

If the installation is missing or points at an old location, ask `$shaka doctor`.
For recovery without the skill, use the [manual status check](manual-installation.md#verify-and-update).

## Where do I put project rules?

| What | Where |
| --- | --- |
| Commands, merge policy, and review jobs | [Settings](settings.md) in `.agents/shaka/config.yml` |
| Project constraints, review criteria, and writing style | `AGENTS.md` |
| What the local reviewer looks for and how it reports | [`review.replacement_prompt_file`](settings.md#reviewreplacement_prompt_file), replacing Shaka's defaults |
| Changes to Shaka's workflow | A [fork of Shaka](fork-and-hack.md) |

For Claude Code, a `CLAUDE.md` containing `@AGENTS.md` gives it the same project
instructions. Shaka's reviewer reads trusted `AGENTS.md` independently.

## Can I customize the prompt Shaka gives its local reviewer?

Ask the agent to add your criteria, such as preserving compatibility with an
older public API. [Custom instructions](settings.md#reviewcustom_instructions_file)
add to Shaka's defaults. [Replacement prompts](settings.md#reviewreplacement_prompt_file)
replace them; start from a copy so you can choose what to remove. Local-review
prompts do not configure hosted CI reviews.

## Can a PR change Shaka's settings or rules for itself?

Editing settings in a PR does not select them automatically. Shared settings and
review criteria normally come from the default branch. A maintainer can explicitly
[select a settings PR's pinned configuration](settings.md#preview-settings-before-adopting-them)
for experiments. A fork PR cannot choose its own review rules. See
[which settings apply](settings.md#which-settings-apply).

<a id="what-is-a-decision-checkpoint"></a>
<a id="what-is-an-evaluation-checkpoint"></a>

## What is a checkpoint?

A checkpoint assesses whether the change solves the problem and is worth
maintaining. Use its [recommendation and evidence](pr-verification.md#checkpoint)
to decide what happens next.

## Can I hide my checkout path while keeping the chat locator?

Yes. Set `wip.include_checkout_path: false`. WIP Details then show `REDACTED` for
the checkout path and keep the chat locator, which helps resume the owning chat.
See [WIP settings](settings.md#wipinclude_checkout_path).

## What does Shaka enforce, and what relies on the agent?

Ruby checks settings and trusted comment authors. When the agent merges, it also
checks the reviewed commit and, when review is required, that posted review
covers it or that a reason for skipping review was given. How thorough that review
was, test quality, screenshots, and privacy rely on the agent's judgment. See
[what is enforced](workflow.md#what-is-enforced).
