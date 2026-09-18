# Build with Shaka and repair what slows delivery

Project-local maintenance guidance, outside the consumer skill, installer and gem.
Use it with trusted Shaka; adoption does not launch workers or background monitoring.

## Durable work and observed failures

| Work | Evidence and next outcome |
| --- | --- |
| [Publication quality #44](https://github.com/shakacode/shaka/issues/44) | #37 has escaped newlines; #38 has a malformed usage table. One Ruby renderer/publisher should make descriptions, comments and walkthroughs predictable. |
| [Model/effort cost #45](https://github.com/shakacode/shaka/issues/45) | Existing reports have model/effort tokens but no comparable priced totals. Extend the current reporter, retaining coverage and unknowns. |
| [Skill rewrite #33 / PR #38](https://github.com/shakacode/shaka/pull/38) | Current-head Ask/Auto behavior and existing acceptance belong here; do not create a competing rewrite. The maintainer chose Astra/xhigh for the next critical review. |
| [Public feedback PR #43](https://github.com/shakacode/shaka/pull/43) | Triage newly arrived findings against the code and prove configured AI review remains usable without maintainer relaying. Do not turn every suggestion into work. |

The study inspected PRs #25–#29, #37–#39 and #41–#43, plus proposal issues #30–#36.
At main `30073bb1c8558373298d30cbd446fe181e447057`, #37 and #39 are merged;
#38 and #43 remain open. These are dated observations, not merge-readiness claims.
Fresh-reader acceptance and comparative savings remain UNKNOWN/pending.

[Issue #1](https://github.com/shakacode/shaka/issues/1) remains the acceptance record;
[issue #36](https://github.com/shakacode/shaka/issues/36) remains the scope record.
The supervisor proposal revises the earlier solo-default recommendation for Shaka
development. It does not restore the retired fleet/control-tower infrastructure
or make multiple agents a requirement for every consumer PR.

## Objective and complexity test

Optimize accepted, understandable software per unit of human attention, elapsed
time and model cost. Count retries, supervisor work, review and rescue. Also inspect
maintainability, false alarms, recovery and unpredictable long-running failures.
Do not trade away trust or correctness for a cheaper first attempt.

Before adding a mechanism, name its observed failure, expected user benefit,
build/recurring cost, simpler alternative, acceptance evidence and deletion point.
For #44, one cohesive renderer replaces model-authored layout; #45 extends an
existing usage reader. Neither justifies a general schema, new telemetry service,
model-routing service, dashboard or growing inventory of policy checks.

## Use Shaka here without making improvement the task

Use the trusted installed Shaka workflow for development of Shaka itself, including
its tests, review and publication. Keep the workflow revision stable during a task.
Fix an immediate safety or delivery blocker when necessary; otherwise finish the
bounded change and batch workflow improvements afterward. Do not automatically
adopt the candidate workflow being edited as the instructions governing that work.

Dogfooding here reveals integration problems, but Shaka's instruction/trust design
is an atypical development workload. Learn about ordinary model performance from
useful feature and bug-fix work in consumer repositories as well. No duplicate
implementation, model bake-off, savings study or cost-report completeness is a
prerequisite for delivering work in either place. Preserve required safety gates.

Ruby owns mechanical formatting and publication. Writing, documentation and skills
still need judgment and real-reader evidence; word counts and rigid templates must
not replace clarity or accuracy. Use stronger reasoning when the task warrants it,
not merely to satisfy a lowest-token target. The supervisor's priority is finishing
accepted work and absorbing corrections, not continuously optimizing the agents.

## Supervisor as the default project contact

The maintainer gives one supervisor the goal, constraints and authority. That
supervisor owns planning, worker allocation, model/effort choices within those
constraints, acceptance, integration and the final explanation. The maintainer
should not need to chase worker mistakes. Workers must still test their work.

| Role | Responsibility |
| --- | --- |
| Maintainer | Set goals, budget/authority and consequential decisions; receive one concise account. |
| Supervisor | Scope work, dispatch only authorized tasks, verify evidence, consolidate repairs, manage dependencies and report outcomes/decisions. |
| Worker | Implement one bounded change, reproduce/test behavior and return commit, evidence, unresolved concerns and usage. |
| Existing independent reviewer | Challenge the change at its current revision; the supervisor assesses findings. A supervisor involved in design is not independent review. |
| Ruby and GitHub | Perform mechanical checks/publication and enforce native protection. They do not judge whether a prose explanation is true. |

Start with one supervisor and one worker; admit a second independent worker only
when review capacity and file ownership are clear. Several workers may serve one
supervisor, but adding workers must not create a new review queue. Keep one writer
per branch and use isolated worktrees. No recursive supervisors. Pause dispatch
when existing repairs or integration are the bottleneck.

For each assignment, pass only the goal, existing issue/PR, acceptance criteria,
checkout/file ownership, model/effort, authority and stopping point. Keep detailed
state on the PR and native task; avoid copying entire chat histories. Use compact
status snapshots, inspecting detailed outputs when a claim needs verification.
Review blockers, readiness, changed heads and failed checks at meaningful events;
do not repeatedly poll unchanged work or reread every transcript.

The supervisor checks behavior evidence, relevant diff, required checks/review,
current head and the actual published explanation before declaring completion.
It returns one batch of demonstrated findings, with a reproduction and acceptance
for each. After two failed repair rounds for the same class, choose a simpler
design, a focused reasoning escalation or a maintainer decision. Never merge past
a failing gate to satisfy a retry budget.

For new delegated workers, reserve publication/integration to the supervisor unless
explicitly assigned otherwise. Existing user-owned tasks retain their current
publication authority; a supervisor does not silently revoke or assume it. Record
who will publish/merge before taking over. Never edit a worker's files concurrently.
Required human approvals remain unchanged and are surfaced through the supervisor.

Native task tools can inspect or message existing tasks and, when supported, set
model/effort for a subsequent turn. Verify actual settings on resumption; do not
claim that a prompt switched the host. Reuse the maintainer's explicit selection.
Without the capability, request one precise setting change rather than proceeding
with an expensive fallback. Do not interrupt an active critical review to experiment.

Agree on the allowed model/effort choices and escalation boundary once with the
maintainer; avoid a new interview for each worker. Workers route questions through
the supervisor, which resolves routine choices within that authority. The public
skill's existing startup pause still applies today. Before claiming seamless
supervision, test how an explicitly authorized delegated assignment satisfies that
checkpoint; any required instruction change needs a reviewed, bounded follow-up.
Do not silently bypass the pause or claim every host supports remote model changes.

This guide activates no workers or persistent monitoring. A supervisor can operate
while its task runs; durable wakeups require a separate explicit scheduling request.
Machine aliases and cross-machine dispatch are deferred. Approved task IDs may be
placed on PRs as copyable `codex://threads/...` references: GitHub strips clickable
custom-protocol anchors. IDs do not publish transcripts; never create share links
or expose unrelated task identifiers as a side effect.

## Model and effort choices during delivery

Default ordinary features and bug fixes to Terra/medium, honoring explicit settings.
Record model and reasoning effort together from existing native evidence. Escalate
for a demonstrated reasoning difficulty or consequential risk. The maintainer's
Astra/xhigh review of #38 is a separate critical case, not an ordinary default.

Do not schedule Terra/low-versus-medium trials now. Reconsider settings only when
observed cost, latency or correction burden justifies the investigation. If a
comparison is later useful, hold skill revision, acceptance and task scope steady
and change one variable at a time. Do not infer causal savings from unrelated tasks
or delay useful delivery while looking for an optimal configuration.

Use existing PRs and native records to observe correctness, human corrections,
repairs, model/effort costs including supervision, and elapsed time. Missing data
stays UNKNOWN and nonblocking. Human active minutes need a maintainer estimate.
No mandatory per-task retrospective or new measurement infrastructure is needed.
A green unit suite establishes mechanics; fresh-task behavior and real deliveries
establish different outcomes. Keep these claims separate and fix observed misses.

## Price usage rather than comparing raw totals

Source snapshot: September 15, 2026. Refresh prices when calculating new work.
[Official Codex pricing](https://learn.chatgpt.com/docs/pricing#token-rates) gives
these standard credit rates per million tokens:

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Terra | 50 | 5 | 300 |
| GPT-5.6 Sol | 100 | 10 | 500 |
| GPT-6 Astra | 250 | 25 | 1,250 |

Credits, API-equivalent dollars and actual charges are separate quantities.
Applicable account terms and speed options matter. Do not infer a per-task bill
from account-wide usage percentages or spread a subscription fee across tokens.

For API estimates, [Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra)
lists $2/$0.20/$12 and [Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)
$10/$1/$50 per million input/cached-input/output tokens. Cache-write pricing,
context thresholds and service tiers require request-level treatment. Never apply
an API multiplier to Codex credits without evidence that it applies there.

Calculate each unique response using disjoint native categories and its applicable
rates, then sum. In the tested Codex records, cached input is included in input and
reasoning output in output: subtract cached input before pricing ordinary input;
do not add reasoning output again. Handle cache writes according to the source's
semantics, including whether already included in another category. Missing rate,
model, billing mode, tier or threshold evidence yields UNKNOWN or an explicitly
conditional estimate. A configured-model estimate does not establish actual routing.

Effort changes consumption and latency; do not add an invented effort surcharge.
Use actual settings and observed usage for each supervisor, worker and reviewer,
including unsuccessful attempts. Count response IDs once across shared/forked
sources. Preserve original commit associations after squash without recounting.
Missing external reviewers remain a coverage gap, not zero cost. Public reports
contain aggregate metadata, sourced rates and assumptions, never raw sessions.

## Sequence and stopping point

1. Continue using trusted Shaka for useful work here and in consumer repositories.
   Finish #38/#43 in their existing tasks with their required verification.
2. Implement #44's bounded publisher correction because it addresses demonstrated
   maintainer rework; validate the failure cases and use it on subsequent work.
3. Extend cost reporting in #45 when it fits delivery priorities. It is nonblocking;
   no model/effort experiment or proven savings is required before shipping.

Review changes to this internal skill before adopting them. Candidate instructions
cannot replace the trusted workflow governing their own review.
Each task stops at its agreed delivery outcome. Two unsuccessful repair rounds on
the same failure family trigger reassessment, not endless workflow development or
permission to waive checks. Retain improvements that reduce total work; remove
ones that add friction. No automatic routing, fleet service or broad V1 migration
follows from using Shaka to build itself.
