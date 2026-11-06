# Full-diff or new-commits re-review: preregistration

*An AI agent wrote this preregistration: Claude Code running Claude Opus 5.5, on 2026-11-06
(UTC). It made no paid model calls. Every number below comes from published review data, Git,
or stub reviewers that cost nothing. Nothing here is a result about review quality.*

**Status:** preregistered, not run. The maintainer approves the priced pilot before any paid
call.

## The question

- The [review signal report](https://github.com/shakacode/shaka/blob/146a46a5328d9b09660b9b37be3ca571280efd7a/eval/reports/review-signal.md)
  ([PR #1066](https://github.com/shakacode/shaka/pull/1066)) checked 40 fixed findings. All
  were real and came from their own PR. 58% of fixed defects were first reported in cycle 1.
- In its sample, 11 of 17 later-cycle findings sat in code written during the review loop.
  The other 6 sat in code the first cycle had already seen.
- Reviewer spend was $2.38 per fixed defect. The report recommends keeping the two-reviewer
  loop. Its weakest claim is that full-diff re-review beats a diff-only re-review. Nobody has
  measured the implementing agent's cost per cycle or the defects a diff-only review misses.
- This eval compares two re-review policies on the same PRs and the same reviewers:
  - **A, full diff (today):** every cycle reviews `git diff MERGE_BASE...HEAD`.
  - **B, new commits:** cycle 1 reviews the full diff; each later cycle reviews only the
    commits since the previous reviewed head.
- Per arm it measures the known fixed defects found and missed, and the total cost after
  cycle 1. Total cost includes the implementing agent's triage, fix, and validation tokens
  and time, not only reviewer spend.
- The answer decides whether a later PR adds new-commits re-review as a setting, or whether
  Shaka keeps full-diff re-review with this evidence on record.

Terms follow the report. A *cycle* is one reviewed commit. A *run* is one reviewer on one
commit. *K* is the set of known fixed findings an item can be scored against.

## Two stages

| Stage | Design | What runs | What it measures | Needs |
| --- | --- | --- | --- | --- |
| 1 | R, reviewer replay | Both reviewers under each arm at every later historical cycle. No implementer. | K found and missed; reviewer cost; findings per cycle | Today's Shaka |
| 2 | L, live loop | The implementing agent runs the loop from the first reviewed commit under each arm | K missed at each arm's final head; total cost and time after cycle 1 | A prototype helper, and Stage 1 passing |

- Stage 1 is cheap and answers the safety question first. A failing safety bar ends the eval
  before the expensive stage.
- Stage 2 answers the cost question the report left open. Its arms fork after a shared live
  cycle 1, because both policies review cycle 1 the same way.

## Arms

| Role | Model id | Settings | Price per MTok (in/out) | Historical cost per run, billed / cache-neutral |
| --- | --- | --- | --- | --- |
| Reviewer | `claude-opus-5-5` | `anthropic/claude` through `shaka review run`, Claude CLI default model and effort | $4 / $20 | $0.24–$0.61 / $0.55–$1.00 |
| Reviewer | `gpt-6.1-sol` | `openai/codex` through `shaka review run`, Codex CLI default under `--ignore-user-config` | $2 / $10 | $0.07–$0.14 / $0.29–$0.69 |
| Implementer, Stage 2 | `claude-opus-5-5` | Claude Code 2.1.318, effort high, Shaka at the pinned prototype commit, `--max-budget-usd 20` per session | $4 / $20 | $3 per fixing cycle, $1 per clean cycle, billed (assumption below) |
| Judge | `gpt-6.1-sol` | `codex exec -s read-only`, effort low | $2 / $10 | about $0.035 per call |

- Both arms use every component above unchanged. The arms differ in one thing: the diff the
  reviewers receive from cycle 2 on.
- Every run goes through one pinned Shaka helper commit: the trusted `main` commit at pilot
  start for Stage 1, and the prototype commit below for both Stage 2 arms.
- Reviewer costs come from the pilot items' own published runs (the execution tables in the
  [#810](https://github.com/shakacode/shaka/pull/810#issuecomment-6314326001),
  [#902](https://github.com/shakacode/shaka/pull/902#issuecomment-6479167788) and
  [#954](https://github.com/shakacode/shaka/pull/954#issuecomment-6489963059) review
  comments). Cache-neutral prices all input at the base rate, as
  [ADR 0001 D12](../../internal/adr/0001-eval-and-release-gating.md#d12-cost-accounting)
  requires for comparisons. Billed uses cache rates; `lib/pricing.ts` in gstack excludes cache
  writes, so billed figures are Shaka's own published estimates.
- The implementer assumption comes from three published usage tables. Whole-PR implementation
  cost divided by reviewed commits gives $1.84
  ([#1024](https://github.com/shakacode/shaka/pull/1024), 5 commits), $3.74
  ([#1045](https://github.com/shakacode/shaka/pull/1045), 7) and $2.70
  ([#954](https://github.com/shakacode/shaka/pull/954), 4 across two ledgers) per cycle.
  Each includes the first build, so each is an upper bound. The split between first build and
  loop work is unmeasured; measuring it is Stage 2's job.
- #1024's implementation cost is 10.7 times higher cache-neutral than billed. The pilot table
  uses that ratio for the implementer.

### How each arm is produced

- **Stage 1:** each run is `shaka review run --root FIXTURE --head CK --criteria-ref MAIN
  --description-file DESC` without `--ledger`, where `MAIN` is the fixture's `main` described
  below. Arm A passes `--base MERGE_BASE`; arm B passes `--base C(K-1)`. `DESC` is identical for both arms: the PR title, then the earlier findings
  (id, class, summary, disposition) first reported before cycle K, built from each round's
  **Collated as** line. Without a ledger, neither arm gets the ledger's "confirm each fix"
  instruction or commit list; the earlier findings reach both through `DESC`.
- **Stage 2:** arm B needs a prototype. The stub dry run showed that today's ledger refuses
  arm B's second round: "The ledger's rounds measure the change against 4925daa13ac6…; use a
  new ledger." The prototype is a pinned, unmerged helper commit with a scope choice for
  `review run --ledger`. With the scope at full diff, it must render byte-identical prompts to
  the trusted helper; arm A uses that. Arm B sets the new-commits scope, which embeds
  `git diff PREVIOUS_REVIEWED_HEAD..HEAD` from cycle 2 on. Both scopes keep the
  earlier-findings list, the round cap, and returned-after-fix detection.

## Items and fixture

### Pilot items (development rows)

The pilot items come from the report's sample, which this plan's author had already read.

| Item | Why | Reviewed commits | K (first reported, fixed at) |
| --- | --- | --- | --- |
| [#810](https://github.com/shakacode/shaka/pull/810) | Defect in text the first cycle saw, found in cycle 2 | 4: `24180a9` `450b4fa` `7da26fc` `86f3cda` | F4 defect (2, 3); F5 risk (2, 3) |
| [#902](https://github.com/shakacode/shaka/pull/902) | Long loop; defects found in cycles 3 to 5, one of them in code cycle 1 saw | 6, as rebased before push; the rebased commits form one chain: `97de0d1` `4d301a4` `5e00bf9` `5aec7cb` `aaeef20` `cc11931` | G10 defect (3, 5); G11 risk (4, 5); G14 defect (5, 6) |
| [#954](https://github.com/shakacode/shaka/pull/954) | Median two-cycle PR; nothing fixed after cycle 1 | 2, first of its two ledgers: `048b110` `db8e38f` | none (null item) |

Full SHAs are in the review comments linked above. Every reviewed commit is fetchable from
`refs/pull/N/head`; the dry run checked all 12.

### Full-run items (held out)

- **Eligible:** a ledger in the report's snapshot (500 ledgers, 2026-10-15 to 2026-11-05) with
  at least three reviewed commits, every reviewed commit fetchable, and at least one fixed
  defect or risk first reported at cycle 2 or later.
- **Also required:** each reviewed commit is an ancestor of the next, and the PR changes no
  `AGENTS.md` and nothing under `.agents/shaka/`. The fixture's `main` below replaces those
  files, so a PR that changes them would show its final version.
- **Excluded:** every PR the review signal report names, and the three pilot items.
- **Draw:** sort eligible ledgers by the SHA-1 of `PR:LEDGER_MARKER` and take the first 25 for
  Stage 1. Stage 2 takes the first 10 of those 25, in the same order.

### Fixture

- Each run gets a repository built from a Git bundle with two branches and no remote:
  - the historical head branch name at the reviewed commit, holding only its ancestry;
  - `main`, one commit on the item's merge base that replaces the root `AGENTS.md` and
    `.agents/shaka/` with the trusted `main` copies pinned at pilot start. No other file
    changes, so no later code enters the fixture.
- The dry run found two leaks this layout closes. A plain local clone carries 725 refs,
  including `origin/main` with #902's merged fix, which a read-only Codex reviewer could read.
  And `--criteria-ref MERGE_BASE` fails on #810: the current helper refuses its older settings
  ("review.post_implementation moved to the top-level checkpoint section").
- `main` serves as `--criteria-ref` in Stage 1 and as the trusted ref for `seam check` in
  Stage 2. Both arms get the same criteria.
- The checkout lives at `/Users/justin/claude/shaka-worktrees/<PR>`, the layout the historical
  reports show. The prompt names this path, and the dry run's scratch path leaked the word
  `fixtures` into it.
- Stage 2 starts from the first reviewed commit. Its goal file holds the PR title and the
  linked issue's first paragraph, if one exists, and no finding text.

## Scoring

### Stage 1

- **Window:** a K item can be found at any cycle from 2 up to the cycle where history first
  reported it. From the next cycle on, its summary is in the earlier-findings list both arms
  receive, so a later match would repeat history rather than discover it. A defect introduced
  at cycle j cannot be found before j by either arm, so the window does not favor one.
- **Found by an arm:** any run of that arm inside the window reports a finding that the judge
  matches to the K item.
- **Judge input:** one finding at a time, with the item's K list plus decoys, under opaque ids.
  The judge never sees the arm, reviewer, model, cost, or run number.
- **Cost:** each run's usage record from `review run`, in both D12 figures.

### Stage 2

- **K for an item:** the historical fixed defects and risks whose cited code exists at the
  first reviewed commit, minus those the shared live cycle 1 fixed.
- **Missed by an arm:** the K item is still present at that arm's final head. When the
  historical fix added a test, run it at the final head; otherwise a verifier reads the code.
- **Escape audit:** at each arm's final head, both reviewers review the full diff once more,
  outside the loop. A fresh verifier session checks each defect and risk with the review
  signal report's procedure. It sees heads labelled `P` and `Q`, never the arm.
- **Cost after the fork:** the implementer's native session usage, every reviewer usage record,
  validation runs and their time from `shaka evidence run`, and wall-clock time from fork to
  loop end. The implementer's own summary of its work never counts.

## Bars

| Metric | Pass bar | Direction | A miss means |
| --- | --- | --- | --- |
| P1 pilot completeness | Every attempt ends `completed` or recorded `not_completed` with a reason; at most 1 retry each; every attempt has usage | all | Fix the harness; a changed frozen element needs a new preregistration |
| P2 pilot scorer | The judge bars below hold on the pilot's controls | higher | Stop; found counts are void |
| P3 pilot harm signal | `b - c` below 2 over the 5 pilot K items, with b and c as in R1 | lower | Stop and recommend keeping full diff; no full run |
| P4 pilot spend | Actual spend within the pilot cap; full-run projection within the cap the maintainer approves | lower | Stop; recompute with fewer items or ask for a different cap |
| R1 Stage 1 safety, primary | `b - c <= max(1, ceil(0.10 * size(K)))`, where b counts K items A finds and B misses, and c the reverse | lower | Keep full-diff re-review; Stage 2 does not run |
| R2 Stage 1 reviewer cost | Geometric mean of per-cycle B/A, cache-neutral, at most 0.80 | lower | Reported; Stage 2 still decides value |
| R3 findings per later cycle | Paired B/A ratio | report only | Predicts triage load for Stage 2 |
| J1 judge positive controls | At least 90% of historical reports collated to a K item are matched to it | higher | Stop; scorer below its bar |
| J2 judge cross-PR decoys | 0 matched | lower | Stop; scorer below its bar |
| J3 judge same-PR near misses | At most 1 in 10 matched | lower | Stop; scorer below its bar |
| L1 Stage 2 safety, primary | Same rule as R1, over Stage 2's K | lower | Keep full-diff re-review |
| L2 Stage 2 total cost, primary | Geometric mean of per-PR B/A post-fork cost, cache-neutral, at most 0.75, and its 95% bootstrap upper bound below 1.00 | lower | Keep full-diff re-review; the saving does not pay for a setting |
| L3 time after the fork | Geometric mean B/A | report only | Supports or weakens L2 |
| L4 loop-introduced escapes | B's verified escapes exceed A's by at most 2 over 10 PRs | lower | Flag to the maintainer with each escape |

**Decision:** recommend new-commits re-review only when R1, L1 and L2 all pass. A failed R1
or L1 keeps full diff. With safety passing, a geometric mean above 0.75 also keeps full diff.
A mean at or below 0.75 whose upper bound reaches 1.00 is inconclusive, and the maintainer
decides. A third stage needs a new preregistration.

## Decoys

| Decoy | Count in pilot | How made | A pass proves |
| --- | --- | --- | --- |
| Positive controls | 7 | The historical reports collated to each pilot K item: #810 round 3 (#1 to F4, #2 to F5); #902 rounds 5 and 7 (G10), 8 (G11), 9 and 10 (G14) | The judge recognizes the same problem in different words |
| Cross-PR K items | 4 per item | Fixed findings from unrelated sampled PRs added to each item's K list: #1024 F2, #916 F1, #634 F1, #860 F1 | The judge matches by mechanism, not by topic |
| Same-PR near misses | 10 | The pilot PRs' own unfixed findings on the same files, judged against K: #902 G2, G3, G4, G5, G7, G8, G9; #810 F2, F3, F6 | The judge separates a different problem in the same file |
| Null item | 1 | #954, with K empty | The pipeline invents no K item; any credited find there is a scorer error |
| Verifier decoys, Stage 2 | 3 | Dismissed findings with recorded disproofs (#902 G2, G3; #810 F2) given to the escape-audit verifier as findings | The verifier rejects a plausible false claim |

The full run uses the same recipe on its own items: every collated report of each K item, four
cross-PR K items, and every unfixed same-file finding.

## Blinding

- **Fixture root:** `/Users/justin/claude/shaka-worktrees/<PR>`; state under
  `/Users/justin/claude/shaka-state/<PR>/`. Neither path holds an eval word.
- **What candidates read:** the rule's words (`eval`, `test`, `judge`, `experiment`, `rubric`,
  `score`, `compare`, `benchmark`, `candidate`, `arena`) appear in none of the paths, goal text,
  implementer prompts, or retry prompts the eval writes. The dry run checked this.
- **Allowed exceptions:** `test` appears in two #902 finding titles about the project's own
  tests. All the words appear in the repository's own `AGENTS.md` and in Shaka's review prompt.
  That text is the project's own and identical in both arms.
- **Network:** Codex reviewers run with `-s read-only`. Claude's `--restricted` mode removes
  WebFetch but not WebSearch. Past Claude reviewer sessions made 4 WebSearch calls in 3,924
  transcripts, all for library or Action versions. After each attempt the operator reads the
  candidate transcripts. A web call naming `shakacode/shaka`, the item's PR, or one of its SHAs
  voids the attempt. Stage 2 implementers run without GitHub credentials and with WebFetch and
  WebSearch denied, in both arms.
- **Judge and verifier labels:** `P` and `Q`, or opaque finding ids. Never a model id, arm
  name, price, or run number.
- **Training data:** the items date from 2026-10 and 2026-11, after Claude Opus 5.5's training
  cutoff. gpt-6.1-sol's cutoff is UNKNOWN.

## Stop rules

- **Spend:** the pilot caps are $20 for Stage 1 and $125 for Stage 2 in billed-equivalent
  dollars, or $35 and $1,000 if the maintainer counts cache-neutral dollars. The full-run caps
  are set at approval. The ADR's shared $200 monthly cap takes precedence. So does its $15 per
  PR evaluation, unless the maintainer approves an exception for a named item. The spend ledger
  admits a call only when `spent + reserved + unknown + estimate <= cap`; `budget_exhausted`
  stops the run with no retry to make room.
- **Pilot bars:** a missed P1 to P4 stops the run and reports, without asking for approval.
- **Scorer:** J1 to J3 below their bars stops the run; found counts from that judge are void.
- **Stage 2 prerequisite:** no Stage 2 priced call until the prototype helper commit exists
  and passes `bin/validate`. Its stub-rendered full-scope prompts must match the trusted
  helper's byte for byte. Its cycle-2 new-commits prompt must match Stage 1's arm-B prompt
  apart from the ledger block.
- **Stage 2 offline smoke:** at $0, in a fixture with no remote and no GitHub credentials, run
  every helper command the workflow's Intake and Verify phases call: `doctor --brief`,
  `seam check --ref main`, `claim`, `reviewer`, `review run` with stub reviewers,
  `review record`, and `evidence run` for `validate`. A command that fails offline gets a
  harness fix before any priced call. Intake runs once per item, inside the shared cycle 1;
  both forks resume after it.
- **Early spend:** an implementer session that spends more than $2 before its first
  `review run` is voided. Its spend counts, and the harness is fixed before a retry.
- **Stage order:** Stage 2's pilot runs only after Stage 1's pilot passes P1 to P4. Stage 2's
  full run starts only after R1 passes on Stage 1's full run. Each step needs its own approval.
- **Retries:** at most one per attempt, after a diagnosed timeout or provider error. A second
  failure records the attempt as failed. Stage 1 resends the identical prompt; Stage 2 sends the
  resume prompt below.
- **Round cap:** Stage 2 keeps the trusted `review.local_max_rounds` of 5. An arm that reaches
  the cap ends there, recorded, and is not extended.
- **Frozen text:** a changed arm, bar, decoy, item rule, or stop rule after the first priced
  call is a new eval with a new preregistration.

## Held-out exposure

| Set | Prior exposure | Reservation |
| --- | --- | --- |
| Pilot items #810, #902, #954 | Their findings were produced by Codex (gpt-6.1-sol) and Claude (Opus 5.5) reviewers and read by their implementing agents. All three are in the report's sample. This plan's author (Claude Opus 5.5) read their review comments. | Development rows: the dry run and pilot may read them, and the author may tune the harness on them before freezing. |
| Full-run items (H1) | Produced by the same reviewer families. The report's study agent (Claude Opus 5.5) parsed their finding titles and counts by script without reading or verifying them. This plan's author has not read them. | Candidates never see their review comments, later commits, or PR pages. The operator reads their comments only to build K and decoys, after the harness, prompts, and bars are frozen. Nothing read from H1 changes this text. |
| Cross-PR decoy findings | From the report's sample, already read by the study and this author | Used as decoys only; never as K items. |

## Zero-cost dry run

All of this ran on 2026-11-06 with no model call.

- **Stub reviewers:** stub `claude` and `codex` executables on `PATH` record the exact prompt
  Shaka sends and return an empty attested report. Shaka's real `review run` ran 36 times in
  the fixtures described above: both arms and both reviewers at all 9 later cycles. All 36
  returned `completed`.
- **Fixtures:** each held only its head branch and `main`, with 521 to 623 commits. In all 36,
  `git merge-base main HEAD` equals the item's merge base, and each `C(K-1)` is an ancestor of
  its `CK`.
- **Ledger probe:** a stub ledger loop on #954 accepted arm A's second round and refused arm
  B's, quoted under [How each arm is produced](#how-each-arm-is-produced).
- **Offline probe:** with no GitHub credentials, `seam check --ref main` loaded the settings in
  a fixture. `doctor --brief` reported FAILED for repository access. The Stage 2 prompts
  therefore tell the implementer the checkout is offline.
- **gstack checks:** `gstack-eval-plan dry-run` passed for both stages.

```text
Stage 1 rows (36 reviewer prompts), --arms claude-opus-5-5,gpt-6.1-sol --output-budget 16384 --cap 20
CHECK: price-table ok
CHECK: output-budget ok (16384 tokens; reasoning floor 8192)
CHECK: retry-prompt ok — "On a diagnosed timeout or provider error, resend this row's review prompt unchanged, once, with --timeout-seconds 600. Append nothing, so both arms keep byte-identical inputs."
CHECK: reservation-fits-cap ok ($0.4161 <= cap $20.00) one call = 22113 in + 16384 out tokens
DRY_RUN_RESULT: pass

Stage 2 rows (9 implementer prompts), --arms claude-opus-5-5 --output-budget 32768 --cap 125
CHECK: retry-prompt ok — "The previous session stopped before the review loop finished. This checkout has no GitHub remote, so work offline. Read the ledger and the branch's commits, then continue the loop from the last recorded round without repeating it. Do not push, open a pull request, or post anything to GitHub."
CHECK: reservation-fits-cap ok ($0.6559 <= cap $125.00) one call = 147 in + 32768 out tokens
DRY_RUN_RESULT: pass
```

The gstack per-item estimates price one call per row. Stage 2 rows are agent sessions with
many calls, so their per-item figure checks the pipeline, not the price. The pilot table below
is the price.

**Reviewer prompt size,** measured from the 36 captured prompts at 0.25 tokens per byte:

| Item | Arm A tokens per run | Arm B tokens per run | B/A |
| --- | ---: | ---: | ---: |
| #810 | 7,514 | 5,619 | 0.75 |
| #902 | 21,634 | 5,484 | 0.25 |
| #954 | 7,825 | 5,576 | 0.71 |

- The historical runs read 113K to 331K input tokens each, because reviewers read files over
  several turns. The prompt is re-read every turn, so B's saving per run can exceed the
  difference above. Stage 1 measures it.
- The prompt has a fixed part of about 19 KB: instructions, `AGENTS.md`, and the earlier
  findings. On small PRs that part dominates, and B saves little on reviewer input.

**Implementer prompts.** Stage 2 sends these exact texts. Both arms get the same ones.

- Shared cycle 1: "/shaka The branch checked out at /Users/justin/claude/shaka-worktrees/PR
  holds a change that has not been reviewed yet. Its goal is in
  /Users/justin/claude/shaka-state/PR/goal.md. This checkout has no GitHub remote, so work
  offline. Run one round of the local review loop with the
  configured reviewers and the ledger /Users/justin/claude/shaka-state/PR/ledger.json: review
  the current head, record every finding, fix defects and clearly correct risks in new commits,
  and run validation. Stop before reviewing the new head. Do not push, open a pull request, or
  post anything to GitHub."
- Each arm, resuming a fork of that session with `claude --resume ID --fork-session`:
  "Continue the local review loop with the same ledger: review the current head, record every
  finding, fix defects and clearly correct risks in new commits, validate, and review again
  until no agent-owned fix remains or the round cap stops the loop. Do not push, open a pull
  request, or post anything to GitHub."

## Priced pilot

Three items per stage. Arm B is priced at arm A's cost, so the cap covers no saving.

| Stage | Item | Paid work | Billed estimate | Cache-neutral estimate |
| --- | --- | --- | ---: | ---: |
| 1 | #810 | 3 later cycles × 2 arms × 2 reviewers = 12 runs | $2.04 | $5.70 |
| 1 | #902 | 5 × 2 × 2 = 20 runs | $6.60 | $14.00 |
| 1 | #954 | 1 × 2 × 2 = 4 runs | $0.64 | $1.68 |
| 1 | Judge | about 68 calls: findings, controls, near misses | $2.38 | $2.38 |
| **1** | **Total** | **36 runs, 68 judge calls** | **$11.66** | **$23.76** |
| 2 | #810 | Shared cycle 1; 3 cycles per arm; 2 escape audits | $23.41 | $222.90 |
| 2 | #902 | Shared cycle 1; 5 cycles per arm; 2 escape audits | $40.93 | $360.95 |
| 2 | #954 | Shared cycle 1; 1 cycle per arm; 2 escape audits | $9.95 | $90.15 |
| **2** | **Total** | **21 loop cycles, 6 audits** | **$74.29** | **$674.00** |

- **Stage 1 band:** reviewer costs varied up to 1.5 times between runs on these items, so
  $8 to $18. Cap $20.
- **Stage 2 band:** an implementer cost of 0.6 to 1.8 times the assumption, $1.80 to $5.40 per
  fixing cycle, gives $51 to $121. Cap $125.
- **Cost units:** the [ADR's budget](../../internal/adr/0001-eval-and-release-gating.md#budget)
  sets its caps in API-equivalent dollars and gives its figures cache-neutral. This plan
  states both and leaves the unit to the maintainer.
- **Per-PR cap:** the ADR allows $15 per PR evaluation. Stage 1 averages $3.90 per item billed
  and $7.90 cache-neutral. Cache-neutral, #902 alone is $14.00 plus about $1.80 of judge calls,
  just over $15. Stage 2 exceeds the cap in either unit, up to $41 billed for #902, so it needs
  its own approval.
- **Time:** Stage 1 is about 40 minutes with two workers. Stage 2 is 3 to 5 hours: about 21
  cycles of review, fix, and the 5.5-minute median validation.
- **Full-run projection:** Stage 1 on 25 items is about $120 billed ($60 to $180). Stage 2 on 10
  items is about $250 billed ($170 to $400), above the monthly cap. The pilot's
  `gstack-eval-plan pilot report` replaces these figures with measured ones.
- **Metering:** reviewers and the implementer run on seat subscriptions. Each attempt settles in
  the spend ledger at Shaka's billed-equivalent estimate and is marked seat-metered.
- **Gate pricing:** the repository has no gstack call-plan file, so `price-gate` has nothing to
  price. This table is the price.

## Approval

Recommended: approve the Stage 1 pilot only, capped at $20 billed-equivalent.

- A) Run the Stage 1 pilot (3 items; $11.66 billed or $23.76 cache-neutral; cap $20 or $35).
  Recommended. In cache-neutral dollars, this option also needs a per-PR exception for #902,
  up to $16.
- B) Run both pilots: Stage 1 now; Stage 2 after its prototype exists ($74.29 billed, cap $125).
- C) Stop here and keep this preregistration as the record.

Also needed: which unit the caps count. In cache-neutral dollars, Stage 2's $674 estimate
cannot fit the $200 monthly cap.

## Limits

- **Stage 1 replays history shaped by arm A.** After a historical full-diff find, the earlier
  findings name it and a later commit holds its fix. Stage 1 therefore credits either arm only
  up to the cycle where history first reported each item. It cannot show what B's own loop
  would have done next. Stage 2 can.
- **Stage 1's arm A is not quite today.** Both arms run without a ledger, so neither gets the
  ledger's "confirm each fix" instruction.
- **Stage 2's arm B is a prototype.** Its prompt wording may differ from a shipped setting.
- **Implementer:** Stage 2 fixes one implementer, Claude Opus 5.5 at high effort. #902 was first
  built in Cursor, so Stage 2 replays its loop with a different implementer.
- **Fresh context:** Stage 2's arms fork one session after cycle 1. A real session may
  carry more context into later cycles than a fork does.
- **K is history:** K holds only what historical reviewers found and agents fixed. A defect both
  historical arms missed is invisible to the K bars; Stage 2's escape audit covers part of it.
- **One repository, one maintainer,** and reviewer prompts that changed during the window, as in
  the report.

## Rerun the dry run

1. Fetch each pilot PR: `git fetch origin "+refs/pull/N/head:refs/remotes/origin/pr/N"`.
2. Build `main` for the item: write a tree from the merge base's files, with the root
   `AGENTS.md` and `.agents/shaka/` taken from trusted `main`, and commit it with
   `git commit-tree -p MERGE_BASE`.
3. For each reviewed commit `CK`, bundle a branch at `CK` together with `main`. Clone the
   bundle into `/Users/justin/claude/shaka-worktrees/N`, fetch `main` from it, and remove the
   remote.
4. Put stub `claude` and `codex` executables first on `PATH`. Each reads the prompt from stdin,
   saves it, and returns a report ending `REVIEWED <head> BY <reviewer> EFFORT <effort>
   FINDINGS 0`. The Claude stub prints a JSON result with a `result` field; the Codex stub
   writes the report to the `-o` path.
5. Run `shaka review run` for both arms and both reviewers as under
   [How each arm is produced](#how-each-arm-is-produced), and save one JSON row per prompt.
6. Run `gstack-eval-plan dry-run --input ROWS --arms claude-opus-5-5,gpt-6.1-sol
   --output-budget 16384 --retry-prompt RETRY --cap 20 --out DIR`.
