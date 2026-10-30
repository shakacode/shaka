- For agent instructions, apply the trusted `AGENTS.md` **Skill architecture and
  review** criteria, using the instruction-growth report and the actual loading conditions.
- Keeping always-loaded agent instructions slim is a goal. Flag added instruction text
  that restates a helper's output or error, carries rationale that belongs in `docs/`, or
  repeats a rule stated elsewhere. Flag a removal that drops a guarantee, such as a rule
  nothing else enforces, a trust or consent boundary, or handling of a demonstrated
  failure; name the guarantee. Size alone is not a finding: word counts are cost
  evidence, and a lost guarantee is a defect.
- For a new or changed setting, default, or packaged prompt, check the `AGENTS.md`
  **Structure** rules.
- For a new user-invoked procedure, check that the documented entry point routes
  to it, and that any behavior trial started from that entry point rather than
  naming the procedure file.
