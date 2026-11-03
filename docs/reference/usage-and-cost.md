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

Input counts tokens sent to the model; output counts tokens generated.
Cached input was read from an earlier prompt cache. Cache writes store input
for later reuse. Reasoning can already be part of output, so adding every
column can count the same tokens twice.

| Host | Input includes | Output includes |
| --- | --- | --- |
| Codex | Cached input | Reasoning |
| Claude Code | Neither cache reads nor writes | Reasoning |
| Cursor | Cache reads and writes | Reasoning is unreported |
| OpenCode | Neither cache reads nor writes | Reasoning is separate |
| Pi | Neither cache reads nor writes | Reasoning |
| OpenRouter | Cached input | Reasoning |

For example, 100,000 Codex input tokens with 80,000 cached tokens means 20,000
uncached tokens. Do not add cached input again. Ask the agent to normalize
counters before comparing providers. Token totals are not summed across hosts.

<a id="how-estimates-are-priced"></a>

Read each report's pricing note before comparing dollars. OpenAI reports
distinguish Codex plan credits from API-equivalent USD; Cursor estimates use
on-demand list prices. Pi preserves nominal recorded cost, while OpenRouter
uses the response's reported account charge.

Anthropic prices uncached input, cache reads, and cache writes separately.
A one-hour cache write costs more than a five-minute write. Fast-mode responses
need a published rate; unsupported models or billing categories stay unpriced.

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
