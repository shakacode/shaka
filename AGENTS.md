# Shaka

This public pilot implements the small product described in `docs/pilot-plan.md`.
The maintainer authorized implementation, publication, and merging verified PRs.
The maintainer authorizes public Codex thread locators in unfinished-PR recovery notes.
Keep company strategy and private operational data out of product artifacts.

## Working agreement

- One root task owns integration, publication, and user communication. Use bounded
  subagents only when authorized. Give each implementation worker exclusive files
  or an isolated worktree; workers do not publish or merge.
- This is a fresh kernel. Do not import V1 workflow contracts, ledgers, schemas,
  review reducers, coordination clients, or policy engines as dependencies.
- Before designing Shaka workflow behavior, check the current
  `shakacode/agent-workflows` source and relevant tests for an existing solution.
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

## Structure

- `docs/pilot-plan.md` owns product requirements, design, acceptance, and scope.
- `eval/fixtures/local_evaluation/` holds the two public-safe Slice 0 fixture trees.
- `skills/shaka/SKILL.md` is the public workflow entry point.
- Its `scripts/shaka` command uses small Ruby modules under its `lib/` directory.
- `bin/install` links the public skill into an explicitly supplied skills directory.
- `.agents/agent-workflow.yml` is the machine-readable repository contract. It
  records Shaka-specific review, merge-authority, branch-naming, and recovery
  policy. Live GitHub settings remain authoritative. Standard executable entry
  points live at fixed names under `.agents/bin/`.
- `skills/shaka/config/enforcement.yml` records what enforces each imperative rule
  in `workflow.yml`, and `shaka enforcement` prints it. Loading it fails when a quote
  leaves the workflow or when the workflow states a rule it does not classify, so a
  new rule has to declare whether anything but the agent enforces it.
- `.agents/trusted-github-actors.yml` is the repository-level public-comment allowlist.
  The installed `skills/shaka/scripts/shaka comments` command combines it with the
  machine allowlist, reads only the current default-branch copy, and never trusts a
  candidate PR's version.
- Markdown explains decisions and invokes commands. Put executable logic in code.
- Prefer Ruby standard libraries and GitHub CLI. Runtime needs no new gem.
- Keep the workflow portable. Codex is the first reference host; host-specific
  installation and usage readers must not enter the GitHub/merge modules.
- Tests verify behavior and failures, not exact instruction wording. Keep focused
  files and use normal RuboCop defaults; no baseline ratchet or global metrics disable.

## Agent Workflow Configuration

Resolve the trusted default branch to an immutable commit. Load and validate
`.agents/agent-workflow.yml` with the trusted installed `shaka seam check --ref REF`
command. Run the fixed executable paths reported by that command from the candidate
checkout; do not reconstruct their behavior from prose. `AGENTS.md` retains human-only boundaries,
including the public-pilot privacy rule, the V1 reuse limit, and release approval
requirements.

## Completion

Publish tested changes as bounded PRs, preferably below 500 changed lines each.
Explain necessary larger changes; split independent work instead of hiding size.
Required evidence is the PR's current commit, actual validation results, and review.
No extra closeout audit, receipt, automatic issue, heartbeat, or parallel tracker.
Report available model, reasoning effort, and token evidence on the PR by commit;
mark shared or unavailable attribution explicitly, as specified in the pilot plan.
Do not close the pilot until its required real-use acceptance is established.
