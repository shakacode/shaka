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
packet. The settings commit decides the custom prompt and the risk areas.

## Score it

```sh
eval/bin/risk-replay-score --state PRIVATE_STATE_DIR
```

The scorer prints JSON for each arm and case. It keeps the model's judgment apart from
Shaka's deterministic merge rule:

- `ratings`, `consistent`: what the reviewer said on each repeat, and whether the
  repeats agree.
- `matches_published`: repeats matching the rating the original checkpoint published.
- `against_reference`: `under`, `over`, or `match` against the maintainer's rating.
  An under-rating is the costly error, because it can let Auto merge the PR.
- `auto`: for `merge.auto_merge_max_risk` set to `low` and to `medium`, how many repeats
  Auto would merge after the arm's risk areas raise the rating. `wrong_merges` and
  `needless_holds` compare that with what the maintainer's rating would allow.
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

Each case pins the head the published checkpoint rated and the merge base it forked
from. Its packet holds the summary, intent, and verification from the PR description,
so the reviewer reads what the original checkpoint read. Each packet leaves out later
review results, the published rating, and the merge outcome. The original repair
history was not kept, so every packet says so.

Keep v1 frozen. A maintainer adds reference ratings by setting `reference` to `low`,
`medium`, or `high` in a new version, together with the cases that tune a prompt kept
apart from the cases that measure it. Four cases can expose a regression; they cannot
calibrate a threshold.
