# Choose your settings

Ask your agent what applies before changing a setting:

```text
Tell me about the Shaka configuration.
```

The agent can explain your project's choices, where they are saved, and what
each setting changes. See the [settings reference](settings.md),
[built-in defaults](../skills/shaka/config/defaults.yml), and
[Shaka's own overrides](https://github.com/shakacode/shaka/blob/main/.agents/shaka/config.yml) for a working example.

Examples use `/shaka`. In Codex, use `$shaka` instead.

## Where Shaka keeps things

Shaka is installed as a skill for your coding agent. Each project has its own settings,
usually in `.agents/shaka/config.yml`:

| Settings | Where they are saved |
| --- | --- |
| Individual | In your local checkout, outside commits |
| Team | In the repository's default branch, shared through PRs |

Team settings take precedence. If the repository leaves the PR display time zone
unset, Shaka can use your personal time zone. Other local settings do not fill in
team settings. A personal starting template can supply initial choices for individual setup.
See [which settings apply](settings.md#which-settings-apply) and
[start individual setups from your preferences](settings.md#start-individual-setups-from-your-preferences).

## Use individual or team settings

To try a task in a project that has no shared Shaka settings:

```text
/shaka Fix search when the query contains an apostrophe. Set up Shaka just for me.
```

Individual settings can choose reviewers and PR preferences. Local settings do
not authorize automatic merging or supply fallback required checks. To share your
team's choices:

```text
/shaka Set up Shaka for my team in this repository.
```

Review and merge the separate setup PR on GitHub. Its settings then become the
team's defaults. See [team setup](configure-repository.md).

## Change your team's settings

Ask for a separate settings PR. For example:

```text
/shaka Propose waiting for all configured CI reviews before merging.
```

The agent explains what changes and what the team needs to do. Review the PR
before merging. Follow any update instructions in the settings PR: a copy of
Shaka older than a new setting refuses the settings file, so every task on that
copy stops until it updates.

<a id="common-situations"></a>

### Try settings before adopting them

You can use a settings PR for one task:

```text
/shaka Fix search when the query contains an apostrophe. Use settings from PR #123.
```

That task uses the selected configuration. Each teammate can choose the same PR
for their own trial. For a supported choice on one task, state it in the prompt,
such as "Ask me before merging." Other tasks keep their usual settings.
GitHub's required checks and approvals still apply. Ask explicitly to switch to a
newer version of the settings PR. See [settings previews](settings.md#preview-settings-before-adopting-them).

## Choose a merge policy

See [merge choices](working-with-shaka.md#choose-a-merge-policy) for **Ask** and
`auto`, including when you still need to review. To change the team default:

```text
/shaka Propose making automatic merging the default for this repository.
```

The new default applies after the settings PR merges. See
[merge preference](settings.md#mergepreference).

## Choose AI reviewers

Ask for the reviewer you want and have the agent check access:

```text
/shaka Propose using Claude first for code review in this repository.
```

Shaka prefers a reviewer from a different provider than the implementation agent,
then uses your configured order. Additional reviewers can add cost and time.
See [reviewer choices](settings.md#reviewlocal_review_agents) and
[reviewer count](settings.md#reviewlocal_review_count).

Use `AGENTS.md` for project rules. To add guidance for Shaka's local reviewer, ask:

```text
/shaka Add local review guidance to flag API changes that break existing clients.
```

Those instructions can add to Shaka's defaults. CI review jobs have their own
prompts. See [custom review instructions](settings.md#reviewcustom_instructions_file).

## Keep PR explanations useful

Tell the agent who reads your PRs and what they need to decide:

```text
/shaka Write PR explanations for someone who knows the product but hasn't read the code.
Keep supporting evidence expandable.
```

Use [writing preferences](writing-preferences.md) and
[prose limits](settings.md#prose_limits) to guide descriptions and walkthroughs.
The [opening check](settings.md#opening_check) can suggest a clearer first sentence.

## Decide what happens next

The [checkpoint](reference/pr-record.md#checkpoint) evaluates the finished result
and recommends the next action. You can choose its reviewer, model, and effort
separately from code review. See [checkpoint settings](settings.md#checkpoint).

## Add your own PR requirements

Ask the agent to record what every relevant PR should show. For example:

```text
/shaka Add a PR requirement: explain the database backfill plan before merging.
```

The agent can propose a settings PR. Use CI or your validation script for
requirements tools can test. Use [project guidance](settings.md#project_guidance)
for evidence the agent should assess and report in the PR.

## Resume unfinished work

**WIP Details** in the PR description helps you find the owning chat and next action.
To hide your project folder's path in **WIP Details**, ask:

```text
Hide my project folder's path in WIP Details. Keep the chat link.
```

The path appears as `REDACTED`. Any available chat link stays in place. See
[WIP settings](settings.md#wipinclude_checkout_path) and
[resume unfinished work](working-with-shaka.md#resume-unfinished-work).
