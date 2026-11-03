# Choose your settings

Ask Shaka to explain your current choices before changing them:

```text
$shaka Explain this repository's Shaka settings.
```

Ask about one setting or work through them a group at a time. To inspect the
actual instructions given to an AI reviewer, ask:

```text
$shaka Show what my code reviewer receives.
```

<a id="where-shaka-keeps-things"></a>

## Use individual or team settings

Use individual setup to try Shaka without asking teammates to adopt it:

```text
$shaka Fix search when the query contains an apostrophe.
Set up Shaka just for me. Go.
```

Individual settings stay out of commits and apply only where team settings are
absent. For several repositories, [save your usual preferences once](settings.md#start-individual-setups-from-your-preferences).

When teammates want the same checks and review choices:

```text
$shaka Set up Shaka for this repository.
```

Review and merge its settings PR to adopt those choices together.
See [repository setup](configure-repository.md).

## Change your team's settings

Ask for the effect you want:

```text
$shaka Have Claude and Codex review every meaningful change in this repository.
```

The agent proposes a separate settings PR. You can try it on a task before
adopting it:

```text
$shaka Fix search when the query contains an apostrophe.
Use settings from PR #123. Go.
```

A preview pins the complete settings at one commit. Later edits to that PR do
not silently change your task. Merge the settings PR when the choices suit your
team. New options can require teammates to update Shaka; check the adoption
steps before merging. See [settings previews](settings.md#preview-settings-before-adopting-them).

<a id="common-situations"></a>

## Choose a merge policy

Keep **Ask** when you want a merge decision on each PR. Use **Auto** for eligible
work you want the agent to merge after checks, reviews, and approvals:

```text
$shaka Fix search when the query contains an apostrophe.
Use merge policy Auto. Go.
```

Large or risky changes still come back to you. A task's choice does not change
the team default. See [merge choices](working-with-shaka.md#choose-a-merge-policy).

## Choose AI reviewers

Start with reviewers you can access on the machine doing the work. More
reviewers add cost and may take longer; another perspective does not guarantee
that a bug will be caught. See [reviewer options](settings.md#reviewlocal_review_agents).

Add criteria the reviewer cannot infer from the code:

```text
$shaka Add a review rule: preserve our public API for customers on version 2.
```

Use [custom instructions](settings.md#reviewcustom_instructions_file) to add rules
while retaining Shaka's defaults. Replace the whole prompt only when you need to
remove a default rule.

## Keep PR explanations useful

```text
$shaka Keep PR descriptions under 200 words.
```

[Writing limits](settings.md#prose_limits) apply to descriptions and walkthroughs.
Use [writing preferences](writing-preferences.md) for voice, audience, or examples.

<a id="decide-what-happens-next"></a>

## Add your own PR requirements

Put checks your team repeatedly misses into [project guidance](settings.md#project_guidance):

```text
$shaka Add PR evidence guidance: for email-template changes, show rendered
before and after screenshots.
```

Automate a requirement in tests or CI when possible. Guidance asks the agent to
exercise judgment; it does not enforce the check itself.

## Resume unfinished work

To keep local directory names off public PRs, ask the agent to
[hide your checkout path](settings.md#wipinclude_checkout_path).
The chat locator stays available for [resuming work](working-with-shaka.md#resume-unfinished-work).
