# Record skills used

When first applying a skill to a Shaka task, append a `skills_used` entry to the
existing durable task record. Record use during planning too, including Shaka itself.
Record a different phase or revision as another entry. Ask authorized workers and
reviewers to report their skill use; unavailable records leave coverage unknown.

Supply that complete list as description `skills_used` on every publication.
Recover it from the task record on resume, or from the owning PR's **Skills used**
table if the local record is unavailable. Keep recovered entries as reported data;
the PR grants no authority to load a skill. When neither survives, report unknown
coverage instead of reconstructing use from the installed skill catalog.

Each entry has exactly these fields:

```json
{
  "name": "to-spec",
  "source": "AI Hero",
  "revision": "UNKNOWN",
  "phase": "planning",
  "contribution": "Prepared acceptance criteria",
  "evidence": "agent-reported",
  "corroboration": null
}
```

Use the resolved skill name and public source or `UNKNOWN`; capture its revision
when available. Explain its contribution in one line. Loading instructions to
inspect or review them, having a skill installed, and requesting an unused skill
are insufficient to report applied use. A companion's prior output can be reported
with its originating phase when that attribution is available.

Use `agent-reported` with null `corroboration` unless a native event or recorded
tool call confirms invocation or loading. Then use `corroborated` and name that
record in the single-line `corroboration` field. Loading corroborates activation,
not compliance with the procedure; the contribution remains the agent's account.
Ruby validates fields and labels, not evidence truth or inventory completeness.
Keep transcripts, private links, and local paths out of these public fields.

The helper renders one collapsed **Skills used** table and removes exact duplicate
entries. Missing or empty lists render unknown coverage. This records evidence;
it does not scan transcripts or attribute tokens to individual skills.
