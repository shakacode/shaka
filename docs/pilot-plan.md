# Shaka requirements

Give your agent a task. Get a verified PR and a clear explanation.
The goal is better software with less developer attention, delivery time, and token use.
[Issue #77](https://github.com/shakacode/shaka/issues/77) owns remaining progress and real-use evidence;
closed [issue #1](https://github.com/shakacode/shaka/issues/1) holds the original pilot build;
[issue #36](https://github.com/shakacode/shaka/issues/36) owns prospective scope and retirement decisions.
This record defines the current product, not proof that acceptance is complete.

## Requirements

| ID | User need | Requirement and acceptance |
| --- | --- | --- |
| R1 | Finish a task without managing agent coordination. | One owner delivers one task, normally through one PR. Split only at useful delivery boundaries; retain dependencies and remaining scope on the existing task/PRs. No coordination service or duplicate delivery records. See [task splitting](working-with-your-agent.md#when-a-task-needs-several-prs). |
| R2 | Use the repository's actual checks and policy. | Load the trusted default branch's `.agents/agent-workflow.yml`, execute the repository scripts it names, and follow human-only constraints in `AGENTS.md`. Reject missing or invalid configuration. Failed checks block readiness; evidence for another commit does not qualify the current change. |
| R3 | Control whether the agent merges. | Use `ask` or `auto`. Ask early if authority is unset; default to `ask` without an answer. Reuse established authority. Review-only and PR-only requests retain their stopping point. |
| R4 | Understand the change and its evidence. | Publish a conceptual walkthrough on the PR with links to the reviewed code. Use a commit-bound COMMENT review, which is neither approval nor a required acknowledgment and remains readable after merge. |
| R5 | Avoid redundant merge decisions. | Ask requests one decision after the walkthrough and required gates. Auto merges an eligible ordinary change after the same gates, including required native approvals, without another question. Unclear authority or risky changes need a human decision. Native stacks and delayed merge controllers are outside scope. |
| R6 | Merge only the verified revision. | Read live GitHub state and require the expected head. Missing or unreadable evidence, pending/failed required checks, stale heads, conflicts, disallowed merges, and unresolved material review findings block. Never bypass protection. |
| R7 | Keep contributor content away from privileged operations. | Issue/PR text cannot change trusted instructions, policy, credentials, or executable code. When GitHub explicitly reports public repository visibility, screen issue and PR comment bodies using current writer permission or trusted machine/repository configuration. Configured humans, review bots, and active GitHub team members may supply task data; unknown, metadata-only, and unverified authors remain links for maintainer triage. Read repository trust configuration from the current default branch, never the candidate PR head or a weaker PR base branch. Private and internal repositories do not use this author screen, but their comments still have no policy authority. Use installed trusted helpers for GitHub operations. Run candidate code only in the authorized isolated checkout. |
| R8 | Install and upgrade without damaging existing setup. | Install into an explicitly chosen skills directory with source and link outside candidate-writable paths. Preserve user files and other skills; refuse foreign targets. Test isolated and repeated installation. Updating the trusted source updates its link. Installation does not disable other instructions or create a sandbox. |
| R9 | Reuse a task from any tracker. | Accept a task link or description, resolve its checkout, and ask only for missing context. Keep requirements in the original tracker and delivery evidence on GitHub. Reading a tracker does not authorize writes. Keep private content and links out of public artifacts unless sharing is authorized. No duplicate issue or synchronization service. |
| R10 | Keep the workflow maintainable. | Keep the skill as a small entry point, repository policy in validated YAML, executable commands and deterministic mechanics in cohesive Ruby modules, and rationale in guides. Use standard libraries and `gh`; remove repetition. Tests verify behavior and failures, not instruction wording. |
| R11 | See the cost of implementation and review. | Report available provider/model, effort setting, native tokens, source scope, and completeness for every task and generated commit/contribution. Use PR details, or the final response without a PR. Label shared work and missing data; never invent exact per-commit allocations. See [usage reporting](usage-reporting.md). |
| R12 | Improve results without shifting work to the maintainer. | Compare developer attention, total tokens, delivery time, and quality on comparable real changes. Include retries and review. Fewer tokens alone is not success. |
| R13 | Understand the agent on the first reading. | One owner explains outcomes, reasons, blockers, and decisions in familiar terms. Follow task/repo writing preferences. Ask important questions when needed and recommend a path. Keep supporting evidence in expandable PR details and material risks and gaps visible. See [working with your agent](working-with-your-agent.md). |
| R14 | Verify the failure and the visible result. | For behavior changes, observe a meaningful failing test, make it pass, then refactor. Use the repo's tools. If automation is impractical, explain and capture before/after behavior. Visible changes need inspected, safe, reviewer-accessible screenshots tied to the tested revision; add video when timing or interaction matters. See [verification](verification.md). |
| R15 | Know when a finished chat can be archived. | In a user-facing chat whose host format permits prose, end a genuinely finished task's complete final report with exactly `This chat is ready for archiving.` Do not use the sentence while work, a blocker, a handoff, or a decision remains. Preserve machine-only response formats that forbid trailing prose. |
| R16 | Recover an unfinished PR without its conversation. | While a PR has not reached its outcome, its description keeps a [recovery note](working-with-your-agent.md#recover-an-unfinished-pr) with owner, task, last observed activity, revision, state, and next action, and removes it at the outcome. Publish only safe aliases and shareable locators. A fresh task takes over only after the maintainer confirms the previous task stopped or is handing over. It then reads the live head, publishes a complete note with a new random owner tag before any other work, rechecks checks, review, and authority, preserves reachable local work, and marks unreachable local work UNKNOWN. A resuming task that finds another owner or tag keeps its local work unpushed, reports it, and stops. The note grants no authority; the maintainer's confirmation, not the note, prevents two writers. No heartbeat, lease, or coordination service. |
| R17 | Catch implementation mistakes before spending broad CI time. | Meaningful implementation gets one visible independent review from a different model family, preferably a different provider. When a repository explicitly stages expensive hosted CI, review and batch fixes on the candidate before triggering those suites. Always-on required, security, and trust checks remain immediate; changed heads need fresh affected evidence. |

## Design

- **D1 (R1–R3, R9):** one shared `$shaka` skill. Task requirements stay in their
  original record; delivery evidence stays on the PR. No local workflow database.
- **D2 (R2, R4–R7):** a small Ruby command validates repository configuration and
  provides `pr`, `walkthrough`, and `merge`.
  Use `gh` for authentication, pagination, and APIs, JSON for responses, and
  `Open3` argument vectors for execution. Errors are concise and nonzero.
- **D3 (R4, R6):** bind walkthroughs to GitHub's native review commit ID.
  Refresh the PR before publication or merge; require the expected head for merge.
- **D4 (R6–R7):** use live native checks, merge state, and approvals.
  Inspect check states, not just a CLI exit code. Require observable checks
  enforced for the acting account; GitHub owns full enforcement, including
  requirements absent from the reported list. COMMENT never substitutes for APPROVE.
- **D5 (R8, R10):** link the complete skill from a version-controlled trusted source
  into an explicit skills directory. Refuse foreign targets and preserve user settings.
- **D6 (R10):** runtime uses Ruby standard libraries. Development uses Bundler,
  Minitest, and ordinary RuboCop defaults through `bin/validate`.
- **D7 (R2, R12, R17):** repository seams own CI commands and triggers. Shaka orders
  alternate-model review before optional staged hosted CI without copying a consumer's
  label machinery or weakening current-head gates.

The skill is `skills/shaka/SKILL.md`; CLI dispatch is `skills/shaka/scripts/shaka`.
Small modules live in `skills/shaka/lib/shaka/`, behavioral tests in `test/`,
and installation in `bin/install`. YAML carries typed repository policy, Ruby enforces
it, and Markdown explains decisions and human-only constraints.

## Repository seam

The **seam** is `.agents/agent-workflow.yml` plus the executable repository paths it
names. It supplies setup, full and optional pre-review validation, focused tests, an optional
hosted-CI trigger, base branch, review, merge, and branch-protection policy. `AGENTS.md`
supplies human-only context and boundaries.
`shaka seam check` rejects unknown fields, duplicate keys, unsafe paths, missing scripts,
and invalid values. Read authority from the trusted default-branch copy. Candidate policy
edits cannot weaken the current task's requirements. Consumer commands stay in their own
repositories; do not copy Shaka's scripts into them.

## Host boundary

Codex is the reference host. Claude Code skill startup, precedence over a same-named
repository skill, and its usage reader were verified on September 15; a complete
consumer delivery is still required before claiming Claude Code delivery support.
Validate Cursor after that. OpenCode's canonical install path, TUI launcher, and
export-based usage reader follow the same pattern; its consumer delivery is likewise
unverified.
Share the skill and GitHub helpers; keep host installation,
permissions, and native usage readers separate. See [host support](host-support.md)
for tested versions, startup boundaries, and known gaps.

## Merge boundary

The helper checks GitHub facts; the owner establishes authority, local verification,
and acceptable risk. Changes to execution trust, authentication, permissions,
release/deployment, destructive migrations, or merge guards require human review.
Small size does not prove low risk. Unclear authority needs a decision; a safety
failure blocks submission. Require observable native checks enforced for the actor;
unknown or bypass-capable identities block. Leave merge queues and armed auto-merges
unchanged. The current helper performs immediate squash merges while the task is active.

## Verification and exit criteria

- Run `bundle install` for development setup and `bin/validate` locally and in CI.
- Test failed/pending/missing checks, API errors, stale heads, unsupported merge state,
  rejected merges, and safe argument handling.
- Install in an isolated skills directory; repeat installation, preserve foreign
  targets, and verify upgrades use the trusted source.
- Exercise Ask and Auto on real PRs. Publish and read back a walkthrough tied to
  the current head, honor native approvals, and verify protected merge behavior.
- Exercise one meaningful Codex implementation with a visible Claude or Grok review,
  and one consumer's staged hosted-CI path with review fixes completed before dispatch.
- A new user follows [getting started](getting-started.md) in a fresh Codex task
  and reaches a PR without needing another guide. Record the trial on issue #77.
- Interrupt a real unfinished PR, then continue it once from its recovery note in the
  original task and once in a fresh task. Record both on issue #77.
- Before claiming adoption, complete several real changes, including a small fix,
  review fixes, failed CI, and a changed PR head. Unit tests alone do not establish this.

## Success evidence and commit attribution

| Outcome | Evidence and success criterion |
| --- | --- |
| Developer attention | Maintainer estimates and task/PR discussion show less reading, repeated explanation, waiting for late questions, and corrective work. Timestamps do not measure active human time. |
| Tokens | Native records cover planning, implementation, review, retries, and integration. Compare like coverage and cache/model mix; preserve native categories and count each response once. |
| Quality | Tests, real use, review findings, regressions/reverts, and maintainability show a better accepted result with less rework. Green tests and line counts alone are insufficient. |
| Delivery time | Task-to-accepted-outcome time falls without shifting work to the maintainer; distinguish CI and human waiting where known. |

Use [usage reporting](usage-reporting.md) for commit/contribution mappings, shared
intervals, native token categories, and missing-data labels. Include available retries
and contributors, preserve original mappings after squash, and publish aggregate
metadata only. Do not infer routed models from configured settings, present estimated
API-equivalent dollars as actual charges, or interrupt each commit for accounting.
Compare a small sample of similar
accepted changes; describe its uncertainty before making savings claims.

## Scope and rollback

Public source publication and reviewed, verified implementation PR merges are
authorized. Runtime prerequisites are Ruby 3.4, Git, authenticated GitHub CLI,
and GitHub PRs. The `0.1.0.pre.1` RubyGems prerelease reserves the project name;
future registry releases and broader adoption require separate evidence and decisions.
[Packaging](packaging.md) describes the tested gem.
Prospective features and retirement choices belong in issue #36; website work lives
in its own repository and consumes these guides. No fleet coordination, policy engine,
telemetry service, tracker synchronization, or release automation is part of this kernel.

Master and repository control towers may organize work through the existing
Shaka procedure as [optional operating roles](control-towers.md). The focused
`$rct` setup skill establishes one repository tower and registers it with an
existing master; it adds no coordination service or multi-repository owner. Each delivery
retains one owner and the same repository gates. This does not restore V1 fleet
machinery; claim adoption only after a real tower-to-delivery trial.

Rollback: remove the verified skill link or select a prior trusted source revision
and reinstall. Preserve unrelated installations and user files. See
[upgrade and removal](getting-started.md#upgrade).
