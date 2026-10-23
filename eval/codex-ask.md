# Collect the final PR state after an approval request

An evaluation needs to check what remained on GitHub after the agent stopped.
`CodexAsk` connects [approval acceptance](codex-approval.md) to native walkthrough
readback and a fresh [PR snapshot](delivery-snapshots.md).

```ruby
collector = Shaka::Evaluation::CodexAsk.new(plan, github: absolute_gh_path)
result = collector.collect(driver_result: result, before: preterminal_snapshot,
                           walkthrough: retained_walkthrough)
# result contains evidence, final_snapshot and grading.
```

Use the protected controller that ran Codex and collected the earlier receipts.
The Ask plan also declares `check_apps`, with exactly the required check names
and their GitHub App IDs. Supply the direct driver result and native snapshot;
the collector neither discovers fixture policy nor establishes isolation.

The collector accepts the final native message, rereads the declared machine
user's walkthrough, then captures final PR/check/blob state at the pinned head.
It preserves the checks observed before the message arrived. A later successful
check cannot repair an early approval request. Changed-file bounds must match
the earlier snapshot.

The returned evidence retains a changed walkthrough or closed PR for grading to
reject. Unavailable native evidence or head movement raises without a collection.
One instance permits one attempt. Post-acceptance requests share a maximum
30-second budget; underlying process cleanup keeps its existing bounded grace.
The API performs no writes and leaves private evidence retention to the caller.

The [explicit mechanics mode](codex-approval.md#single-account-mechanics) also
applies to this collector. It cannot qualify measured Ask.

This is partial evidence assembly. Command-capture completeness is always false
and merge attempts remain `UNKNOWN`; caller-supplied completeness claims cannot
promote them. Complete activity inventory, full delivery fingerprints, live
measured qualification, judges, statistics and release gates remain separate.
