# Development records

Public project records for Shaka maintainers. These files are not product setup
instructions or private company plans.

- [Requirements and acceptance](requirements.md) — original scope and remaining evidence.
- [Coding-environment trials](coding-environment-trials.md) — dated observations, not a support matrix.
- [Test fleet](fleet.md) — repository adoption and migration evidence.
- [Local evaluation proposal](local-evaluation-proposal.md) — proposed experiments, not shipped behavior.
- [Eval and release-gating decision record](adr/0001-eval-and-release-gating.md) — proposed comparison design and execution-layer spike.
- [Install locations and no-compatibility decision record](adr/0002-install-locations-and-no-compatibility.md) — accepted install defaults, worktree refusal, opt-in updates, and no backward compatibility before 1.0; not yet shipped.
- [Configuration walkthrough decision record](adr/0003-configure-walkthrough.md) — accepted `configure` entry, settings and prompt reports from Ruby, and migration-flow settings PRs; not yet shipped.
- [Per-machine reviewers decision record](adr/0005-per-machine-reviewers.md) — accepted quieting of reviewer setup warnings that selection never needs, and an optional per-machine reviewer list with model and effort; not yet shipped.
- [Walkthroughs on request decision record](adr/0007-walkthroughs-on-request.md) — walkthroughs on request by default, offered at handoff, with `always` to keep one on every PR; implemented in #1186.
- [Size delivery to the task decision record](adr/0008-size-delivery-to-the-task.md) — accepted draft-first opt-in as step 1, with risk-scaled evidence skips and on-demand bookkeeping as later options; not yet shipped.
- [Companion skill points decision record](adr/0009-companion-skill-points.md) — proposed skill points in the procedures that load when a task reaches them, where ShakaPerf, pstack, and AI Hero skills are suggested by default; a packaged `use` entry, once a study supports it, applies only after the repository or machine turns the pack on.
- [PR retrospective decision record](adr/0010-retrospective-over-merged-prs.md) — proposed PR record report beside `timings report`, and a retrospective across merged PRs that reads it.
- [Experiment index](../eval/README.md) — retained repositories, outcomes, and the next proposed case.
- [Review outcomes](review-outcomes.md) — proposed record of review decisions and later assessments, not shipped behavior.
- [Improving Shaka](improving-shaka.md) — maintainer method for investigating observed workflow failures.
- [Documentation structure](documentation.md) — help users start with the skill and consult guides as needed.
- [Rendering preview](rendering-preview.md) — how an agent shows a rendering change on its own PR.
- [Conditional workflow loading](conditional-workflow-loading.md) — bounded extraction and Ponytail structure comparison.
- [Predecessor retirement](retirement.md) — temporary migration record; remove after its acceptance conditions are met.
