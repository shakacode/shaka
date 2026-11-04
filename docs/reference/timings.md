# Understanding PR timings

A PR's **Timings** section, just below **Usage and cost**, shows where the
PR's time went. It separates the stretches when the agent was working from
the stretches when the PR was waiting for you. Use it to see how long each
checkpoint took to reach and how long each one waited for a person to respond.

Here is an example:

| Stretch | From | To | Time |
| --- | --- | --- | ---: |
| Before the pull request | 2026-10-18 07:54 | 2026-10-18 08:26 (opened) | 32m |
| Between checkpoints | 2026-10-18 08:26 | 2026-10-18 09:54 | 1h 28m |
| Waiting on a person: answer | 2026-10-18 09:54 | 2026-10-18 19:36 (resumed) | 9h 41m |
| Between checkpoints | 2026-10-18 19:36 | 2026-10-18 21:54 | 2h 18m |
| Waiting on a person: merge approval | 2026-10-18 21:54 | 2026-10-18 23:15 (merged) | 1h 21m |

The section opens with totals for both kinds of time, for example
`Totals: 4h 18m between checkpoints · 11h 2m waiting on a person in 2 waits`.
The first total includes the time before the PR opened.

## Read the bars

Above the stretches, a chart puts the PR and its measured steps on one time axis:

```text
10-26 01:16 to 10-27 01:57 PDT (1d 0h)
                          01:16        02:47        22:54        00:25
PR                23h 6m               =.===.//19h//......====....============
Validation         2h 5m  ####       ### ### //            x xxx     xx #####
Review anthropic     13m     x # #   #   ##  //            # #       #
Review openai        28m     x # xx  #   x#  //                      #
Checkpoint        2m 54s                #   #//                    ##       ##

- before the PR  = PR open  . waiting on a person  # step  x failed  // idle wait cut
```

- **Where the time went:** the number beside each lane adds up its runs. The PR lane's
  number is the time from its first stretch to its last.
- **When something ran:** read the clock times above the bars. The first line gives the
  dates and the time zone.
- **What ran at the same time:** marks in the same column overlapped. Each reviewer
  provider gets its own lane.
- **When the PR opened and waited on you:** on the PR lane, `-` turns to `=` when the PR
  opens, and `.` marks a wait.
- **What failed:** `x` marks a validation that failed or a review or checkpoint that
  did not finish. Those steps keep a row in the table below, with their exit codes.

A wait that fills more than a quarter of the timeline with nothing running is cut from
the axis, so one long night does not flatten everything else. `//19h//` on the PR lane
says how much idle time was removed, and `//` crosses the other lanes at the same
place. Clock times jump across a cut. A wait with a step running during it is cut only
around that step, so the label can be shorter than the wait.

Each column covers the same length of time, so a run shorter than a column still takes
a full one. A blank cell separates back-to-back runs, which can make a run look a column
shorter. When two runs share a column in one lane, the later one shows. The table below
still lists a failure that a retry drew over.

## Time to ready and merge

The model line at the top of the description ends with the AI spend. Under
Shaka metrics, the estimated cost adds how long the work took from the recorded
task start once that is known: `ready in 1h 19m` while the PR is open, then
`merged in 3h 24m`.

The Timings section breaks that down for the current head. Prompt to CI runs
from the task start to the head's earliest check. CI to ready runs from that
check until the head's required checks and configured CI reviews are green.
Ready to merged runs from then until the merge. After a new push, the intervals
measure the new head. `pending` is not known yet. `UNKNOWN` was not established,
such as a ready time no update recorded before the merge. Neither means zero.

## What each stretch means

| Stretch | Starts | Ends |
| --- | --- | --- |
| Before the pull request | Recorded task start, or the PR's first commit when unavailable | The PR opens |
| Between checkpoints | The PR opens, or a wait ends | The next wait starts, the PR merges or closes, or this update |
| Waiting on a person | The agent asks for your answer, your merge approval, or a manual resume | The agent resumes, or the PR merges or closes |

