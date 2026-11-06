# Review-scope judge prompt

This file pins the judge for the
[review-scope preregistration](../review-scope-preregistration.md). The judge decides
whether one review finding reports one of an item's known problems. Every scored call
sends the text under [Prompt](#prompt) with its three placeholders filled. A change to
that text or to the call below after the first priced call makes a new eval.

## Call

One call per finding. Each call is a fresh process that reads the prompt on standard input:

```bash
codex exec -s read-only --ignore-rules --ignore-user-config \
  -c skills.include_instructions=false --skip-git-repo-check --json \
  -m gpt-6.1-sol -c 'model_reasoning_effort="low"' -C EMPTY_DIR -o ANSWER -
```

- The flags match Shaka's own Codex reviewer, plus the model, the low effort, and the
  working directory. `--ignore-user-config` drops any configured model, so the model is
  named.
- `EMPTY_DIR` is a new empty directory outside every checkout, so the judge reads nothing
  but the prompt.
- The JSON events on standard output give the call's usage record.

## Inputs

- **Findings:** every numbered finding, of any class, from every Stage 1 run, and every
  positive control and same-PR near miss the preregistration's Decoys table names for the
  item. A finding's text is its numbered item from the report's Findings section, verbatim,
  without the leading item number.
- **Nothing else from a report:** no coverage section, attestation line, header, or any
  text the operator adds about the reviewer, model, round, cycle, cost, or arm.
- **Known problems:** the item's K items and its four cross-PR K items, one line each, as
  `- ID: TITLE`. `TITLE` is the finding's title from its ledger's Finding details line,
  without the finding id, class, disposition, link, or reporter. The null item lists only
  the four cross-PR K items.
- **Ids:** each known problem gets `k` and each finding `f`, followed by 8 random hex
  digits. Known-problem ids are generated once per item, so every call for that item shows
  the same list. The run record maps each id to its source. Known problems are listed in
  id order, so the order says nothing about which are decoys.

## Answer

- The answer is the last line of `ANSWER` that parses as a JSON object. Its `finding` must
  equal the call's finding id, and its `match` must be `none` or an id from the list.
- A call whose answer fails that check counts as a provider error under the
  preregistration's Retries rule: the identical prompt is sent once more. A finding still
  without a valid answer is unjudged. A K item whose window holds an unjudged finding is
  inconclusive, as a K item with an incomplete run is.
- The run record names this file's commit, the finding and known-problem ids, the answer,
  and the usage record.

## Prompt

The text between the two fence lines below, with `{{KNOWN_PROBLEMS}}`, `{{FINDING_ID}}`,
and `{{FINDING_TEXT}}` replaced. `{{FINDING_ID}}` appears twice.

```text
Below are the known problems in one change to a code repository, then one finding from a review of that change. Decide whether the finding reports one of the known problems.

The finding reports a known problem only when it names the same mechanism: the same faulty input, state, or statement leading to the same wrong result. The wording, the line numbers, the severity, and the suggested fix may differ. Sharing a file, a feature, or a topic is not enough. If the finding names several problems and one of them is a known problem, match that one. If more than one known problem could match, choose the closest. If none matches, answer none.

Known problems:
{{KNOWN_PROBLEMS}}

Finding {{FINDING_ID}}:
{{FINDING_TEXT}}

Reply with one line of JSON and nothing else, in this form, where match is one known problem id or the word none, and reason is one sentence:
{"finding": "{{FINDING_ID}}", "match": "<id or none>", "reason": "<why>"}
```
