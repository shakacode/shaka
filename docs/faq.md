# Frequently asked questions

Examples use `/shaka`. In Codex, use `$shaka` instead.

## What should I try first?

Choose a small change in a project you know and follow [Start here](getting-started.md).
For a practice project, use [Shaka in pictures](shaka-in-pictures.md).
Then [review the PR](pr-verification.md) to decide what happens next.

## Do I need to write configuration by hand?

No. Ask your agent:

```text
/shaka Help me set up Shaka for this project.
```

The agent inspects the project, reuses existing checks, and explains the choices.
For team setup, review and merge the setup PR before using the shared settings.
See [repository setup](configure-repository.md).

## Can I try it without changing team configuration?

Yes, when the project has no shared Shaka settings:

```text
/shaka Fix search when the query contains an apostrophe. Set up Shaka just for me.
```

Your settings stay out of commits. Existing team settings still apply if present.
To try different team settings for one task, use a
[settings preview](settings.md#preview-settings-before-adopting-them).
Trying a change to Shaka itself is separate: see [try a Shaka PR](trying-pr-versions.md).

## Can I use a different setting than my team?

For a supported task choice, say what you want, such as "Ask me before merging."
For a lasting change, ask for a settings PR. You can explicitly
[try that settings PR](settings.md#preview-settings-before-adopting-them) before it merges.

Local settings do not override team settings. See
[which settings apply](settings.md#which-settings-apply).

## Why did the agent stop to ask about model and effort?

Shaka recommends a model and effort before implementation. If you specify either,
the agent pauses when the choice is unavailable, cannot be verified, or differs
from its recommendation. If you say "Go" without specifying either, it continues
with the coding tool's current settings. A prompt cannot switch the running model.
See [give it an outcome](working-with-shaka.md#give-it-an-outcome).

## Why didn't the agent merge my PR?

Shaka uses **Ask** by default. When the PR is ready, merge it on GitHub or tell
the agent, "You can merge." For **Auto**, say "Merge when ready."

Required checks, reviews, approvals, and unresolved concerns can still hold a
merge. Large or risky changes may need your decision. Ask the agent what is
blocking this PR and what it needs from you. See
[merge choices](working-with-shaka.md#choose-a-merge-policy).

## Can I make sure the agent never merges?

Add "Do not merge" to your task:

```text
/shaka Add CSV export to the orders page. Do not merge.
```

This tells the agent to leave the PR open. Shaka's instructions rely on the agent
following them. To enforce a restriction through GitHub permissions, use branch
protection that requires approval from another eligible reviewer. The agent's
account must lack permission to bypass or change those rules.

<a id="does-a-green-review-job-mean-the-pr-was-reviewed"></a>

See [how Shaka counts review results](settings.md#reviewci_review_jobs) and
[what a ready PR shows](pr-verification.md).

## Can the agent review its own work?

Shaka prefers a reviewer from another provider. A fresh review session can also
use the implementation model without its earlier conversation. This gives the
change another examination; it does not guarantee that every problem is caught.
See [reviewer choices](settings.md#reviewlocal_review_agents).

<a id="why-does-shaka-review-with-a-separate-cli-instead-of-a-subagent"></a>
<a id="why-does-shaka-use-a-separate-review-session"></a>
<a id="do-multiple-reviews-run-one-after-another"></a>

For review-session access and concurrency details, see
[reviewer limits](settings.md#reviewlocal_review_agents) and
[reviewer count](settings.md#reviewlocal_review_count).

## Why did the agent ignore a PR comment?

The agent may no longer be running or receiving automatic follow-up. Return to
the chat and paste the comment link. See
[resume unfinished work](working-with-shaka.md#resume-unfinished-work).

### Comments on public open-source PRs

Anyone can comment on a public PR. Shaka passes trusted comments to the agent
and withholds comments from other authors, keeping their links for a maintainer
to inspect. Maintainers can read the feedback and give the agent their own
instructions. See [comment trust](workflow.md#trust-model).

To trust an additional contributor, ask:

```text
/shaka Add USER to this project's trusted GitHub actors.
```

<a id="where-is-shaka-installed-and-is-that-my-configuration"></a>

## Where are the skill and settings saved?

The installed skill contains Shaka's workflow. Project settings choose how that
workflow runs for your project. Ask your agent:

```text
Tell me about the Shaka configuration.
```

The agent can explain which settings apply and where they are saved, separately
from where the skill is installed. See [where settings live](settings-guide.md).
For an installation problem, use [manual installation and repair](manual-installation.md).

## Where do I put project rules?

| What you want to record | Where it belongs |
| --- | --- |
| Project standards, constraints, and writing preferences | `AGENTS.md` |
| Check commands, reviewers, and merge choices | [Shaka settings](settings-guide.md) |

Keep each rule in one place. Shaka reads `AGENTS.md` from the trusted Git revision,
including a repository symlink target such as `CLAUDE.md`. Your coding tool also
needs to load the project instructions. Claude Code does not read `AGENTS.md`
in every session. When `AGENTS.md` holds the rules, use a `CLAUDE.md` containing
`@AGENTS.md` to load them consistently. See Claude Code's
[AGENTS.md support](https://code.claude.com/docs/en/memory#agents-md) and
[coding agents](coding-agents.md).

## Can I customize the prompt Shaka gives its local reviewer?

Yes. Put project-wide criteria in `AGENTS.md`, or ask the agent to add local
review instructions:

```text
Have the local reviewer flag API changes that break existing clients.
```

The agent proposes the instructions and settings change while keeping Shaka's
default review criteria. See [custom review instructions](settings.md#reviewcustom_instructions_file)
for adding to or replacing those defaults. CI review jobs have their own prompts.

## Can a PR change Shaka's settings or rules for itself?

Editing settings does not select them automatically. Shared settings and review
criteria normally come from the default branch. A maintainer can explicitly
[preview a settings PR](settings.md#preview-settings-before-adopting-them) for one
task. GitHub's required checks and approvals still apply.

<a id="what-is-a-decision-checkpoint"></a>
<a id="what-is-an-evaluation-checkpoint"></a>

## What is a checkpoint?

The checkpoint assesses the finished result and recommends what to do next.
When present, open the **Checkpoint** link near the top of the PR description. See
[the checkpoint reference](reference/pr-record.md#checkpoint) for report details.
A recommendation to merge does not authorize a merge.

## Can I hide my checkout path while keeping the chat locator?

Yes. Ask your agent:

```text
Hide my project folder's path in WIP Details. Keep the chat link.
```

The path then appears as `REDACTED`. Any available chat link stays in place.
See [WIP settings](settings.md#wipinclude_checkout_path).

## What does Shaka enforce, and what relies on the agent?

Shaka's helper checks settings, trusted comment authors, and merge evidence.
The agent judges whether tests and reviews are thorough enough, evidence is
clear, and publication protects private information. See
[what is enforced](workflow.md#what-is-enforced) for the exact boundaries.