The task start comes from the agent, or otherwise from the earliest implementation
usage report that covers the whole task, and is retained across description
updates. Shaka uses it to include planning and implementation before the first commit. The
**Before first recorded validation** interval shows the elapsed wall-clock time
from that start to the earliest recorded validation run, including a focused test.
It overlaps the stretches and is not added to the totals again. Missing start or
validation records are reported as unavailable.
If a validation timestamp predates the reported start, the interval is unavailable
and description publication continues.

Shaka reads PR opening, closing, commit and label times from GitHub every time it updates the description. A
wait is the time one of the attention labels stayed on the PR:
`awaiting-answer`, `awaiting-merge-approval`, or `awaiting-resume`. The agent
adds a label when it stops for you and removes it when work resumes.

## Read the limits

- Times are wall-clock time in the [configured time zone](../settings.md#pr_descriptiontime_zone),
  UTC by default, and include nights and weekends.
- A wait ends when the agent resumes, which can be slightly after you replied.
- Time between checkpoints includes the agent's work, checks running, and any
  wait the agent did not mark with a label.
- Without a recorded task start, the timeline starts at the first commit and
  excludes earlier work. A rebase can move that date; when it falls after the PR
  opened, the first row is omitted.
- Ruby checks the task start's timestamp and order, but does not verify when work
  actually began. A start read from a usage report is the agent's first response in
  that report, moments after the request. A task that moved to a new chat before
  its PR opened shows only the new chat's time.
- The ready time appears once a description update or a watch sees the gate green,
  so it can be missing until the description next updates. It stays missing when
  the configured CI review did not run, such as a review skipped for a small change.
- Every labeled wait counts, however short. A wait of a few seconds can be a
  quick reply or the agent relabeling the PR; the label history cannot tell them apart.
- When a PR has waited many times, the table shows the latest 30 stretches. The
  totals still include every stretch.
- The description shows timings as of its last update. The agent asks for your
  merge approval after that update, so when you merge on GitHub yourself, the
  final wait appears only if the agent updates the description again.

If GitHub cannot supply the timeline, the section says so and the rest of the
description still publishes. The next update tries again.

## Measured steps

Below the stretches, the section adds up each kind of step, for example
`Measured steps: Validation 13m (1 run) · Local review 58s (1 run)`. With the bars,
a second line names the models and machines that ran them. The machine reads
`UNKNOWN` when `SHAKA_MACHINE_ALIAS` is not set; setting it is described in
[Getting started](../getting-started.md).

Steps that passed or finished appear only in the bars. A step that did not gets a
row with its exit code. A validation run reads `failed`. A review or checkpoint reads
`not completed`, because its result says only whether it finished; its findings and
recommendation are in its own PR comment.
For example:

| Step | Started | Time | Result | Model | Machine |
| --- | --- | ---: | --- | --- | --- |
| Validation: validate | 2026-10-18 08:05 | 13m | failed (exit 1) | — | m5 |
| Local review | 2026-10-18 08:20 | 58s | not completed (exit 1) | openai · gpt-6.1-sol · medium | m5 |

If the bars cannot be drawn, the section lists every step in this table instead, and
the rest of the description still publishes.

The steps come from Shaka's timing log on the machine that ran them. A step
belongs to the PR when it reviewed one of the PR's commits, or, for a validation
run, when it tested exactly the files a commit holds. Each description update keeps
the steps earlier updates published, so steps from another session or machine
stay listed.

Limits:

- A step overlaps the stretches above. A validation run during a wait, for
  example, appears in both.
- A validation run of files never committed, such as a failing run before a
  fix, is not listed.
- A rebase replaces the PR's commits. Steps logged against the old commits stay
  listed only if an update published them before the rebase.
- Only the PR's latest 100 commits are matched.
- On a PR from a fork, whose author can edit its description, earlier updates'
  steps are not kept. Only steps logged on the machine making the update appear.
- The description keeps the latest 50 steps, and the bars and totals cover only
  those. The table shows the latest 30 of its rows. The section notes either cut.
- A step logged on a machine that never updated the description afterward is
  missing, so treat the totals as what was recorded, not the whole task.
- The earliest recorded validation time survives the step retention limit once
  published. If older steps were already dropped before that time was saved,
  the interval stays unavailable.

[Usage and cost](usage-and-cost.md) explains the section beside it.
