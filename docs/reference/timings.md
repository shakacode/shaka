# Learn where a task's time went

Use timing reports to find work worth improving, such as repeated validation
runs or a slow review. Ask about the task rather than decoding its chart:

```text
Where did this task spend time? Separate work, waiting on me, and repeated
checks. Which delay could we reduce next time?
```

## Compare runs fairly

Compare similar tasks and note the machine, load, and checks each ran. A slower
run on a busy machine does not establish a regression. Parallel reviews can
finish sooner than their durations added together.

Recorded times are wall-clock intervals, including nights and weekends. A wait
for a person follows attention labels; it is not a measure of their active work.
Unmarked waits can appear as work between checkpoints.

## Understand the measurements

| Interval | Measured from → to |
| --- | --- |
| Ready in | Recorded task start → observed readiness of the current commit |
| Merged in | Recorded task start → merge |
| Prompt to CI | Task start → current commit's earliest check |
| CI to ready | That check → observed passing required checks and configured CI reviews |
| Ready to merged | Observed readiness → merge |
| Before first recorded validation | Task start → first recorded validation, including focused checks |

The validation interval overlaps the timeline; do not add it again.
After a new push, the ready intervals describe the new commit.
`pending` means not known yet; `UNKNOWN` means no suitable record, not zero.
Readiness can remain unknown when a configured CI review did not run or no
update observed the gates passing.

Before the PR opens, the timeline starts at the recorded task start, or the
first commit when that start is missing. Between checkpoints runs from opening
or the end of a labeled wait to the next wait, closure, merge, or update.
A person's wait follows an attention label until the agent resumes or the PR
closes or merges.

An idle cut such as `//19h//` removes nineteen idle hours from the chart's axis.
Clock labels jump across it; the recorded elapsed duration still includes that time.

## Check coverage before drawing conclusions

The task start is agent-reported. Missing starts omit earlier planning; missing
updates or records can omit readiness, steps on another machine, or the final
wait before a manual merge. Retention limits can exclude older steps.

```text
What time is missing from this report? Did retries, parallel steps, or a
handoff change what the totals cover?
```

Treat unknown time as unknown, rather than zero. Use the
[time-zone setting](../settings.md#pr_descriptiontime_zone) if displayed times are
hard to compare with your working day. For spend, see [usage and cost](usage-and-cost.md).

<a id="time-to-ready-and-merge"></a>
<a id="what-each-stretch-means"></a>
<a id="read-the-bars"></a>
<a id="measured-steps"></a>
<a id="read-the-limits"></a>

<a id="understanding-pr-timings"></a>
