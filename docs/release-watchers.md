# Watch a release after deployment

A release needs an owner after deployment, including when the agent or laptop
that started it disconnects. Run the observation window in infrastructure that
outlives that session, and give a primary responder and backup the same evidence.

This is a project-owned deployment pattern. Shaka supplies PR evidence and review;
it does not install a watcher, provide on-call coverage, or grant deployment or
rollback permission.

## Start with a project proposal

Ask your agent:

> Design an inactive release watcher using this project's existing checks and
> release conversation. Name the responder and backup, show what evidence is
> missing, and propose a separate activation PR. Rehearse on staging first.

Add your preferred observation window, release cadence, or incident channel when
the agent cannot infer them. Keep provider commands, alert thresholds, and recovery
instructions with the project. Supply scoped credentials from a secret manager.

## Keep three decisions separate

| Decision | Evidence |
| --- | --- |
| Merge the application change | Current-commit tests, review, walkthrough, and unresolved concerns. |
| Promote the release | The exact release range, current staging evidence, migration and dependency checks, and approval. |
| Close the observation window | Fresh post-deployment observations, responder handoff, and any recovery verification. |

A PR check passing does not establish deployment health. A successful deployment
does not establish that its observation window completed. Missing evidence stays
unverified; it cannot become a pass because the application appears healthy.

## Connect the PR to the release

Each PR should explain what an agent needs to exercise on staging: setup and
representative data, steps, expected results, permissions, and cleanup. Include
changed background jobs, public metadata, external integrations, and feature flags
when they affect the change. Record what ran and what remains unchecked.

At promotion, reconcile those plans across the release range. Preserve the
candidate revision, staging image, configuration, timestamps, and evidence links.
Invalidate checks when their relevant inputs change. Do not combine an earlier
candidate's browser result with a later candidate's passing build.

## Capture a baseline before changing anything

Record the current application images, workload health, worker polling and queue
age/size, and the error and performance windows used for comparison. Capture the
worker baseline before quieting or restarting workers; it cannot be reconstructed
reliably afterward.

Compare equivalent time windows and stable error groups. Show existing debt
separately from new degradation, without assuming every post-release error was
caused by the release. The project owns the thresholds and any explicitly allowed
baseline debt. Existing debt does not erase a failed required check.

## Keep observation and response durable

A CI job, supervised service, or other durable runner can own the timer. Serialize
conflicting promotions, or give each release isolated observations that can be
attributed correctly. An overlapping deployment can invalidate the comparison.
Choose the window from observed failure latency and acceptable release delay;
measure the runner cost rather than treating one duration as universal.

Bind the watch to its release and conversation. Report who responds, who takes
over, the acknowledgement deadline, and where the evidence lives. A delivered
mention is not a human acknowledgement. Define the backup's escalation path when
nobody acknowledges.

A notification failure should not stop independent collectors. Save the final
result before attempting delivery. Preserve missed samples and recovered failures
so a later healthy sample cannot silently erase a breach.

An always-run cleanup step cannot report after runner loss. Cancellation behavior
varies: [GitHub Actions re-evaluates conditions during cancellation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation),
with a bounded grace period. Test forced cancellation, timeouts, an independent
notification, and the responder's recovery path. If those are unavailable, state
the gap and keep an attended fallback until the handoff is proven.

## Rehearse before making it a release gate

Prepare the libraries and runbook without wiring them into production. Keep
activation separate so missing credentials or a failed installation cannot
unexpectedly block every release, including an urgent fix.

On staging, exercise the actual browser, credential scopes, collector commands,
conversation delivery, and responder acknowledgement. Test missing credentials,
a failed collector, delayed or stale evidence, notification loss, and cancellation.
Record real boundaries separately from simulated failures. Staging telemetry may
differ from production; name unsupported signals instead of borrowing production
measurements and calling them staging proof.

Rehearse recovery on staging with a saved baseline. Check data and migration
compatibility, queued payloads, feature flags, and outside effects. Restore
rehearsal data and configuration, then verify health again. Reverting application
images cannot undo sent messages, provider writes, or data mutations.

The activation PR should link that rehearsal, list remaining prerequisites and
their owners, and retain the project's deployment approval. A detected regression
can request a decision; it does not authorize an automatic rollback.

See [PR evidence](pr-verification.md) for reviewing the change and
[repository configuration](configure-repository.md) for Shaka's project-specific
PR policy. Store watcher credentials in the project's secret manager.
