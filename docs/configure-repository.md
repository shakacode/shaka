# Configure a repository

Give teammates the same checks and review choices without maintaining a separate
workflow for every project:

```text
$shaka Set up Shaka for this repository.
```

The agent finds your existing test and lint commands and proposes a settings PR.
Review the choices and merge the first setup PR yourself on GitHub. Its settings
become the team's defaults after merge. You can
[try the settings on one task](settings.md#preview-settings-before-adopting-them)
first. To try Shaka alone, use [individual setup](settings-guide.md#use-individual-or-team-settings).

<a id="use-shaka-across-projects"></a>

## Before you start

Choose checks that would catch a broken change. Shaka uses GitHub's required
checks, or your configured [required-check list](settings.md#mergerequired_checks)
when GitHub requires none. Ask if you are unsure:

```text
Which checks would block a broken PR here? Which important failures do they miss?
```

With no required check, use Ask and decide whether the local evidence is enough.
Auto needs at least one required check. A Shaka-only list does not prevent someone
from merging through GitHub; use branch protection or rulesets for that.

<a id="set-up"></a>

## Change choices later

Ask for the effect you want, such as waiting for all configured CI reviewers.
The agent prepares a separate settings PR. Each project can choose different
checks and reviewers. See [Choose your settings](settings-guide.md).

## Add hosted Claude review

Hosted review also covers teammates who do not use Shaka:

```text
$shaka Add Shaka's hosted Claude review workflow and configure it as a CI reviewer.
```

You need to create the `CLAUDE_CODE_OAUTH_TOKEN` repository secret. The shipped
workflow skips drafts, Dependabot, and fork PRs; review those another way. Cursor
cloud pushes are supported. For another GitHub App, add it to `allowed_bots`.

When the author has already posted a local Claude review of that commit, hosted
Claude checks for serious bugs the local reviewers missed. Otherwise, it performs
a full review. See the [shipped workflow](https://github.com/shakacode/shaka/blob/main/skills/shaka/config/claude-code-review.yml)
for its configurable wait and triggers.

<a id="files-the-agent-prepares"></a>

## Review setup choices

Confirm that the chosen commands run your real checks and fail when those checks
fail. Configuration lives under `.agents/shaka/`; your existing `AGENTS.md`
continues to hold project rules. Shaka does not create or edit it during setup.
Use the [settings reference](settings.md#standard-command-scripts) for script paths.

### Run the scripts in a CI container

If Git refuses a container checkout because another user owns it, mark the actual
checkout path safe before running the scripts. For a GitHub Actions workspace:

```yaml
- run: git config --global --add safe.directory "$GITHUB_WORKSPACE"
```

For a subdirectory checkout, mark that subdirectory instead. Jobs running directly
on a GitHub-hosted runner need no change.
