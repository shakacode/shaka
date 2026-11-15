# 0009: Suggest and use companion skills at skill points

Status: proposed.
Date: 2026-11-14. Revisions read: Shaka `c3e92e8`, pstack (`cursor/plugins`) `3dbd22f`,
AI Hero (`mattpocock/skills`) `5863806`, ShakaPerf (`shakacode/shakaperf`) `cd7eae5`,
`shakacode/agent-workflows` `d85ecea`.
Related: [issue #206](https://github.com/shakacode/shaka/issues/206) tracks skill and plugin
evaluation. [#1132](https://github.com/shakacode/shaka/pull/1132) proposes how a companion's
results appear on a PR; this record covers when Shaka brings a companion up at all.

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

### Where a skill fits

Two procedures already name a companion at the step where it helps:
[retrospective.md](../../skills/shaka/references/retrospective.md) has "Use the companion when
it is installed," and performance-verification.md suggests ShakaPerf. Each loads only when its
condition applies, so the suggestion costs nothing on tasks that never reach it. This record
turns that pattern into the mechanism instead of adding a list of moments beside workflow.yml.

### Predecessor check

`shakacode/agent-workflows` has no companion catalog, modes, or install offer. Its ADRs 0002
and 0004 record, in prose, which phases Compound Engineering and Superpowers may own. That is
the ownership rule companion-skills.md already follows, so there is no code to reuse.

## Decisions

1. **A procedure owns its skill point.** A *skill point* is a step in a procedure Shaka
   already loads conditionally, where a companion skill can do part of the work. The procedure
   declares it with one line that runs `shaka companions POINT`, where `POINT` is the
   procedure's file and heading, such as `ui-verification#ui-changes`. That line is the only
   declaration: a test derives the set of points from those lines and fails when an id no
   longer matches its file and heading. workflow.yml gains nothing, and no file lists moments
   a second time. companion-skills.md defines the term once. Starting points:

   | Skill point | The point line runs when |
   | --- | --- |
   | `delivery#agree-on-the-design-first` | the user chooses to agree on the design first |
   | `delivery#when-a-task-needs-several-prs` | a larger task needs splitting |
   | `ui-verification#ui-changes` | the change is something a person sees on screen |
   | `performance-verification#verify-a-speed-affecting-change` | the change affects speed |
   | `post-implementation-validation#recommend-the-next-action` | a checkpoint, at Finish or mid-task, rates the change high risk |

   delivery.md and the checkpoint procedure load on most tasks, not only when their point
   applies: the plan step reads delivery.md for the value line, and the checkpoint runs on
   every task. Each point line therefore states the condition it runs under: the user chose
   to agree on the design first, the task needs several PRs, or the checkpoint rated the
   change `high` under [the risk rubric](../../skills/shaka/config/post-implementation-risk.md).
   A task that meets none of them sees no suggestion from those files.

   retrospective.md gets no point and keeps its companion section unchanged. It reads an
   installed companion's analysis, including explicit-only ones such as AI Hero `retro`,
   under stricter rules than a pack mode can express: never a checkout skill, no install,
   and session content treated as data.

   The command reads repository settings at the trusted `--ref`, the way `guidance` does, and
   applies every layering and trust rule below in Ruby. It prints, for each skill, the mode,
   why that mode applies, whether it is installed, and the pack's revision.

2. **Each pack file maps its skills to points with one of three modes.** Packaged packs live
   in `skills/shaka/config/packs/`, one file each. A pack file names the pack's source, how
   to tell its installed copy from a same-named skill, its install command per coding agent,
   and for each skill: the mode at each point, a one-line reason, and whether it is
   explicit-only, fans out workers, or is one-time setup.

   - `use`: Shaka applies the technique inside the procedure's phase without asking. Only
     model-invocable skills that stay inside the phase and run no workers qualify.
   - `suggest`: Shaka names the skill, says in one line why it fits this task, and either
     runs it after a yes or hands the user the invocation to type. Explicit-only skills,
     skills that fan out workers, and one-time setup skills are always `suggest`. Ruby takes
     the stricter of the pack file's explicit-only flag and the installed skill's front
     matter, so an upstream change cannot raise a mode.
   - `decline`: Shaka does not use the skill inside a task and says why when asked. This
     covers companion orchestrators and skills that duplicate a Shaka rule.

   Starting entries, all `suggest` until a study supports `use` (decision 6):

   | Skill point | Skill | Mode |
   | --- | --- | --- |
   | design first | AI Hero `grill-me`, `prototype`; pstack `architect` | suggest |
   | task splitting | AI Hero `to-spec`, `to-tickets`, `wayfinder` | suggest |
   | UI | pstack `create-verification-skill`, once per repository | suggest |
   | UI | ShakaPerf `shaka-perf-coverage`, then `shaka-perf-add-coverage` | suggest |
   | speed | ShakaPerf `shaka-perf-dockerize`, `shaka-perf-discover-abtests`, until `abtests.config.ts` exists | suggest |
   | speed | pstack `benchmark-checklist`, `principle-explain-the-number` | suggest; first `use` candidates |
   | high risk | pstack `interrogate` (fans out); ShakaPerf `shaka-perf-find-bugs` when twin servers exist | suggest |
   | (any) | pstack `poteto-mode` playbooks; AI Hero `implement`, `implement-spec` | decline: orchestrator |
   | (any) | pstack `tdd`; AI Hero `tdd` | decline: Implement owns failing-test-first |

   performance-verification.md keeps running `shaka-perf compare` as it does today; a pack
   setting never weakens what a procedure already requires.

   pstack `unslop` and `technical-writing` get no skill point and no decline. companion-skills.md
   already applies their prose advice to the content Shaka supplies, and the workflow's
   agent-enforced rule says not to invoke a separate rewrite skill at publication. Whether
   either should change belongs to the writing-style work in
   [#210](https://github.com/shakacode/shaka/issues/210), not to this record.

   Skills that load on their own by description, such as pstack `blast-radius` or
   `typescript-best-practices` and AI Hero `diagnosing-bugs`, need no point. The host already
   loads them.

3. **The maintainer turns packs on, and anyone can add their own.** A packaged `use` entry
   applies only after the repository's settings or the developer's machine file lists its
   pack under `companions.packs`. Until then it acts as `suggest`. This keeps trust where the
   [trust model](../../docs/workflow.md#trust-model) puts it: ShakaCode chose the packaged
   list, but the maintainer, or a developer for their own machine, chooses which third-party
   instructions run without asking.

   ```yaml
   companions:
     packs: [shakaperf]   # packaged `use` entries from these packs apply
     use: []              # promote a packaged suggest entry for this repository, within the fixed limits
     decline: []          # a skill or a whole pack, never raised in this repository
     pins: {}             # pack: revision; doctor warns when the installed one differs
     suggest: true        # false stops suggestions nobody asked for
   ```

   - A repository adds its own skills with a pack file under `.agents/shaka/packs/`, read
     from the trusted settings source. When Shaka uses a project skill, it loads it from the
     trusted commit, its whole directory and not only `SKILL.md`, so a candidate branch
     cannot change what it says or runs. Hosts may still load checkout skills by
     description, outside this mechanism. A project skill that is new or changed on the candidate branch comes
     back declined, because a candidate branch grants nothing.
   - `~/.agents/shaka/companions.yml` on a machine, beside the reviewer list from
     [ADR 0005](0005-per-machine-reviewers.md), can turn packs on and decline skills for its
     owner. It has no `use` key, and it cannot lift a repository's decline, for the same
     reason individual settings never override team settings. Personal packs go in
     `~/.agents/shaka/packs/`, and their `use` entries act as `suggest` for the same reason.
   - Ruby applies declines last and matches skills by their installed path, not their label,
     so re-declaring a packaged skill under another pack name inherits every limit on it.

   Trusting a source is different from knowing what ran. Packs update themselves, so Shaka
   records the installed revision in `skills_used`, which it already does when the revision is
   available. `shaka doctor` reports each pack that is turned on, whether it is installed, its
   revision, and any pinned-revision drift.

4. **Shaka offers to install a missing packaged pack.** The rule "Do not install it" changes
   to: when a skill point lists a skill from a packaged pack that is not installed, say what
   it would add to this task and offer the pack's install command. Install only after a yes
   in this task, or under standing consent the user saved, using the same consent pattern as
   review consent. Offer each pack at most once per task, and keep going without it when the
   user declines. Packs that are not packaged keep today's rule.

5. **Users can ask for suggestions.** `/shaka suggest skills` (or "suggest skills" mid-task)
   runs `shaka companions --all` and lists, for each point this task is likely to reach, the
   skill, its mode, whether it is installed, and one line on why. It changes nothing until the
   user picks. Without that request, Shaka raises a `suggest` entry at most once per point per
   task, records the answer in the task record, and keeps a declined suggestion quiet for the
   rest of the task.

6. **An entry moves from `suggest` to `use` on ADR 0001's evidence.** A candidate gets paired
   eval runs with and without it on the same tasks, using
   [ADR 0001](0001-eval-and-release-gating.md)'s quality score and cost accounting. It is
   promoted when the mean per-task quality delta is at least D8's threshold tau with p below
   0.05, the same test D8 uses for a loss turned toward a gain, and the cache-neutral cost
   ratio stays within D9's 1.2 limit or the higher cost is accepted in writing. Review rounds,
   confirmed findings, and cost per merged PR are supporting evidence, not the test. ADR 0001
   does not yet name skill presence as a comparison axis or state a gain rule, so both are
   additions it needs, not new bars this record sets. A packaged `use` entry links the study
   behind it, and the loader refuses a packaged `use` without one. The study rule binds what
   ShakaCode ships to everyone. A repository's own `companions.use` promotion, or a `use`
   entry in its own pack file, is the maintainer's choice: it needs no study and no `packs`
   entry, and it stays within the fixed limits on explicit-only, fan-out, setup, and declined
   skills.
   ADR 0001's comparison runs are not built yet, so until they are, nothing is promoted and
   every packaged entry stays `suggest`. PRs that report `skills_used` add real-use context,
   but those entries are optional and agent-reported, so they inform a study rather than
   replace it.

## Alternatives considered

- **Leave it to the user to name companions.** This is today's behavior. It works for people
  who already know the packs, and nobody else finds them.
- **Let each skill's own description decide, as the host does.** Hosts already load
  model-invocable skills by description. That gives no say over phase, no way to keep an
  orchestrator out of delivery, and no record of which moment the skill was meant for. This
  record still relies on it for skills that fit no procedure.
- **A central catalog that quotes workflow.yml for each point**, validated the way
  enforcement.yml is. It covers moments written inline in workflow.yml, such as diagnosing a
  bug, checking shared callers, and editing agent instructions, which no procedure owns. It
  costs a marker on each point in every rendered workflow plus an instruction to use them,
  and a third file anchored to workflow text whose `when` conditions repeat what the linked
  procedures already say. Procedure ownership loses those three moments and costs five lines
  in four procedure files, two of which load only when needed; the other two state their
  own conditions.
- **Points as fields inside workflow.yml phases.** Fewer files, but every catalog change would
  edit the always-loaded workflow, which is already over 1,000 lines.
- **A broad registry search (skills.sh and similar).** More coverage, but no trust boundary,
  and we would be recommending skills we have never run through the eval. Decision 3's pack
  files give people the same reach for packs they chose themselves.
- **Pin every pack to a reviewed commit by default.** Safer, but someone at ShakaCode would
  review every upstream release before users got it. Turning packs on per repository,
  recording revisions, and optional pins get most of the safety for a fraction of the upkeep.
- **Let the agent read pack files and settings itself.** No new command, but the agent would
  read them from the candidate checkout and apply the layering rules from prose. That breaks
  "a candidate branch grants nothing," and puts deterministic rules in Markdown.

## Consequences

- New `shaka companions` command with packaged pack files, a pure resolver with table tests
  for each layering and trust rule, and a test that derives points from procedure lines.
  The installed-skill scan moves out of `Doctor::CompanionSkills` so doctor and the command
  share it.
- companion-skills.md gains a skill points section, the three modes, and the install offer,
  and replaces "Do not install it" for packaged packs. Four procedure files gain five point
  lines; delivery.md holds two.
- `defaults.yml`, docs/settings.md, and the `.agents/shaka/config.yml` example gain the
  `companions` section. The machine file is a new home-directory exception that
  docs/settings.md names beside the machine reviewer list.
- Reading installed `SKILL.md` front matter and comparing a project skill's file with the
  trusted commit are new reads the configuration boundary test will need to admit.
- Suggestions add some prompts to a task. The once-per-point limit and `companions.suggest:
  false` bound that.
- Each `use` entry loads another skill into context. Decision 6 requires a measured gain
  before promotion, so that cost has to pay for itself.
- Delivery step 3 waits on ADR 0001's comparison runs.
- When an upstream pack renames or removes a skill, its pack entry goes stale. The command
  warns, and doctor names entries whose skill is missing from an installed pack.

## Delivery

Proposed as three PRs:

1. `shaka companions`, the pack file schema, the resolver, the point lines in the five
   procedures, and companion-skills.md's definition, with no packaged entries. No behavior
   change.
2. Packaged pack files for ShakaPerf, pstack, and AI Hero in `suggest` mode only, repository
   and machine pack files, `/shaka suggest skills`, the install offer, doctor reporting, and
   the `companions` settings.
3. Once ADR 0001's comparison runs exist, eval runs for the first `use` candidates,
   `benchmark-checklist` and `principle-explain-the-number`, and promotion of what the
   results support.
