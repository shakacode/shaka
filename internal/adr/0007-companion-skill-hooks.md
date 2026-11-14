# 0007: Suggest and use companion skills at named points in the workflow

Status: proposed.
Date: 2026-11-13. Revisions read: Shaka `48874c5`, pstack (`cursor/plugins`) `3dbd22f`,
AI Hero (`mattpocock/skills`) `5863806`, ShakaPerf (`shakacode/shakaperf`) `cd7eae5`.
Related: [issue #206](https://github.com/shakacode/shaka/issues/206) tracks skill and plugin evaluation.

## Context

Shaka already works with other skill packs. [companion-skills.md](../../skills/shaka/references/companion-skills.md)
treats a companion's spec, ticket, review, or PR template as task data, keeps phase order,
review, publication, and the merge decision with the workflow, and declines a companion that
runs its own delivery. [skill-attribution.md](../../skills/shaka/references/skill-attribution.md)
records every applied skill with its source, revision, and phase, and the description publishes
that list as `skills_used`.

What Shaka does not do is bring a companion up on its own. A user has to know that pstack's
`create-verification-skill` exists and name it in the prompt. When a named companion is missing,
the reference says "Do not install it." So most users never meet the skills that would help
them, and we have no way to say "this pack is worth installing next to Shaka" from inside a task.

We want Shaka to act as a guide to a small set of trusted packs: notice when a task reaches a
point where one of their skills helps, then use it or suggest it. Three packs ship configured
out of the box. Two already appear in our docs and many of our users install them, and the
third is our own performance tool:

- **pstack** (Lauren Tan, `cursor/plugins/pstack`): about 60 skills. Most are model-invocable
  techniques and principles. `poteto-mode` and its delivery playbooks run their own delivery.
- **AI Hero** (Matt Pocock, `mattpocock/skills`): about 25 engineering and productivity skills.
  Most planning skills (`grill-me`, `to-spec`, `to-tickets`, `wayfinder`, `retro`, `implement`,
  `implement-spec`) set `disable-model-invocation: true`, so an agent should not start them on
  its own. companion-skills.md already says to honor explicit-only invocation.
- **ShakaPerf** (ShakaCode, `shakacode/shakaperf`): six skills around the `shaka-perf` CLI,
  which runs the base and the change on twin servers and compares speed and screenshots.
  [performance-verification.md](../../skills/shaka/references/performance-verification.md)
  already suggests the CLI by name. The skills cover setup (`shaka-perf-dockerize`,
  `shaka-perf-discover-abtests`), coverage of changed components (`shaka-perf-coverage`,
  `shaka-perf-add-coverage`), and bug hunting against the base (`shaka-perf-find-bugs`).

Other packs, such as Addy Osmani's skills, can come later. Decision 3 lets any repository or
developer add their own packs in the meantime.

### Predecessor check

Not done yet. Before implementation, check `shakacode/agent-workflows` for an existing
companion or skill registry, as AGENTS.md requires.

### Where a skill fits

The question "when would this skill help?" turns out to have an answer already written down.
workflow.yml branches on situations, and each branch links a procedure:

| Situation in workflow.yml | Phase | Linked procedure |
| --- | --- | --- |
| "When that assessment finds design choices the request leaves open" | plan | agree on the design first |
| "For larger tasks, read the task-splitting section" | plan | task splitting |
| "Before changing behavior, identify its triggering state" | implement | reproduce, then fix |
| "Exercise the safety assumption for affected shared callers" | implement | (inline) |
| "search the repository for text that still describes the old one" | implement | (inline) |
| "For UI changes, meaning anything a person sees on screen" | verify | UI verification |
| "When a change aims to speed up page load, rendering, or bundle size" | verify | speed verification |
| local adversarial review | verify | local review |
| "Self-edit those summaries before calling `description`" | explain | publication |

Each row is a moment where a companion technique could do part of the work. Reading the two
packs against these rows places almost every skill without guessing: a skill's description
says when it applies, the explicit-only flag says whether Shaka may start it, and the row says
which Shaka procedure stays in charge.

enforcement.yml already ties entries to workflow.yml by quoting it, and its loader fails when
a quote no longer appears. The same mechanism keeps hook points honest when the workflow text
changes.

## Decisions

1. **Name hook points in a new `skills/shaka/config/companions.yml`.** Each hook has an id, a
   phase, and a `quote` from workflow.yml (or the reference it links) that defines the moment.
   The loader fails when a quote is missing, as enforcement.yml's does. `shaka workflow`
   prints hooks with their phase. Starting set:

   | Hook | Moment |
   | --- | --- |
   | `intake.open_assumptions` | The readback leaves consequential assumptions open |
   | `plan.design` | Design choices the request leaves open |
   | `plan.split` | The task needs several PRs or more than one session |
   | `implement.diagnose` | A bug or regression whose cause is unknown, or two fixes that failed the same check |
   | `implement.shared_callers` | The change touches code with callers outside the diff |
   | `implement.agent_instructions` | The change edits `AGENTS.md`, `CLAUDE.md`, or a skill |
   | `verify.ui` | UI verification, when the repository has no scripted way to drive the app |
   | `verify.speed` | Speed verification, or any measured number the PR reports |
   | `verify.high_risk` | The checkpoint rates the change high risk |
   | `explain.content` | Content Shaka supplies to `description`, `walkthrough`, or `reply` |
   | `retrospective` | `/shaka retrospective`, or the same correction twice in one task |

2. **A packaged catalog maps skills to hooks with one of three modes.**

   - `use`: Shaka applies the technique inside the hook's phase without asking. Only
     model-invocable skills that stay inside the phase and run no workers qualify.
   - `suggest`: Shaka names the skill, says in one line why it fits this task, and either
     runs it after a yes or hands the user the invocation to type. Explicit-only skills, skills
     that fan out workers, and one-time repository setup skills are always `suggest`.
   - `decline`: Shaka does not use the skill inside a task and says why when asked. This covers
     companion orchestrators and skills that duplicate a Shaka rule.

   Starting entries:

   | Hook | Skill | Mode |
   | --- | --- | --- |
   | `intake.open_assumptions` | AI Hero `grill-me` | suggest |
   | `plan.design` | pstack `architect` | suggest, then use at its checkpoint once chosen |
   | `plan.design` | AI Hero `prototype` | suggest |
   | `plan.split` | AI Hero `to-spec`, `to-tickets`, `wayfinder` | suggest |
   | `implement.diagnose` | AI Hero `diagnosing-bugs` | use |
   | `implement.diagnose` | pstack `principle-attack-the-premise` | use after two failed fixes |
   | `implement.shared_callers` | pstack `blast-radius` | use |
   | `implement.agent_instructions` | AI Hero `writing-for-agents` | use |
   | `verify.ui` | pstack `create-verification-skill` | suggest once per repository |
   | `verify.speed` | ShakaPerf `shaka-perf` (compare) | use when the repository has ShakaPerf set up |
   | `verify.speed` | ShakaPerf `shaka-perf-dockerize`, `shaka-perf-discover-abtests` | suggest once per repository |
   | `verify.speed` | pstack `benchmark-checklist`, `principle-explain-the-number` | use |
   | `verify.ui` | ShakaPerf `shaka-perf-coverage`, then `shaka-perf-add-coverage` for changed components with no A/B test | suggest |
   | `verify.high_risk` | pstack `interrogate` | suggest (fans out) |
   | `verify.high_risk` | ShakaPerf `shaka-perf-find-bugs` | suggest, for UI changes when twin servers exist |
   | `explain.content` | pstack `unslop`, `technical-writing` | use, on supplied content only |
   | `retrospective` | pstack `reflect`, `correct`; AI Hero `retro` | suggest |
   | (any) | pstack `poteto-mode` playbooks; AI Hero `implement`, `implement-spec` | decline |
   | (any) | pstack `tdd`; AI Hero `tdd` | decline: Implement already owns failing-test-first |

   `explain.content` keeps the existing rule that the helper renders the body: the skills edit
   the content JSON before `description` runs and never rewrite the rendered body.

   Skills that load on their own by file type, such as pstack `typescript-best-practices`,
   need no hook. The host already loads them.

3. **Allowlisted packs are trusted sources, and anyone can add their own.** The packaged
   catalog lists ShakaPerf, pstack, and AI Hero with each pack's repository and install
   command per coding agent. Shaka treats an allowlisted pack's installed skills the way it
   treats the repository's own instructions: it follows them inside the hook's phase without
   asking where they came from.

   Two more catalog files use the same schema, so people can bring whatever packs they like:

   - `.agents/shaka/companions.yml` in a repository, read from the default branch like other
     trusted settings. A team adds packs, its own skills, or entries at any hook.
   - `~/.agents/shaka/companions.yml` on a machine, beside the reviewer list from
     [ADR 0005](0005-per-machine-reviewers.md). A developer adds packs they use everywhere.

   Repository entries override packaged ones for the same skill. A machine file can add packs
   and `suggest` entries for its owner, but it cannot turn a skill the repository declines back
   on, for the same reason individual settings never override team settings. Settings on a
   candidate branch still grant nothing.

   Trusting a source is different from knowing what ran. Packs update themselves, so Shaka
   records the installed revision in `skills_used`, which it already does when the revision is
   available. `shaka doctor` reports each allowlisted pack, whether it is installed, and its
   revision. A repository that wants a fixed version can pin a revision in settings, and doctor
   then warns when the installed one differs.

4. **Shaka offers to install a missing allowlisted pack.** The rule "Do not install it" changes
   to: when a hook would use or suggest a skill from an allowlisted pack that is not installed,
   say what it would add to this task and offer the catalog's install command. Install only
   after a yes in this task, or under standing consent the user saved, using the same consent
   pattern as review consent. Offer each pack at most once per task, and keep going without it
   when the user declines. Packs that are not allowlisted keep today's rule.

5. **Users can ask for suggestions, and repositories can set defaults.**

   - `/shaka suggest skills` (or "suggest skills" mid-task) lists the hooks this task is likely
     to reach and, for each, the allowlisted skill, its mode, whether it is installed, and one
     line on why. It changes nothing until the user picks.
   - Without that request, Shaka raises a `suggest` entry at most once per hook per task, and
     only when the hook fires. A declined suggestion stays quiet for the rest of the task.
   - Repository settings in `.agents/shaka/config.yml`:

     ```yaml
     companions:
       suggest: true            # false turns off unrequested suggestions
       hooks:
         verify.ui:
           use: [project:verify-app]   # the skill create-verification-skill generated
         explain.content:
           use: [pstack/unslop]
       decline: [pstack/interrogate]
     ```

     A repository can promote a `suggest` entry to `use`, add its own skill at a hook, or
     decline an entry. It cannot promote an explicit-only skill to `use`, and it cannot attach
     a companion orchestrator to a phase.

6. **An entry moves from `suggest` to `use` on eval results.** Every published PR already
   records `skills_used` with phase and revision, plus token usage and timing. The nightly eval
   from [ADR 0001](0001-eval-and-release-gating.md) gains arms with and without a candidate
   entry on the same tasks. An entry becomes `use` in the packaged catalog when it improves at
   least one of review rounds, confirmed findings, or cost per merged PR without making the
   others worse. Entries that never show a gain stay `suggest` or drop out. The catalog
   records the study behind each `use` entry.

## Alternatives considered

- **Leave it to the user to name companions.** This is today's behavior. It works for people
  who already know the packs, and nobody else finds them.
- **Let each skill's own description decide, as the host does.** Hosts already load
  model-invocable skills by description. That gives no say over phase, no way to keep an
  orchestrator out of delivery, and no record of which moment the skill was meant for.
- **Hooks as fields inside workflow.yml phases.** Fewer files, but every catalog change would
  edit the workflow, and workflow.yml is already over 1,000 lines. A separate file with quoted
  anchors keeps the workflow readable and still fails loudly when they drift apart.
- **A broad registry search (skills.sh and similar).** More coverage, but no trust boundary,
  and we would be recommending skills we have never run through the eval. Decision 3's
  catalog files give people the same reach for packs they chose themselves.
- **Pin every pack to a reviewed commit by default.** Safer, but it means someone at ShakaCode
  reviews every upstream release before users get it. Trusting allowlisted sources, recording
  revisions, and letting a repository pin when it wants to gets most of the safety for a fraction
  of the upkeep.

## Consequences

- New file `skills/shaka/config/companions.yml` with a loader, quote validation, and tests,
  modeled on enforcement.yml.
- companion-skills.md gains a section on hooks, the three modes, and the install offer, and
  replaces "Do not install it" for allowlisted packs.
- workflow.yml gains one line per affected phase pointing to companions.yml for that phase's
  hooks. Phase order, validation, review, publication, and merge authority do not change.
- `defaults.yml` and docs/settings.md gain the `companions` section. docs/working-with-shaka.md
  and docs/pstack.md describe suggestions and the AI Hero entries.
- `shaka doctor` reports allowlisted packs, install state, revision, and pinned-revision drift.
- Suggestions add some prompts to a task. The once-per-hook limit and `companions.suggest:
  false` bound that.
- Each `use` entry loads another skill into context. The eval gate is there so that cost has to
  pay for itself.
- When an upstream pack renames or removes a skill, the catalog entry goes stale. Doctor names
  entries whose skill is missing from an installed pack.

## Delivery

Proposed as three PRs:

1. companions.yml with hooks, the loader, quote validation, and `shaka workflow` output. No
   behavior change.
2. Catalog entries for ShakaPerf, pstack, and AI Hero in `suggest` mode only, the repository
   and machine catalog files, `/shaka suggest skills`,
   the install offer, doctor reporting, and the `companions` settings.
3. Eval arms for the first `use` candidates: `blast-radius`, `diagnosing-bugs`,
   `benchmark-checklist`, `shaka-perf` compare, and `unslop` on supplied content. Promote what the results support.
