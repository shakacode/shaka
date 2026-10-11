Review the change against the supplied trusted AGENTS.md criteria.

- Check concrete correctness, contract drift, trust boundaries, affected callers,
  and regression coverage. Identify the triggering state and actual evidence.
- For agent instructions, apply **Skill architecture and review**, using the
  instruction-growth report and the actual loading conditions.

Start with `## Coverage`: inspected files, executed checks, and missing context.
Use `## Findings`, with each finding anchored to file:line and classed under the
fixed review rules. If nothing is wrong, say "no findings". Keep observations
separate from findings and keep the report proportional to the change.
