# What to expect from Shaka

<a id="pilot-status-and-limitations"></a>
<a id="what-the-pilot-has-established"></a>

Give your agent a task. It checks setup, builds and verifies the change, and
opens a PR explaining the result. Ask for help as you go.
[Start here](getting-started.md) covers your first task.

## Choose how to start

If your project has no Shaka settings, the agent asks whether to set it up just
for you or for your team. Individual settings stay out of commits. Team settings
arrive in a [setup PR](configure-repository.md) your teammates can review.
Neither choice authorizes merging your work.

<a id="private-trials-available-tools-incomplete-guided-experience"></a>
<a id="individual-trials-available-tools-incomplete-guided-experience"></a>

### Individual setup

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

Individual setup supports the same reviewer and writing preferences as team
setup. It applies only where team settings are absent. To try different team
settings for one task, select a [settings PR](settings.md#preview-settings-before-adopting-them).
To try a change to Shaka itself, use a [PR trial](trying-pr-versions.md).

## Run an ordinary task

Describe the outcome you want. The agent finds your project's checks and asks
when it needs a decision. If there are no useful checks, agree on whether to add
them or report limited verification.

## Multiple reviewers per commit

Start with one reviewer. [Additional reviewers](settings.md#reviewlocal_review_count)
cost more; the agent combines their findings before making repairs.

## Understand the PR's settings and evidence

The PR shows what was tested and reviewed, which commit those results cover,
and any missing evidence. Failed checks or stale results cannot satisfy a
required gate. A settings summary alone does not prove tests or review ran.

```text
Explain what this PR's verification proves and what I still need to check.
```

Public PRs, including their expandable details, are public. WIP Details normally
includes your checkout path and a chat locator. You can
[hide the checkout path](settings.md#wipinclude_checkout_path) or ask the agent to
withhold the chat locator before publication. Shaka redacts selected settings;
the agent still has to inspect the rest for private content.

## Decide whether to merge

By default, you merge on GitHub or approve the agent's merge. With Auto, the
agent merges eligible work after checks and approvals; large or risky changes
still need your decision. See [merge choices](working-with-shaka.md#choose-a-merge-policy).

When continuing the same task, the agent reuses an established merge choice.
A WIP note alone does not grant authority. If a new chat cannot verify your
earlier Auto decision, state it again.

## Resume or change your checkout

Return to the chat that owns the work. Before handing it to a new chat, finish
or cancel any active automatic follow-up and confirm the previous owner stopped.
Then give the new chat the PR URL. WIP Details identifies the
revision, unfinished work, and next action.

Before a PR exists, give the new chat the task, checkout, and branch, plus saved
check results if available. It reruns checks whose results are missing.

Captured individual settings can seed a new worktree even after the earlier
worktree is deleted. Keep the earlier checkout available to capture its latest
edits first. Recovery copies protect captured settings, not feature changes or
conversations. Uncaptured edits, or deletion of the shared Git directory, cannot
be recovered from those copies. Team settings take precedence over saved
individual settings.

To revisit earlier guidance, ask for a [return point](pr-verification.md#return-points).
It can restore only the work state the agent recorded.
See [resuming unfinished work](working-with-shaka.md#resume-unfinished-work).

## When the coding agent denies access

The agent reports the failed operation and path. Use your coding tool's
permission controls, then retry. Shaka cannot grant access; permission to edit
project files may still exclude the Git files individual setup needs.

<a id="recorded-verification-evidence"></a>
