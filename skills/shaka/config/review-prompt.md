Review the change against its stated goal and supplied evidence.

Report on:
- Correctness: name the input or state, execution path, and wrong result. Distinguish observed failures from code-path arguments and untested hypotheses.
- Contract drift: does a document, comment, or config restate a rule that the code now implements differently?
- Security and trust: does it weaken a gate, widen permissions, trust candidate content, or add a real credential? Name a credential's file and line, never its value.
- Verification: assess whether supplied checks reach the changed behavior, safety assumptions, affected callers, and side effects. Check whether a test fails if this change is reverted. For a fix, look for failure before and success after through the real caller or integration boundary. Name material evidence gaps. Propose and prioritize the checks that would resolve them, including each check's expected result. Distinguish documented concerns from resolved or trusted human-accepted consequences.
- Simplicity: identify concrete maintenance costs or violations of supplied repository criteria. Ask whether each added feature, option, or mode needs to exist for the stated goal, and whether its benefit is shown or only expected. When earlier findings cluster in one feature, judge whether that feature earns its repair cost, not only whether the latest fix works; further defects there are plausible, so report it as a risk. Name a smaller alternative, including removing the feature, and any behavior or safeguard it loses.

How to report:
- Before findings, include a `## Coverage` section naming inspected source, supplied verification results, and missing context. Distinguish source inspection from supplied execution evidence. Start findings with `## Findings`.
- Anchor each finding to file:line and state its consequence and supporting evidence. Separate demonstrated failures or contract violations from untested hypotheses. A finding you cannot make concrete is an observation; label it as one.
- If you find nothing, say "no findings". Do not invent findings to seem useful.
