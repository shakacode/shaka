# Choose your settings

Give Shaka a task:

```text
$shaka <task or issue link>
```

If the project has no Shaka setup, the agent asks whether to prepare individual
or team settings. It finds your existing checks, explains the AI review choices,
and defaults to Ask. The [settings reference](settings.md) owns the options and defaults.

## Where Shaka keeps things

Using Shaka is separate from your team adopting it. You can use Shaka on any
repository without changing it, and adopt it as a team later through an ordinary PR.

| What | Where | Who decides |
| --- | --- | --- |
| Shaka itself | Your Shaka installation, linked into your coding agent | You, when you install or update |
| Individual settings | `.agents/shaka/` in your copy of the repository, kept out of commits | You, until the team adopts Shaka |
| Your starting point for individual setup | `~/.agents/shaka/config.yml`, read when an individual setup starts, and for your time zone when a PR's repository sets none | You |
| Team settings | `.agents/shaka/`, committed on the default branch | Your team, through settings PRs |

Each task uses one of these settings sources, never a mix, apart from your time zone. See
[which settings apply](settings.md#which-settings-apply).

## Use individual or team settings

**Individual setup** lets you try Shaka before your team adopts it. Your choices
stay in your local copy of a repository without shared Shaka settings, outside commits.
To choose it upfront:

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

Individual settings support the same choices as shared settings: reviewers, custom
code-review instructions, checkpoint choices, writing limits, opening instructions,
and WIP preferences.
See [current experience and recovery limits](expected-experience.md#individual-setup).

If you try Shaka on several repositories, write those preferences once in
`~/.agents/shaka/config.yml`. Each new individual setup starts from them, and you
still review the proposal before Shaka writes it. See
[start individual setups from your preferences](settings.md#start-individual-setups-from-your-preferences).

For shared team settings:

```text
$shaka Set up Shaka for this repository.
```

The agent opens a settings PR for you to review. Its choices become the team's
defaults after it merges into the default branch. Individual settings do not
override team settings.

You can [try a settings PR on one task](settings.md#preview-settings-before-adopting-them)
before adoption. The PR keeps the experiment visible.

## Change your team's settings

Settings changes get their own PR. Shaka's checks before push and its PR description
publisher both refuse a feature PR that also changes files under `.agents/shaka/`, so a
settings change never hides inside other work.

To see where you stand first, ask your agent:

```text
$shaka Explain this repository's Shaka settings.
```

It goes through the settings a group at a time, with each value, whether it is the
default, and a link to its [reference](settings.md) section. To see the full instructions a
reviewer gets, ask `$shaka Show what my code reviewer receives.` or name the checkpoint or
the opening check.

1. Ask for the change, for example:

   ```text
   $shaka Propose using Codex first for local reviews in this repository.
   ```

   The agent prepares the change as its own settings PR. An older Shaka refuses a
   settings file with a setting or option it does not know, so every task stops until it
   updates. The PR therefore lists updating Shaka as a step after merge, with the date
   each new setting or option first appeared when Shaka can find it, so you can tell
   whether anyone's copy is that old. A PR that only removes settings, or only edits a
   prompt file, lists no update. You can also edit
   `.agents/shaka/config.yml` in a PR yourself.
2. To try it before it merges, select it for your tasks. Teammates can select the
   same PR:

   ```text
   $shaka <task or issue link>
   Use settings from PR #123.
   ```

3. Merge the settings PR. Its choices become the team's defaults.

## Common situations

| Situation | What to do |
| --- | --- |
| Try Shaka on a repository your team has not adopted | Ask for individual setup. Feature PRs contain no Shaka files. |
| Share a trial setup with a teammate | Put the settings in a settings PR; each of you selects it for your tasks. |
| Adopt Shaka as a team | Ask Shaka to set up the repository; review and merge its settings PR. |
| Change one setting for one task | Say it in the request, such as `Use Ask for this task`, where the setting allows it. |
| Change a team setting for good | Follow [change your team's settings](#change-your-teams-settings). |

## Choose a merge policy

With **Ask**, review the ready PR, then merge it yourself or tell the agent to merge.
With **Auto**, the agent merges after required checks, reviews, and approvals.
Some changes still need your decision.

```text
$shaka <task or issue link>
Use merge policy Auto. Go.
```

`Go` starts work; it does not authorize merging. See
[merge choices](working-with-shaka.md#choose-a-merge-policy).

## Choose AI reviewers

A separate AI session reviews the code before publication. Choose reviewers you can
access through their tools or API credentials:

```text
$shaka Prefer Claude for code review.
```

Shaka first prefers a provider that did not implement the change, then follows your
configured order. The list supplies choices; the [reviewer count](settings.md#reviewlocal_review_count)
determines how many run. Reviews can run concurrently. Additional reviewers add
cost and may increase elapsed time. A fresh context does not guarantee a better review.

For custom instructions:

```text
$shaka Focus code reviews on compatibility.
```

The agent starts from Shaka's defaults when preparing replacement instructions.
Use one prompt for all local reviewers or one for a particular reviewer. Team
instructions come from the default branch; individual instructions stay in your
local settings folder. See
[custom review instructions](settings.md#reviewreplacement_prompt_file).

## Keep PR explanations useful

```text
$shaka Keep PR descriptions under 200 words.
```

Shaka checks [writing limits](settings.md#prose_limits) before publishing descriptions
and code walkthroughs, including with individual settings. Recommendations and
review replies follow agent instructions; code does not check their length.

An [opening check](settings.md#opening_check) advises whether the first sentence
of a description or walkthrough leads with what improves for the reader, and
suggests plainer words for terms in a description that a maintainer new to Shaka
would not follow. It does not verify the whole text.
You can choose its reviewer, model, and effort separately from code review, or
turn it off, in team or individual settings.

## Decide what happens next

Shaka recommends what to do next at a
[checkpoint](pr-verification.md#checkpoint) and records the owner's
choice for later. See that guide for the terms and current report labels.
[Checkpoint settings](settings.md#checkpoint) choose who evaluates
the result, with team or individual setup.

## Add your own PR requirements

```text
$shaka Add project guidance: before merge, confirm the database backfill plan.
```

The agent reads your [PR evidence, merge-readiness, and walkthrough guides](settings.md#project_guidance)
when it writes the PR description and the code walkthrough, and before the checkpoint.

## Resume unfinished work

**WIP Details** records the chat locator, checkout path, state, and next action.
A locator helps you resume the owning chat when your host can reach it.
[The checkout-path setting](settings.md#wipinclude_checkout_path) hides the path
and keeps the locator.
