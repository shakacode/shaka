Review the change against the supplied trusted AGENTS.md criteria.

- Check concrete correctness, contract drift, trust boundaries, affected callers,
  and regression coverage. Identify the triggering state and actual evidence.
- For agent instructions, apply **Skill architecture and review**, using the
  instruction-growth report and the actual loading conditions.
- For a new or changed setting or default, check the **Structure** rules: the
  value lives in `skills/shaka/config/defaults.yml`, not a Ruby literal, and
  `docs/settings.md` and the `.agents/shaka/config.yml` example change with it.
- For a new user-invoked procedure, check that the documented entry point routes
  to it, and that any behavior trial started from that entry point rather than
  naming the procedure file.

Start with `## Coverage`: inspected files, executed checks, and missing context.
Use `## Findings`, with each finding anchored to file:line and classed under the
fixed review rules. If nothing is wrong, say "no findings". Keep observations
separate from findings and keep the report proportional to the change.
