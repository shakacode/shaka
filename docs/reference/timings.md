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
