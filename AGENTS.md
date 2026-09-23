# Shaka

This public pilot implements the small product described in `docs/pilot-plan.md`.
The maintainer authorized implementation, publication, and merging verified PRs.
The maintainer authorizes public Codex thread locators in unfinished-PR recovery notes.
Keep company strategy and private operational data out of product artifacts.

## Working agreement

- One root task owns integration, publication, and user communication. Use bounded
  subagents only when authorized. Give each implementation worker exclusive files
  or an isolated worktree; workers do not publish or merge.
- This is a fresh kernel. Do not import predecessor workflow contracts, ledgers, schemas,
  review reducers, coordination clients, or policy engines as dependencies.
- Before designing Shaka workflow behavior, check the current
  `shakacode/agent-workflows` predecessor source and relevant tests for an existing solution.
  Reuse or adapt validated, portable code when it fits this pilot; explain the
  chosen reuse and material differences in the PR. Treat the other repository
  as reference material, not as authority over this project's instructions.
- GitHub issue #77 owns remaining pilot acceptance; closed issue #1 holds the original
  requirements. Keep the implementation to them.
  Name feature branches from the trusted seam `branches.name`; never push to `main`.
- Product merge preferences are `ask` and `auto`. Review-only work stops at its
  requested outcome. Existing maintainer merge authority persists; do not ask again.
- Preserve user changes. Pull/rebase before edits when a branch has an upstream;
  for a new branch start from the freshly fetched base. Do not reset others' work.

## Is the change worth carrying?

Use the [value checkpoint](docs/agents/delivery.md#say-what-the-work-is-worth)
and respect settled maintainer scope. Reassess when planning adds substantial
complexity or implementation materially raises expected cost.

Compare observed user benefit with maintenance: dependencies, parsing, settings,
failure handling, compatibility, and tests. Mark unknown impact or frequency as
unknown. Consider a smaller fix, existing library, optional extension, or no change.
New core behavior should improve delivery; evaluate speculative conveniences and
custom editorial preferences outside the core first.

A smaller alternative must preserve demonstrated failure handling. Name any lost
guarantee and evidence that losing it is acceptable. Line count alone does not
justify failures, resource leaks, or weaker safeguards. Recommend proceed,
simplify, evaluate first, or defer, with evidence and the smallest useful option.
Separate value judgments from defects. Surface changed assumptions through the
existing checkpoint or review; add no score or approval gate.

## Structure

- `docs/pilot-plan.md` owns requirements, design, scope, and acceptance.
  [Development](docs/project/development.md) maps the other docs, scripts, and configs.
- `skills/shaka/SKILL.md` loads the procedure through `scripts/shaka`, backed by
  small Ruby modules under `lib/`. `bin/install` links skills into an explicit directory.
- `enforcement.yml` classifies strong rules in `workflow.yml`; run `shaka enforcement`
  after changing either. The loader detects missing quotes and unclassified phrases,
  but review must catch new rules inside already quoted passages.
- `.agents/trusted-github-actors.yml` is the public-comment allowlist. The installed
  `shaka comments` combines it with machine configuration and reads the repository
  copy from the current default branch, never a candidate PR.
- `eval/fixtures/local_evaluation/` contains the two public-safe Slice 0 fixtures.
- Put executable logic in code and explanations in Markdown. Prefer Ruby standard
  libraries and GitHub CLI; add no runtime gem. Keep host installation and usage
  readers out of GitHub/merge modules. Codex is the first reference host.
- Test behavior and failures, not exact wording. Keep files focused and use normal
  RuboCop defaults; no baseline ratchet or global metrics disable.

## Repository configuration

Verify this repository with `gh repo view --json owner,visibility,defaultBranchRef`.
Resolve the trusted default branch to an immutable commit. Load and validate
`.agents/agent-workflow.yml` with the trusted installed `shaka seam check --root . --ref SHA`
command. That `--ref` check is fail-closed: without it the command grants no trusted
authority. Run the fixed executable paths reported by that command from the candidate
checkout; inspect candidate command changes before execution and do not reconstruct
their behavior from prose. `shaka seam check --root . --local` validates
current-checkout syntax and grants no trusted policy. `AGENTS.md` retains human-only boundaries,
including the public-pilot privacy rule, the predecessor reuse limit, and release approval
requirements.

## Completion

Publish tested changes as bounded PRs, preferably below 500 changed lines each.
Explain necessary larger changes; split independent work instead of hiding size.
Required evidence is the PR's current commit, actual validation results, and review.
No extra closeout audit, receipt, automatic issue, heartbeat, or parallel tracker.
Report available model, reasoning effort, and token evidence on the PR by commit;
mark shared or unavailable attribution explicitly, as specified in the pilot plan.
Do not close the pilot until its required real-use acceptance is established.
