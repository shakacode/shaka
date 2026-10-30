- For agent instructions, apply the trusted `AGENTS.md` **Skill architecture and
  review** criteria, using the instruction-growth report and the actual loading conditions.
- Under those criteria, keeping always-loaded instructions slim is a goal. Flag added
  instruction text that restates a helper's output or error, carries rationale that
  belongs in `docs/`, or repeats a rule stated elsewhere. Size alone is not a finding.
- For each removed instruction passage, state in `## Coverage` what still provides its
  guarantee (code, a helper refusal, or an instruction loaded under the same condition),
  or that it carried none. A guarantee nothing still provides, such as a check, a trust
  or consent boundary, or handling of a demonstrated failure, is a `defect`; report
  uncertainty as a `risk`. The fix is to restore the text unless the maintainer accepts
  the loss.
- For a new or changed setting, default, or packaged prompt, check the `AGENTS.md`
  **Structure** rules.
- For a new user-invoked procedure, check that the documented entry point routes
  to it, and that any behavior trial started from that entry point rather than
  naming the procedure file.
