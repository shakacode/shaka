# Hosted Claude review prompt: before #640 against now

Question: on 17 commits where hosted Claude reported `FINDINGS 0` and CodeRabbit later led to a code bug fix, how many of those bugs does each prompt report, and how many other findings does it raise?

Inputs: 22 CodeRabbit threads (21 bugs; #902's one bug is two threads on two commits) on 17 commits and 16 PRs, frozen in `gold.json`. Prompts: `.github/workflows/claude-code-review.yml` at `889364ff^` (before #640) and `84525c74` (now), byte for byte with only workflow expressions filled in. Each run sees the hosted job's own integration commit as a one-commit tree, `gh pr diff` frozen to that commit, and `gh pr view` frozen to the PR body and local-review comments as of the hosted report's timestamp. CodeRabbit comments and earlier Claude reports are withheld. Comments go to files; nothing reaches GitHub.

## Bars
- Replay validity: arm Q reports `FINDINGS 0` on at least 50% of its runs (hosted Claude reported 0 on all of these). Below that, the replay does not reproduce the hosted job, and the article says the comparison measures the prompts only under replay conditions.
- Replay cost match: mean turns and cost per Q run within 3x of the hosted job's (5.3 turns, $0.11). A miss on the pilot stops the run before the full set.
- Scorer accuracy: at least 90% correct on decoys across all packets. A miss means re-score with a hand audit before any result is reported.
- Loosen the criteria: arm P finds at least 5 more of the 21 bugs than current-at-full-depth (arm R on 12 commits, arm Q on the 5 commits that were already full), and bugs only P found outnumber bugs only current-at-full-depth found by at least 3 to 1. A miss means the strict criteria are not shown to be the cause.
- Change the short pass: current-at-full-depth finds at least 5 more of the 21 bugs than arm Q. A miss means the short pass is not shown to be the cause.
- If neither bar is met: recommend keeping the prompt. The noise count (other findings per run, split real, nit, unconfirmed) goes beside any recommendation to loosen, and a recommendation to loosen must name the wording to change.
- A bug counts as found by an arm when at least 1 of its 3 runs has a `match` finding. Report k/3 per target. Report totals with and without the 4 targets already named in the local report the run could read, and with and without the 3 that need a fact from outside the repository.

## Arms
- P: `claude-sonnet-5-5`, CLI default effort, prompt before #640, 3 runs on all 17 commits (51 runs). About $0.11 per run from hosted logs.
- Q: `claude-sonnet-5-5`, CLI default effort, current prompt at the depth the hosted job chose for that commit (12 shaka, 5 full), 3 runs on all 17 commits (51 runs). About $0.11 per run from hosted logs.
- R: `claude-sonnet-5-5`, CLI default effort, current prompt forced to `REVIEW DEPTH: full`, 3 runs on the 12 shaka-depth commits (36 runs). About $0.11 per run from hosted logs.
- Scorer: `claude-opus-5-5`, one packet per commit, read-only tools, blind to which prompt produced each review. About $1 per packet, estimated.

## Decoys
Each of the 17 scoring packets carries 2 decoy reviews under the same random codes. One restates a known bug from that commit (must score `match` to that bug). One restates a bug from a different PR (must not score `match`). 34 decoys. A pass shows the scorer can recognize a bug and does not match on topic alone.

## Stop rules
- Spend cap $50 at the CLI's reported cost: $30 for reviews (enforced by `run.rb --cap`), $20 for scoring.
- Pilot first: 3 commits, all arms, 1 run each. A missed cost-match bar, a run that reaches a real `gh`, or a shim failure stops the run and reports. Pilot runs count as rep 0 if nothing changes afterward; any change to prompts, tools, or scoring after the pilot makes this a new preregistration.
- Stop on a usage-limit error rather than retrying into it.

## Held-out exposure
| set | prior exposure (which runs, which models) | reservation (what this run may read) |
| --- | --- | --- |
| none | No held-out set. The 17 commits were selected from the #1016 study, which is the source of the selection bias reported as a limit. | All 17 commits are read. |

## Blinding
Fixture root is `.../wk/<random>/shaka`, a one-commit tree with a neutral commit message; prompts and tool names carry no eval words beyond what the two workflow prompts themselves contain. The scorer sees random `R####` codes, with depth lines and SHAs removed. Prose style may still hint at the prompt; the scorer is not told prompts differ. After unblinding, the agent audits the scoring: it rereads every `match` and a sample of 20 `other` findings against the code.

## Limits accepted in advance
- Selection: commits were chosen because the current prompt found nothing and CodeRabbit found a bug. That favors any rerun over the original result and says nothing about bug-free commits, so noise is measured only on commits that had a bug.
- Local CLI (2.1.312) rather than the action; a current prompt on an older commit; a checkout path and tool set that match the hosted job but not its runner.
- Runs bill to the maintainer's Claude subscription (the CLI reports `apiKeySource: none`); dollar figures are the CLI's API-equivalent numbers.

## Deviation recorded after unblinding
The preregistered audit found a defect in `score.rb`. Its header scrub used a case-insensitive pattern that also removed every review line containing "review" or "preview", including finding text. No scorer output from that pass is used for results. The fix changes only the scrub, which now removes the attestation line and the depth and SHA phrases. The scorer instructions, gold list, decoys, bars, and reviews are unchanged. The first pass stays in `score-out-v1`. The agent had seen unblinded first-pass results before fixing it; the scorer remains blind.
