# What to expect from Shaka

Shaka guides your coding agent from a task to a tested, reviewed PR. Your agent
runs the work; its permissions, your project commands, and GitHub rules determine
what it can complete. Start with [installation](getting-started.md), then choose
the setup path below.

## Choose how to start

| Your situation | Expected experience | What you need to do |
| --- | --- | --- |
| The default branch already has Shaka settings | The agent reads those settings, reuses project commands, and starts the feature without another setup PR. | Describe the outcome and any constraints. |
| You want the team to use Shaka | The agent proposes shared settings and command wrappers in a separate setup PR. Feature work follows after that PR merges. | Review the choices and merge the first setup PR yourself. |
| You want to try it in one clone without changing team configuration | Private setup can generate ignored local wrappers and settings using existing project commands. The feature diff should contain no Shaka configuration. | Request a private trial explicitly; read the current limitations below. |
| Your project has no usable tests or validation command | The agent identifies the gap rather than inventing passing evidence. | Decide whether adding checks belongs in this task or whether the PR must report limited verification. |

Shared configuration is the repository **seam**: it connects project commands
and settings to Shaka. Team policy comes from the default branch, not a feature
PR. Private setup is local operational configuration; it grants neither team
policy nor permission to merge.

### Private trials: available tools, incomplete guided experience

```text
$shaka Implement this small feature using this repository's existing commands.
Try Shaka privately in this clone. Do not create a team setup PR or include
Shaka configuration in the feature diff. Keep merge policy ask.
```

This prompt describes the intended trial. It is not yet a demonstrated seamless
new-user path. The [first-task acceptance report](https://github.com/shakacode/shaka/issues/277#issuecomment-5904859759)
identifies the evaluated installation and records a verified maintainer-led
feature PR with interventions. Its entry workflow still selected team setup, and reviewer selection,
walkthrough, and handoff operations failed when reading an absent team seam.
An agent also edited private settings to suppress local locations in public WIP Details.

The [private setup procedure](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/repository-setup.md#try-shaka-privately-in-one-clone)
exists, including recovery copies and exclusions. Its availability does not mean
every delivery operation supports that source. Expect an unsupported operation
to be reported with its failure and any manual fallback disclosed. A guided run
with interventions does not establish seamless new-user acceptance.
A newer installation needs its own validation before these limits are removed.

## Run an ordinary task

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

The agent confirms the repository and task, checks for existing work, and explains
scope, risk, and its model recommendation. `Go` without a named model or effort
accepts the current host settings. Naming either setting can require confirmation
when it differs or the host cannot report it. A prompt does not switch models.

Expect questions when the participant, checkout, desired behavior, or a consequential
choice is missing. Existing scripts and CI should supply routine setup and check
commands. The agent should not ask you to edit PATH or write configuration by hand
as an ordinary task step. If access, dependencies, or unsupported configuration
prevent progress, expect a concrete blocker and the next action.

The normal result is a feature PR with an outcome summary, validation results,
independent review, a code walkthrough, available usage, and remaining decisions.
Tests show which behavior was exercised; a green review job alone does not prove
that a reviewer completed. See [PR verification](pr-verification.md).

## Understand the PR's settings and evidence

Expand the settings block to see the source and effective choices used for the
candidate. The publication helper redacts selected settings values; this is not a
general privacy scan. A settings block describes the run;
it does not prove tests or review happened.

| What changes or fails | Expected response |
| --- | --- |
| Validation fails | Fix the demonstrated problem, then rerun the affected checks. The PR stays unverified until they complete. |
| The candidate changes after tests or review | Check whether the evidence still covers the candidate; rerun affected work when it is stale. |
| Material command or review settings change | The workflow requires reassessing affected evidence. Live consumer settings transitions remain untested; do not assume an earlier pass is current. |
| A result is missing, a reviewer is unavailable, or CI is still running | Show the gap explicitly. Missing or stale evidence cannot satisfy a required gate. |
| An optional reviewer is pending | Disclose it and follow the configured waiting choice; required gates still apply. |

Public PRs must contain no private task content, operational settings, or
private-content fingerprints. Expandable details are still public. WIP Details
can include workspace and chat locations by default; decide whether to suppress
them before publication. See [WIP settings](settings.md#wipinclude_locations).
Privacy still requires the agent to inspect the publication.

## Decide whether to merge

The default is Ask: expect the ready PR back for your decision. The
[merge policy guide](working-with-shaka.md#choose-a-merge-policy) explains Ask,
Auto, and approval after a branch update. The workflow tells the agent to retain
explicit task merge authorization within its scope; that persistence remains
untested in a live consumer trial. Planning-only, review-only, and PR-only
requests stop at their requested outcome.

Authorization does not bypass GitHub approval rules or release restrictions.
Changes that alter behavior after approval can need renewed approval of the new
commit. Merging a feature PR does not by itself publish a package or deploy a release.

## Resume or change your checkout

| Scenario | Expected experience and recovery limit |
| --- | --- |
| Resume the same task with a PR | The workflow directs the agent to refresh PR state and evidence. Open WIP Details and return to the owner, or give a new chat the PR URL after the previous owner stops. Fresh-chat acceptance remains untested. |
| Resume before a PR exists | Supply the task and checkout. The intended path is local inspection; there is no PR record from which to recover missing choices. Fresh-chat acceptance remains untested. |
| Use a linked worktree with private setup | Each worktree has its own local settings identity and recovery copy in the common Git directory. Host permissions must allow the required writes. |
| An outside pull adds team settings | Inspect adoption and compare saved private settings. Default-branch team policy governs; do not overwrite it with the private copy. |
| Clean or delete a private worktree | Previously captured settings may be restored outside a checkout for comparison. Uncaptured edits and deletion of the common Git directory cannot be recovered from those copies. |
| Upgrade an older configuration layout | Use the reviewed migration procedure. A private destination collision stops migration for comparison rather than overwriting it. |

Use the [resume guide](working-with-shaka.md#resume-unfinished-work) and
[migration guide](migration.md). Private recovery protects captured configuration;
it is not a backup of feature changes or the agent conversation.

## When the coding agent denies access

Expect the failed operation and path to be reported, with no claim of completion.
Use the host's supported permission mechanism for the necessary operation, then
retry and verify it. Shaka does not create a sandbox or grant filesystem access.

Codex workspace permissions can allow ordinary project edits while denying the
protected Git writes needed by private setup. That denial was observed in normal
and linked worktrees; successful approval/retry remains untested. Claude Code
also needs permission for setup; supplemental checks completed with explicit Bash
allowances. An unrestricted session proves no sandbox outcome.

## What the pilot has established

A verified consumer feature PR demonstrates guided delivery. The linked acceptance
report separates passed, partial, and untested cases, including supplemental
recovery and migration checks. These results support guided trials; they do not
establish broad rollout readiness.
