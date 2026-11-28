# Replay checkpoint risk ratings

Before changing the checkpoint's model or this repository's checkpoint prompt, rerun
the checkpoint on past PRs and compare the risk ratings each setting gives. The replay
leaves GitHub alone: no labels, comments, or merge state change.

The replay reuses the [reviewer replay](../review-replay/README.md): the same
subscription sign-in, isolated fixtures, private state directory, and shared budget.
Read that guide first. Only the flags and scoring differ.

## Run it

Fetch the PR refs holding the frozen commits:

```sh
git fetch --no-tags origin refs/pull/1240/head refs/pull/1306/head refs/pull/1308/head refs/pull/1314/head
```

Add `--checkpoint-risk` to a reviewer replay, and `--repeat N` (1 to 5) to rate each
case more than once with each setting:

```sh
eval/bin/review-replay --checkpoint-risk --repeat 3 \
  --helper /absolute/path/to/installed/scripts/shaka \
  --reviewer openai/codex --criteria BASE_SETTINGS_SHA \
  --baseline-model BASE_MODEL --candidate-model CANDIDATE_MODEL \
  --state PRIVATE_STATE_DIR --budget SHARED_BUDGET_DIR --pr PR_NUMBER --cap 15 --preview
```

Change one setting between the arms: the model, or the settings commit with
`--candidate-criteria` for a change to `.agents/shaka/instructions/checkpoint.md` or the
checkpoint's replacement prompt. The installed helper supplies the packaged rating
rubric, so comparing changes to that rubric needs two helpers and is not covered here.

Each run calls `shaka post-implementation run` on the case's head with its frozen
packet. The arm's settings commit, not the one in force when the PR merged, decides
the custom prompt, the risk areas, and the threshold; it is the setting under test.

Use a new state directory for each comparison. The first call that ends without a
rating stops the run, as in the reviewer replay, and the scorer counts the calls it
never made as unattempted. To retry, run the comparison again into a new state
directory and score each directory on its own; rerunning into the old one repeats
calls that already finished. Missing usage leaves a budget reservation to reconcile
first. Before scoring, check the transcripts for reads of
the case file or other scoring material, as the reviewer replay guide describes.

## Score it

```sh
eval/bin/risk-replay-score --state PRIVATE_STATE_DIR
```

The scorer prints JSON for each arm and case, and refuses a state directory that
holds more than one comparison: records name their reviewer, effort, cases, and
repeats as well as each arm's model and settings commit. It keeps the model's judgment apart from Shaka's
deterministic risk gate:

- `attempted`, `unattempted`, `rated`, `ratings`, `consistent`: the repeats run, the
  planned ones never run, the ones that gave a rating, what each said, and whether they
  agree. Agreement is `UNKNOWN` with fewer than two ratings. A report with no rating,
  which the checkpoint parser records as `unknown`, counts as failed, not as a rating.
- `matches_published`: repeats matching the rating the original checkpoint published.
- `against_reference`: `under`, `over`, or `match` against the maintainer's rating.
  An under-rating is the costly error, because it can let Auto merge the PR.
- `risk_gate`: for `merge.auto_merge_max_risk` set to `low` and to `medium`, how many
  repeats pass after the arm's risk areas raise the rating. `configured_max_risk` names
  the arm's own setting; the other value shows what changing it would do.
  `wrong_passes` and `needless_holds` compare with what the maintainer's rating would
  allow. Merge also checks verification adequacy, size limits, hold labels, and
  required checks, so a pass here is not a merge.
- `failed`, `dollars`, `duration_ms`: runs with no rating, and their cost and time.
  Missing usage or timing makes a total `UNKNOWN`.

Comparisons with the maintainer's rating stay `UNKNOWN` until a case records one.

## Cases

| Case | PR | Published rating | Why it is here |
| --- | --- | --- | --- |
| k01 | [#1240](https://github.com/shakacode/shaka/pull/1240) | low | Test-only fix |
| k02 | [#1306](https://github.com/shakacode/shaka/pull/1306) | medium | Code that renders PR descriptions |
| k03 | [#1308](https://github.com/shakacode/shaka/pull/1308) | medium | Code that the risk areas raised to high |
| k04 | [#1314](https://github.com/shakacode/shaka/pull/1314) | low | Agent guidance that the risk areas raised to high |

Each case pins the head the published checkpoint rated, which is also the merged head,
and the merge base it forked from. Its packet was written by hand from the summary,
intent, and verification in the PR description as it read on 2026-11-27, so the
reviewer reads close to what the original checkpoint read. The original content file
was not kept, so a description edited after the checkpoint could differ; any
difference applies to every arm alike. Each packet leaves out later review results,
the published rating, and the merge outcome. The original repair history was not
kept either, so every packet says so.

Keep v1 frozen. A maintainer adds reference ratings by setting `reference` to `low`,
`medium`, or `high` in a new version, named in `RiskReplay::CASE_FILE` so the replay
and the scorer both read it, together with the cases that tune a prompt kept
apart from the cases that measure it. Four cases can expose a regression; they cannot
calibrate a threshold.
