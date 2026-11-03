# Compare usage and cost

Use cost reports to decide whether extra review or another implementation
attempt earned its cost. Compare similar tasks, with the same coverage:

```text
Compare these PRs' costs. What work does each include, what is missing, and
which reports overlap? What could we change to spend less next time?
```

## Read estimates as estimates

Dollar totals can mix list-price estimates, nominal costs, and reported account
charges. They are not an invoice. Codex plan credits and API-equivalent dollars
are different measures. Old reports retain their original pricing; current
provider prices may differ.

Unknown usage is not zero. A partial estimate can omit a reviewer, tool,
subagent, or an earlier part of the task. A `+` marks missing amounts or earlier
reports excluded from the total. Reports can also overlap, so adding totals
can count the same response twice.

<a id="what-the-columns-mean"></a>
<a id="compare-host-counters-carefully"></a>

## Avoid misleading token comparisons

Hosts count cache and reasoning tokens differently. Codex input includes cached
input; Claude Code input excludes cache reads and writes. Do not add cached
input to a Codex input count again. Ask the agent to normalize counters before
comparing providers.

<a id="how-estimates-are-priced"></a>

Paying for a review does not establish that it finished or was thorough. Check
its result separately. A timeout without usage metadata has unknown cost.

## Keep usage when work changes hands

Before switching chats or coding tools, ask:

```text
Save this task's usage on the PR before handing it over. State any shared
usage that cannot be attributed to individual commits.
```

Saved records let the next owner include earlier work. They cannot recover
usage that was never recorded. See [timings](timings.md) to compare elapsed time.

<a id="read-the-limitations-beside-the-numbers"></a>

<a id="understanding-usage-and-cost-reports"></a>
