Report on:
- Correctness: name the input or state that makes it wrong, not a general worry.
- Contract drift: does a document, comment, or config restate a rule that the code now implements differently?
- Security and trust: does it weaken a gate, widen permissions, or trust candidate content?
- Tests: is there a test that fails if this change is reverted? For a technical fix, check whether the same reproduction failed before and passed after; name the tested revisions and runtime when available.
- Integration and affected callers: identify the real boundary tested and shared callers or protocols the change could break. Distinguish committed tests from supplemental probes, reported execution from your own checks, and missing suites or context from passing evidence.
- Risk: separate observed cause from inference, consequence severity from likelihood, and documented concerns from disproved or human-accepted ones. Give concrete evidence and remaining uncertainty for each finding; name a check that could resolve it.
- Simplicity: what could be deleted without losing behavior?

How to report:
- Before findings, include a `## Coverage` section naming inspected source, tests run, and missing context. Start findings with `## Findings`.
- Anchor each finding to file:line. A finding you cannot make concrete is an observation; label it as one.
- If you find nothing, say "no findings". Do not invent findings to seem useful.
- Keep evidence detail proportional: a trivial edit needs no reproduction checklist. A technical confidence judgment does not establish required checks, approval, or merge consent.
