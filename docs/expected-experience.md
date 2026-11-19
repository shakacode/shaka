# When work stops or verification is incomplete

<a id="what-to-expect-from-shaka"></a>
<a id="pilot-status-and-limitations"></a>

If work stops or verification is incomplete, the agent should explain what
happened, what remains unverified, and what needs to happen next.
For installation, see [Start here](getting-started.md). For everyday prompts,
see [Working with Shaka](working-with-shaka.md).

<a id="understand-the-prs-settings-and-evidence"></a>
<a id="run-an-ordinary-task"></a>

## Incomplete verification

The PR should say what was checked, what could not be checked, and why. The agent
resolves problems it can fix and explains any access or decision it needs from you.
Missing or stale evidence does not satisfy a required check.

If the PR changes after verification, the agent reruns affected checks. If a check
also fails on the target branch, the agent establishes whether the PR caused the
failure before changing unrelated code. See
[merge choices and existing failures](working-with-shaka.md#choose-a-merge-policy).
Required checks and approvals still apply.

Use [Review the PR and improve the process](pr-verification.md) to decide whether
to request revisions, provide missing access, or merge.

<a id="resume-or-change-your-checkout"></a>

## Interrupted work

Return to the original chat. Use **WIP Details → Chat link** in the PR description
when a link is available. If you cannot find or continue that chat, make sure the
previous agent has stopped, then use
[Resume unfinished work](working-with-shaka.md#resume-unfinished-work).
On a public PR, WIP Details and other expandable sections are public too.

Before a PR exists, the work may still be only on the original computer. Keep the
checkout and chat available. Tell the agent the task and where the work was saved.
If files or the checkout are missing, ask it to inspect what can be recovered
before restoring or recreating anything. Unsaved work may be lost.

<a id="private-trials-available-tools-incomplete-guided-experience"></a>
<a id="individual-trials-available-tools-incomplete-guided-experience"></a>
<a id="individual-setup"></a>

See [individual setup](settings-guide.md#use-individual-or-team-settings) to keep
settings local. The agent can carry saved individual settings into a separate
checkout for a later task. Those recovery copies contain settings only. See
[return points](reference/pr-record.md#recovery) for what work can be restored.

## When the coding agent denies access

The agent should name the failed operation, explain why it needs access, and say
what remains undone. It should not claim that the operation succeeded.

Review the requested access in your coding tool. Grant what the task needs, then
ask the agent to retry and verify the result. Shaka cannot grant itself access
or change your coding tool's permissions. See [coding agents](coding-agents.md).

<a id="choose-how-to-start"></a>
<a id="multiple-reviewers-per-commit"></a>
<a id="decide-whether-to-merge"></a>

## More help

- [Set up a project](getting-started.md#2-set-up-your-project) or [configure it for your team](configure-repository.md).
- [Choose settings](settings-guide.md), including [which settings apply](settings.md#which-settings-apply) and [multiple reviewers](settings.md#reviewlocal_review_count).
- [Frequently asked questions](faq.md) cover common setup, review, and merge questions.
- [PR evidence details](reference/pr-record.md) explain reports, return points, and recovery limits.

<a id="what-the-pilot-has-established"></a>
<a id="recorded-verification-evidence"></a>

The [first-task acceptance report](https://github.com/shakacode/shaka/issues/277#issuecomment-5904859759)
records tested and untested scenarios for an earlier installation. It is evaluation
history, not proof that every scenario works in the current version.
