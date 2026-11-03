# Releases after merge

Merging a verified PR does not establish that production is healthy. Keep
release approval, observation, and recovery in your project's release process.
Shaka prepares the PR; it does not deploy or monitor the release for you.

## Carry release work into the handoff

Name work beyond merging when you give the task:

```text
$shaka Add the new invoice field. Record the backfill owner and staging check
before we merge; do not deploy.
```

Agree who runs each staging check, backfill, or feature-flag change, and when.
Keep those actions on the PR so the release owner can find them after merge.
For requirements on every PR, add [project guidance](settings.md#project_guidance).

## Decide whether to release

Check the exact release range, migrations, dependencies, and current staging
results. A preview for one PR may not exercise the combined release.

Keep alert thresholds, an observation window, an on-call handoff, and recovery
steps somewhere that remains available after the agent chat ends. Release and
rollback permission come from your project, separately from permission to merge.

<a id="keep-three-decisions-separate"></a>
<a id="what-shaka-records-for-your-release"></a>
<a id="what-your-project-owns"></a>
