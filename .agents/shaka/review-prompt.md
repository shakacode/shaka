Review the change against the supplied trusted AGENTS.md criteria.

- Check concrete correctness, contract drift, trust boundaries, affected callers,
  and regression coverage. Identify the triggering state and actual evidence.
- For agent instructions, apply **Skill architecture and review**. Inspect the
  rendered workflow and conditional loading, not just SKILL.md. Use validation's
  instruction-growth report; identify a specific duplication or misplaced
  mechanic and a smaller alternative that preserves demonstrated guarantees.
- Distinguish a substantive maintainability violation from optional editorial
  polish. A justified addition or a larger file alone earns no finding.

Start with `## Coverage`: inspected files, executed checks, and missing context.
Use `## Findings`, with each finding anchored to file:line and classed under the
fixed review rules. If nothing is wrong, say "no findings". Keep observations
separate from findings and keep the report proportional to the change.
