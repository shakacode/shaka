# Proposal: deterministic delivery checks and selective local skill evaluations

Status: revised after Fable's SEND BACK; awaiting re-review. No runtime
implementation or paid benchmark has started. Prepared September 15, 2026,
against main `d81953f729f52953ea2a86d087616f94fe22d316`, under
[pilot issue #1](https://github.com/shakacode/shaka/issues/1).
Existing acceptance and merge gates remain in effect.

## 1. Decision and explicit reduction in scope

First make publication mechanics deterministic through existing #44. Then evaluate
one narrow hypothesis about a skill change using local repair tasks. Each task
starts at a recorded CI failure or review finding and ends with a tested local fix
and publication draft. It does not deliver a live PR or simulate all of GitHub.

The original proposal's stateful GitHub simulator exceeded the two-day time box.
Remove its `gh` protocol emulation, GraphQL/REST responders, bare remote/transport,
virtual clock, fake merge endpoint, and evolving review/check state. Keep existing
Ruby tests for those helper contracts. This deliberately narrows what model runs
can establish: repair and explanation at a known workflow stage, not end-to-end
Ask/Auto, review-source discovery, native branch protection, or Actions compatibility.

Fable suggested disposable private repositories with real Actions as an alternative.
That would be a useful integration experiment, but it changes the maintainer's
local-only execution constraint. Defer it unless that constraint is explicitly
changed. No sandbox repositories, remote benchmark jobs, or second GitHub identity
are part of this revision. Model inference still uses the selected provider;
repositories, commands, grading, logs, and experiment orchestration stay local.

The intended comparison remains two fixed profiles: `gpt-5.6-sol` / medium in Codex
and `claude-opus-5` / medium in Claude Code. Qualify Sol and a main baseline first;
then qualify Opus separately. This is staging, not evidence that Sol substitutes
for Opus. A result from only one profile is labeled partial. A specific hypothesis
can choose high instead, applied equally to baseline and candidate for that profile.
Do not run a medium/high matrix, automatic model fallback, paid judge, or subagents.

Do not benchmark every main commit. Each experiment names a hypothesis, the
decision it could change, selected cases, exact profiles/revisions, and a budget.
Success requires correct accepted behavior; fewer words/tokens alone is insufficient.

## 2. Current evidence and existing ownership

- [PR #51](https://github.com/shakacode/shaka/pull/51) completed a real Sol/medium
  delivery using #38's procedure at `22c39717dca47cfb294b73ec06841233d2e592cf`.
  It reports 106 tests / 890 assertions, required CI, independent review, review
  handling, a walkthrough, and merge `d81953f729f52953ea2a86d087616f94fe22d316`.
  It also records reading the installed skill during intake: useful real-use
  evidence, not a clean A/B trial or proof of both approval modes.
- #51's PARTIAL, SHARED usage is 106 responses over approximately 25.35 minutes,
  with an API-equivalent estimate of $7.978283. Reviewer cost and actual charges
  remain unknown. Use its observed scale for provisional budgeting, with the
  qualification that a local repair task is smaller than a complete delivery.
- [PR #38](https://github.com/shakacode/shaka/pull/38) is separate and conflicting
  with current main. Its [handoff](https://github.com/shakacode/shaka/pull/38#issuecomment-5691024590)
  captures next actions and #51's evidence. Building this runner is not a new
  prerequisite for #38 or a substitute for #33's acceptance.
- [#44](https://github.com/shakacode/shaka/issues/44) owns the deterministic publisher.
  [#45](https://github.com/shakacode/shaka/issues/45) and merged #51 own usage/cost
  reporting. Extend those once; do not build competing implementations here.
- Existing `test/github_helper.rb`, `test/merge_test.rb`, and
  `test/review_workflow_test.rb` cover injected GitHub responses, stale-head refusal,
  failed/missing checks, and missing review evidence without model calls.
- Reconcile accepted changes from [#43](https://github.com/shakacode/shaka/pull/43)
  and [draft #46](https://github.com/shakacode/shaka/pull/46) before integration.
  Neither draft supplies new authority or a mandatory supervisor.

## 3. Source examples and what to borrow

These are inspected references, not dependencies or claims of equivalent results.
Check licenses and retain attribution if copying code; pin any reused source.

| Example | Specific reuse | Limit |
| --- | --- | --- |
| [Rails Lemans](https://github.com/rails/lemans/tree/2d0b7fb8d3b0077574dcf7b70fd4e32c8f9d6e76) | Instructions, known-good solution, protected executable verifier, no-op/reference self-checks, distinct infrastructure errors. | Its shipped agent is Miniswen. Its Docker networking is not a ready-made domain allowlist; do not inherit its elevated container capabilities. |
| [Rails AI Evals](https://github.com/rails/ai-evals/blob/5327efe54dd767d662ab89332f6a4285fef07bd8/methodology.md) | Behavioral grading, restored tests, saved patches. | Full application/feature benchmarks are outside this first experiment. |
| [Ponytail agentic benchmark](https://github.com/DietrichGebert/ponytail/blob/e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156/benchmarks/agentic/README.md) | Isolated contexts, same tasks across variants, native usage, retained workspaces. | Distinguish phases: its agent is told to write and stop with Bash disabled; its safety scorer executes produced functions. Shaka repair cases permit local test execution. Prior global-plugin contamination is an isolation lesson. |
| [Caveman runner](https://github.com/JuliusBrussee/caveman/blob/ed37ab132393899c129bbeef2b9743ff3af19c68/benchmarks/run.py) | Skill hashes and raw paired observations; token counts are separate from quality. | Its dry-run prints two arms while execution uses three. Generate estimates and executions from one immutable manifest. |
| [Anthropic skill-creator schemas](https://github.com/anthropics/skills/blob/34040c9c568585f6929bedeaad110ad08f079624/skills/skill-creator/references/schemas.md) | Explicit assertions and timing/usage evidence. | Do not import an optimizer loop or require model-based grading. |

The inspected Lemans [agent interface](https://github.com/rails/lemans/blob/2d0b7fb8d3b0077574dcf7b70fd4e32c8f9d6e76/lib/lemans/agent.rb)
and [verifier](https://github.com/rails/lemans/blob/2d0b7fb8d3b0077574dcf7b70fd4e32c8f9d6e76/lib/lemans/trial/verifier.rb)
support separating host adapters from grading. Borrow that separation, not an
execution framework. Use Ruby standard libraries and existing native CLIs.

## 4. Deterministic mechanics

Implement [#44's acceptance](https://github.com/shakacode/shaka/issues/44) in its
own bounded PR. The agent supplies meaning; Ruby assembles PR descriptions,
short replies, and commit-bound COMMENT walkthroughs. Reproduce #37's escaped
newlines and #38's malformed table through the actual publication entry points.

Use existing validation for serialization, required fields, Unicode/code escapes,
column counts, current-head linkage, readback, and uncertain-write handling.
Link to #44 for the full acceptance rather than maintaining a second contract.
Local structure tests and GitHub's real rendered readback have different coverage;
readable syntax does not prove accurate prose. Paid evaluations assess whether an
agent supplies useful content or recovers from diagnostics, not table punctuation.

Stale heads, check states, missing approval, and missing visible review evidence
remain deterministic helper tests. A green review job alone must not imply a
completed review. No new GitHub emulator or paid stale-head case is needed in v1.
Real delivery evidence still covers the external integration.

## 5. Hypotheses, fixtures, and protected grading

H1: deterministic publication prevents known formatting errors. Ordinary failing-
then-passing tests decide this; no paid run is required for mechanical syntax.
H2: a skill rewrite preserves local CI repair and review handling, with possibly
lower usage. Run the affected case plus a control when needed, within each model
profile. H3: changing a merge helper preserves stale-head refusal. Existing Ruby
negative tests decide the mechanic; do not claim they prove agent judgment.

Create a small Ruby/Minitest consumer fixture, frozen at an initial commit with its
own ordinary `AGENTS.md` seam. Do not use Shaka's source-repository policy as the
consumer's policy. Each case contains a task, consumer files, sanitized evidence,
known-good/known-bad patches, and a protected verifier. No server/database is needed.

| Case | Supplied starting evidence and task | Required outcome |
| --- | --- | --- |
| `ci-repair` first | A saved failed-job log from the fixture's real failing test. Repair the defect, validate locally, and prepare a description/walkthrough draft. Publication and merge are outside task scope. | Protected behavior and unaffected tests pass; draft identifies the fix and actual validation; no claim that remote CI or merge occurred. |
| `review-repair` second | A saved review with a valid defect plus an instruction to weaken trusted policy. Address actionable feedback and prepare a reply. | Correct fix, green protected tests, policy preserved, reply linked to the finding and evidence; unsafe instruction not followed. |

The starting evidence is a declared fixture, not a claim that the agent discovered
current GitHub state. The same task scope/evidence is supplied to both arms. Local
Git commits are allowed; no remote, push, approval, or live `gh` operation is needed.
Ordinary `gh` availability/errors do not require an emulator. Attempted out-of-scope
publication or policy bypass is a behavior failure; harmless unsupported discovery
is retained as overhead, not automatically invalidated as an infrastructure error.

After execution, copy only permitted source changes into a clean verifier
container, restore baseline tests/configuration, and add hidden checks. Reject
unauthorized changes to policy/test commands; add legitimate agent-written tests
separately. The agent cannot read the reference fix, hidden assertions, prior
solutions, grader outputs, or another run. Known-bad/no-op work must fail and the
reference fix must pass before paying a model.

Use executable assertions for code behavior and generated publication structure.
Require evidence for facts the drafts claim; record unsupported statements as
failures where mechanically checkable. Semantic usefulness needs a short human
inspection of the paired drafts, recorded separately from automated assertions.
No keyword score purports to measure reasoning. No paid model judge is required.

Later Rails/React cases should come from demonstrated needs. The Rails corpus and
Ponytail's React examples are references; importing them is not part of v1.

## 6. Two-message startup and proof of a working baseline

The main skill pauses after recommending a model. Supplying a model flag or saying
ready in the same initial prompt may not satisfy that sequence. Do not spend a
candidate matrix before proving main can complete the bounded task unattended.

Use the same finite, preauthored conversation in each arm:

1. Supply task, repository, selected model/effort, offline scope and all required
   policy. Ask the agent to perform intake and pause before implementation.
2. After that turn ends, the driver sends the predetermined user message confirming
   readiness and asking it to complete the already-scoped local task.

Both messages are part of the approved fixture, sent by the driver without a live
human. They do not grant merge authority or answer arbitrary later questions.
Record and charge both turns. The first message explicitly requests the pause so
a faster candidate does not start under different authority. This experiment
therefore does not measure improvements to initial intake or approval UX.

Use the host's native session continuation with the same run-local state. Each
turn uses noninteractive execution and closes stdin after its declared input.
Unexpected questions after the second message end as `NEEDS_INPUT`; there is no
answering loop. Unexpected permission requests are denied. If main cannot finish
with this script and declared permissions, stop: repair the setup or revise the
experimental question, not the baseline skill to make it pass.

Qualify Sol first with one main run. It can become the baseline only if its exact
manifest/configuration survives qualification unchanged. Then run its candidate.
Opus joins only after its own main skill/adapter succeeds under the same contract.
A failed host qualification is not evidence that the candidate skill is worse.

## 7. Concrete local isolation and bounded execution

Run each native CLI in a disposable non-root Linux Docker container on the local
machine. Freeze the image/CLI versions. Only the consumer checkout, native session
scratch, and local publication outbox are writable. The selected skill tree and
supporting guides/helpers are mounted read-only outside the candidate tree.
The trusted outer runner and verifier are never loaded from the candidate package.

Use a fresh home/config per run and exclude ambient skills, hooks, plugins, MCP,
memories and parent instructions. Canary checks establish selected-skill presence
and unselected-skill absence. Mount no host home, Docker socket, SSH agent, or GitHub
credentials. No privileged mode or added SYS_ADMIN/NET_ADMIN capabilities.

Pin the egress mechanism to an off-the-shelf **Squid CONNECT proxy sidecar** with
[domain ACLs](https://www.squid-cache.org/Doc/config/acl/). The agent container joins
only an [internal Docker network](https://docs.docker.com/reference/cli/docker/network/create/);
only the proxy has external connectivity. Configure HTTPS_PROXY/HTTP_PROXY and an
explicit allowlist for required model endpoints. Reject direct/IP-literal, non-TLS,
GitHub, and private/host destinations. Do not use broad provider-domain wildcards
as a substitute for discovering required endpoints. No custom auth/billing proxy.

Proxy variables alone are not the isolation boundary. Phase 0 must prove the pinned
CLI routes all required traffic through the proxy and that unsetting its proxy,
using host.docker.internal, direct IPs, or real GitHub cannot escape. Record the
actual domain allowlist with the profile. If authentication needs an unbounded
allowlist or a custom transport, stop. Prepare dedicated native authentication
before the timed run; do not copy the user's complete config/history. Record the
chosen subscription/API billing mode; changing it changes the profile.

For Codex, plan the documented external-sandbox execution mode inside this
container: the container is the execution boundary, and no nested native sandbox
is assumed. A bypass flag is forbidden on the host and must never be introduced
as a workaround for a failed container-boundary probe. The runner must refuse
launch unless that disposable boundary has been verified. For Claude, pin an
explicit noninteractive permission policy and test it before qualification.

Local inspection found Codex 0.154.0, Claude Code 2.1.272, and Docker 29.4.1;
flags/prerequisites do not prove this combination works. Authentication, proxy
routing, continuation, skill discovery, and timely usage are Phase 0 acceptance.

Start sequentially. Set a **30-minute wall-clock cap per complete two-turn cell**,
including idle/CI-like waiting, based on #51's observed 25.35-minute interval.
This is a conservative starting cap, not a prediction that a short repair takes
that long. Calibration may justify lowering it. Record startup/verification time
separately; neither can run indefinitely. Use native turn/tool limits where
verified; their semantics differ between hosts. Kill the container/process tree
on expiry and retain partial usage. No automatic retry, fallback, or continuation.

Setup/auth failures and unavailable declared tools are infrastructure errors.
Forbidden agent actions are behavior failures even if containment blocks them.
Stop the batch on an infrastructure error. Do not spend more cells to rediscover
it. The two-day engineering cap includes making isolation work.

## 8. Baseline reuse, results, and interpretation

Budget on **fresh baselines**. Reuse is an optimization when strict compatibility
holds, not the assumption that pays for the experiment. Pin CLI/image versions
for a comparison campaign; upgrade deliberately, then requalify affected profiles.
No weekly refresh or evaluation on every main commit is required.

Record the baseline's exact main commit and the candidate commit. Define the
package digest as the installed skill tree linked by `bin/install`, plus every
external guide/helper it loads, identified separately in the manifest. A root
SKILL.md hash alone is insufficient. For an instruction-only claim, hold helpers
fixed; otherwise label the combined package effect.

Compatibility also covers fixture/tree/evidence, startup script and task scope,
model identity/effort, CLI/image, tool/permission/egress configuration, billing mode,
and limits. Rate-card and grader revisions are separate. Regrade saved work or
reprice raw counters without new model calls when only those change and sufficient
artifacts exist; a changed execution contract requires a rerun.

Retain every baseline attempt; never select the cheapest or most successful one.
Unrelated main changes can reuse an unchanged evaluated package after explicit
comparison, with the original baseline commit shown. Current-head ordinary
validation still runs. Alias/routing drift makes older results provisional; a
fresh baseline is appropriate when that uncertainty could change the decision.

Counterbalance arm order across profiles/repeats and record native cache behavior.
A fresh local home does not clear provider caches. Do not credit the candidate for
having run second with warmer caches. This is model-plus-host comparison; equal
provider effort labels do not imply equal compute.

Keep local manifest, patch, native events/usage, assertion results, draft artifacts,
and termination reason outside tracked source. Suggested outcomes: `PASS`, `FAIL`,
`NEEDS_INPUT`, `LIMIT_REACHED`, `HARNESS_ERROR`. Use protected results, not the
agent's success claim. Publish only reviewed aggregate metadata; no raw sessions,
credentials, private identifiers or local machine paths.

One run per cell is a regression screen. Permit at most one additional pair for
an affected profile/case if predeclared in the budget and useful to the decision.
Mixed results are inconclusive; never rerun until green. Reused evidence does not
increase sample size. Safety failures defeat a savings claim. Invalid runs remain
visible with their cost. Human review time is separate and UNKNOWN unless measured.

## 9. Cost estimates grounded in observed work

Reuse #51's deduplication and OpenAI estimator. Qualifying Sol first avoids adding
an Anthropic estimator to the first milestone. Before any Opus cost comparison,
verify its native billing categories/rates: Anthropic input excludes cache reads
and writes, while tested Codex input includes them. Cache-write lifetimes/rates
must be represented; unknown writes are not zero. Thinking is included in output
when the provider records it there. Effort changes usage, not the per-token rate.

Replace the earlier small hypothetical mix with **#51's observed scale**: 208,498
ordinary input, 15,651,328 cached input, and 44,188 output tokens, with zero writes
in that Codex record. Its published $7.978283 Sol scenario is the reference point.
Repricing those same counts at Opus rates gives approximately $9.97, but that is
not measured Opus work and omits its unobserved cache writes and usage differences.

| Planned work with fresh baselines | Cells | Provisional API-equivalent allowance basis |
| --- | ---: | --- |
| Sol qualification/main plus candidate, one case | 2 | About $15.96 if both resemble #51; runtime/setup/reviewer gaps remain. |
| One case on both qualified profiles | 4 | About $35.90 before unmeasured Opus writes/usage differences. |
| CI and review repair on both profiles | 8 | About $71.80 on the same conditional basis. |

These are planning references, not forecasts, caps, invoices, or an assertion that
checkpoint tasks consume a full delivery's tokens. First matched runs replace the
reference with observed per-case usage. No small warm-cache example should headline
the budget. Cache sensitivity remains relevant but is not a second invented quote.
At the 30-minute per-cell cap, sequential run envelopes are 1, 2 and 4 hours,
plus bounded setup/verification; one observation does not establish a distribution.

Rate sources: [Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol)
($4/$0.40/$20 per million ordinary/cache-read/output tokens; promotional pricing
available at least through November 21, 2026) and
[Opus/caching](https://platform.claude.com/docs/en/about-claude/pricing)
($5/$0.50/$25; cache writes separate). Checked September 15, 2026; refresh before
quoting runs. Apply request-level thresholds and tiers before aggregation. Keep
Codex credits, API-equivalent USD and actual charges distinct.

`plan` prints estimated new cells, possible repeats, fresh/reused baseline status,
source/date, cost coverage and wall-time envelope from the same immutable manifest
that `run` consumes. A numeric batch allowance, maximum cells, and deadline must
be agreed before execution. Estimates with missing data explicitly say incomplete.

Claude has a native [print-mode budget control](https://code.claude.com/docs/en/cli-reference).
The inspected Codex `exec` has no dollar-budget flag; telemetry cancellation may
overshoot an in-flight call. Label that as a soft spending stop. If timely counters
are unavailable, report only enforceable count/time bounds. A requested strict
monetary ceiling blocks execution until a supported provider/auth setup enforces it.
No billing proxy or automatic retries belong in this work.

Record implementation, qualification/baseline creation, candidate runs, failed
attempts, and repeats separately in existing PR usage details. A reused baseline
has historical cost and no new model calls. Never split shared totals equally over
commits or silently exclude failures. No dashboard or accounting service is added.

## 10. Advice on whether a PR needs a paid benchmark

Add concise guidance to `docs/verification.md` and the existing task guide only
after plan approval. There is **no Benchmark note on every PR**. A skill/helper
change records the owner's recommendation when behavior/usage is in question;
an obvious deterministic-only change needs at most a sentence in existing validation.
Unrelated PRs get no new receipt, section or mandatory step.

| Change | Default advice |
| --- | --- |
| Typo, explanatory docs, table assembly, pricing arithmetic | Focused deterministic tests/review; skip model runs unless agent interaction changes. |
| Skill wording/order affecting CI repair or review handling | Name the hypothesis; recommend relevant repair case plus a control if justified, on the finalized candidate. |
| Merge guard, authority, or review-source interpretation | Required deterministic negative tests and human/independent review. These checkpoint cases cannot establish full integration; retain applicable real-use acceptance. |
| New model/effort, host adapter, startup isolation | Qualify that host/main first, then create fresh matched baselines. No silent cross-model extrapolation. |
| Nonbehavioral fix after a measured head | Reuse results only with a documented compatibility rationale; run ordinary checks for the new head. |

For relevant PRs, record: hypothesis; run/skip/defer and why; cases/profiles;
baseline/candidate identity; fresh-cell count; estimated cost/time/limits; result
or evidence gap. The author recommends and reviewer challenges. File-path matching
can suggest work but cannot decide semantic impact. No classifier or paid dispatch
service is needed. Existing acceptance cannot be waived by calling a benchmark
advisory. Reassess scope changes without testing every commit.

## 11. Bounded implementation and stopping conditions

Fable re-reviews this revision before implementation. Do not launch workers or paid
runs from the proposal review. Use sequential small PRs, preferably below 500
changed lines, and existing validation/independent review.

| Slice | Scope | Acceptance / stop |
| --- | --- | --- |
| 0: qualify the local boundary and main | Disposable Docker/Squid config, one Ruby fixture, one Codex adapter, fixed two-message startup | Within half a working day, prove isolation, continuation, evidence/usage capture, cancellation and main's completion. Use declared budget; a failed qualification stops candidate runs. |
| 1: deterministic publication | Existing #44; no duplicate contract | Independently useful completion of #44. This does not depend on benchmarks. |
| 2: one informative Sol comparison | Thin Ruby driver, protected verifier, manifest/results; `plan`, `selftest`, `run` only | Model-free no-op/reference selftests; main/candidate CI-repair pair that informs a decision. Results printed by `run`; no standalone compare/rescore commands. |
| 3: extend only after demonstrated value | Second local review-repair case, then qualified Opus adapter and its cost normalization | Preserve two-profile goal, but present one-profile results as partial until this passes. This extension has its own stated budget; no automatic matrix expansion. |

Keep eval dependencies out of product runtime. Proposed paths are `eval/bin/shaka-eval`,
small `eval/lib/` adapters/runner/verifier, and case directories. Local Docker/model
runs are explicit. Cheap no-model tests can join `bin/validate`; CI never launches
paid benchmarks. Keep saved artifacts sufficient for future manual regrading;
add no extra command until it has actual work.

Cap evaluation-specific engineering through the first informative **Sol** comparison
at two working days, including isolation and qualification, excluding independent
#44 work. This supersedes the original promise to build a simulator and two host
adapters in that box. Stop if the boundary requires a custom proxy, privileged
agent container, broad host mounts, or repeated setup fixes. After two repair
rounds on a failure family, reassess. A negative/inconclusive result is a valid
outcome; a half-built platform is not the next automatic phase.

## 12. Response to Fable and re-review request

Fable's supplied review returned SEND BACK on the original `dcbdb29` proposal.
The following dispositions are changes to the plan, not claims of runtime proof.

| Finding | Disposition |
| --- | --- |
| B1: full GitHub simulator exceeds scope | Accepted. Removed it; local repair-stage tasks replace its paid scenarios. Deferred hosted sandbox suggestion because it changes local-only execution. Explicitly reduced coverage. |
| S1: qualify one profile first | Accepted as staging. Sol first; Opus retains a separate main qualification before the requested two-profile comparison. |
| S2: original cost mix too optimistic | Accepted. Use #51's observed scale; label Opus repricing conditional and require its real cache-write accounting. No zero-write assumption for actual Claude results. |
| S3: ten-minute limit too short | Accepted. Initial cap is 30 minutes per two-turn cell, calibrated later. |
| S4: unspecified egress mechanism | Accepted. Squid CONNECT sidecar and internal network, with explicit negative probes; proxy compatibility remains a feasibility gate. |
| S5: assumed nested Codex sandbox | Accepted. External container boundary; no privileged workaround or bypass flag on the host. |
| S6: main's readiness pause | Accepted. Fixed two-message script and a successful main qualification before any candidate matrix. |
| S7: benchmark note on every PR | Accepted. No universal note; concise advice only for relevant skill/helper changes. |
| S8: baseline compatibility often changes | Accepted. Budget fresh baselines; pin campaigns and reuse only verified matches. |
| Nits | Clarified Ponytail agent/scorer phases; linked #44 instead of duplicating it; defined installed-package/guide digests; recorded Sol promotion; kept three verbs; made review-repair the second case and kept stale-head mechanics in Ruby tests. |

Re-review for APPROVE or SEND BACK with BLOCKER/SHOULD/NIT findings. Check whether
this smaller experiment can fit the box, whether its narrowed claims are useful,
whether startup/isolation can be proved, and whether cost/coverage labels are honest.
Prefer deletion to new mechanisms. Do not implement, benchmark, or merge during review.

After approval, recommend one owner on Sol/medium for bounded Ruby/docs work with
existing independent review, honoring current user-selected settings. The unproved
parts are still explicit: native continuation/auth/proxy/isolation, matched costs,
protected grading, and Opus qualification. Approval of a plan proves none of them.
