# Try a Shaka PR on real work

No PR yet? [Test your local candidate first](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#test-before-pushing-or-opening-a-pr),
including from a fork checkout. Pushing a branch or opening a PR is not required
for local testing. The preparation and reporting workflow below needs an open PR.

Try an unmerged Shaka change on a real fix before deciding whether it belongs in
the product. Ask your agent in a preparation chat:

```text
$shaka Try Shaka from https://github.com/shakacode/shaka/pull/359
on this task: fix the search bug in /path/to/my/project.
Prepare a pinned trial and give me the prompt for a fresh chat.
```

Replace the PR, project, and task. The agent gives you a prompt for a **new chat**
in the project. The trial is pinned to one revision outside your project;
your normal installation and existing tasks keep their versions.

Each task uses one candidate at one exact revision. If the candidate changes,
prepare another trial for its new revision. To return to your normal version,
start another chat with your usual Shaka invocation.

## Keep the project's settings

The trial keeps your project's checks, reviewers, and merge policy. It does not
migrate settings. If the candidate needs a new setting, the agent explains the
incompatibility before following the normal configuration procedure.

## Share what happened

The result PR names the exact Shaka revision tested. Check that record before
reporting the trial.

After trying the change, ask your agent:

```text
Report this trial back to the Shaka candidate PR. Link our public result PR,
explain what helped and what I had to correct, and recommend keep, revise,
or drop. Review the summary for private details before publishing.
```

For private work, authorize a public-safe summary with no project link or private
context. You and the agent still inspect the report for confidential content;
the link checks do not scan all prose. Ask the preparation chat to publish it.
Reporting a trial requires no permission to manage labels. The maintainer
decides whether to merge; a trial report grants no merge authority.

Use a trial to learn from real work, not to claim that the candidate beats the
normal version. If adoption depends on that comparison, choose a
[focused comparison or full isolated evaluation](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#choose-an-evaluation-method).
An inconclusive comparison does not require another full replay; first identify
the evidence that would change the decision.
