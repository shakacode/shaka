# Choose your settings

Tell your agent how you want to work. It can prepare the configuration for you:

> $shaka Configure this repository using its existing checks. Explain the review
> choices and keep merge policy Ask.

Start with the choices below. The [settings reference](settings.md) has the exact
options, defaults, and advanced behavior.

## Try it privately or share settings with your team

A **private trial** is for a repository without shared Shaka settings. Your
configuration stays in one clone, outside Git, so you can try the workflow
before asking your team to adopt it:

> $shaka Set up a private trial for this task. Keep the configuration out of the
> PR and use merge policy Ask.

Your local choices control reviewers, writing limits, and the PR opening check.
They do not grant permission to merge or replace GitHub's required checks. See
[what private trials support](expected-experience.md#private-trials-available-tools-incomplete-guided-experience)
for the remaining real-use verification gaps.

Use [shared repository setup](configure-repository.md) when the team wants the
same configuration. The agent opens a settings PR for you to review. Those
choices take effect after that PR merges into the default branch.

## Choose who merges

With **Ask**, you review the ready PR and decide when to merge. With **Auto**, you
authorize the agent to merge after the required checks, reviews, and approvals.
You can choose for one task:

> $shaka Fix this issue. Use merge policy Ask.

See [merge choices](working-with-shaka.md#choose-a-merge-policy) for examples and
[`merge.preference`](settings.md#mergepreference) for the configuration.

## Choose a reviewer

A reviewer from a different model provider gives you another perspective. It
needs a working CLI and sign-in on the machine doing the review:

> Configure local reviews to try Claude first, then Codex. Use medium effort.

You can also request more than one reviewer. Each additional review adds time
and cost. The PR records who reviewed each commit and the available usage.

See [reviewer choices](settings.md#reviewlocal_review_agents),
[reviewer setup](settings.md#add-a-second-reviewer), and
[multiple reviewers](settings.md#reviewlocal_review_count).

## Keep PR explanations useful

Shaka limits long sentences, paragraphs, and explanations that outweigh the
change. If its PRs still feel too long, ask for a tighter limit:

> Keep PR descriptions under 200 words. Link to the code for implementation
> details instead of repeating them.

The agent changes [`prose_limits`](settings.md#prose_limits). In a private trial,
your local limits apply to descriptions and walkthroughs. With shared settings,
the team uses the limits on the default branch.

Shaka also checks whether a PR's opening explains what improves for its reader.
By default, the agent tries a configured reviewer. To keep that check with the
coding agent:

> Have the coding agent check the PR opening without sending it to another model.

See [`opening_check`](settings.md#opening_check) to customize the check or its
instructions.

## Choose what you publish

An unfinished PR can include your checkout path and a link back to the agent
chat. To keep those locations private:

> Hide my local workspace path and chat link in WIP Details.

The agent changes [`wip.include_locations`](settings.md#wipinclude_locations).
The PR still shows who owns the work, its current state, and the next action.

For branch names, additional merge limits, custom review instructions, and other
advanced choices, use the [settings reference](settings.md).
