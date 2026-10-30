- For agent instructions, apply the trusted `AGENTS.md` **Skill architecture and
  review** criteria, using the instruction-growth report and the actual loading conditions.
- Under those criteria, keeping always-loaded instructions slim is a goal. Flag added
  instruction text that restates a helper's output or error, carries rationale that
  belongs in `docs/`, or repeats a rule stated elsewhere. Flag a removal that loses a
  guarantee, such as a check, a trust or consent boundary, or handling of a demonstrated
  failure. Class and report each as those criteria require: a demonstrated lost
  guarantee is a defect, and size alone is not a finding.
- For a new or changed setting, default, or packaged prompt, check the `AGENTS.md`
  **Structure** rules.
- For a new user-invoked procedure, check that the documented entry point routes
  to it, and that any behavior trial started from that entry point rather than
  naming the procedure file.
