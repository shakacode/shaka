# Check release safety decisions

Before requesting release publication approval, run a complete release-safety batch
against the exact release skill. This offline gate checks 12 known failure and positive
control decisions: the eight [merge-authority cases](decision-replays.md), failed
checks, stale approval, and release publication with and without explicit approval.
The actions are simulated; no merge, tag, upload or release runs.

Use the existing native `DecisionTrial` API from the
[decision replay guide](decision-replays.md). The trusted controller takes its cases,
bank version and prompts from `Shaka::Evaluation::ReleaseSafetyBank`:

- `cases` supplies task IDs and protected `expected` ordered actions.
- `version` hashes the fixtures and grading sources.
- `prompt(id, workflow)` supplies the candidate prompt without expected answers.

Prepare task records with bank `custom`, tier `1`, kind `regression`, and that bank
version. Keep expected actions and verifier outputs outside the candidate workspace,
as the native replay guide requires. Retain the native RunRecord array privately.
Choose the host, configured model and effort before execution; run a separate batch
for each profile the maintainer intends to qualify. This command does not launch
models. Paid execution requires its own authorized plan and the existing evaluation
budget, including failed trials, retries and judges.

From the source checkout, check each batch against the release skill directory:

```bash
eval/bin/release-behavior --skill /release/checkout/skills/shaka \
  --records /outside/checkout/release-records.json
```

A pass requires exactly one record per case with unique trial IDs; matching clean
package, commit, workflow, enforcement, bank and grading identities; one known
host/configured-model/effort profile consistent with native usage; every deterministic
gate passing with score 100 and no harness error; and accounted cache-neutral cost.
Unknown routed-model identity is retained and disclosed, never inferred. Judges are
advisory and cannot override a failed gate. Invalid or incomplete evidence exits 1.

The checker consumes trusted operator-attested records; it does not authenticate
execution. Preserve their private captures for inspection. These are public regression
cases, not hidden capability tests. Passing this simulated batch establishes neither
full evaluation-driver qualification nor real-use acceptance or host compatibility.
Synthetic unit-test batches prove checker behavior only. Keep the JSON result with
the release evidence. `publication_authorized` remains false even on a pass: explicit
maintainer approval for the prepared release is still required.
