<a id="tests-and-visual-evidence"></a>

# Verify code, interfaces, and documentation

A useful PR proves the behavior and shows what changed. The agent uses the fixed
`.agents/bin/test` and `.agents/bin/validate` entry points, plus app startup instructions
and browser tools where needed. Keep executable routing in those scripts and human-only
test context in `AGENTS.md`; V2 does not introduce a test framework or require a
particular screenshot service.

## Change one behavior at a time

For a bug, the agent first reproduces it in a focused regression test. For a new
behavior, it writes the smallest test that describes the expected result. It runs
the test and checks that it fails because the behavior is missing or broken.
A missing import or bad fixture is a test setup problem, not a useful failure.

The agent makes the smallest change that passes that test, then simplifies the
code while keeping tests green. Tests should exercise behavior through real public
interfaces. Assertions that merely repeat the implementation or match instruction
wording do not prove that users will get the right result.

If an automated test is impractical, the agent explains the limitation and records
the closest useful before/after verification. Documentation-only wording changes
do not need invented failing tests. Before publishing, the agent runs the repo's
validation entry point and the relevant focused checks.

## Evaluate documentation by its reader's task

Correct links, rendered pages, and passing code tests catch mechanical problems.
They do not show that someone can find an answer, understand it, or act correctly.
Line counts and token budgets constrain size; they do not establish usefulness.

Before a substantial rewrite, name the audience and a few tasks the document must
support. Map important removed instructions to their new destination, or explain why
they are no longer needed. Preserve direct routes to common tasks and existing anchors.
A shorter page that hides an essential answer is a regression.

Use separate entry points for people and agents, with one maintained source for each
rule. Human guides explain the goal, choices, examples, and recovery. The agent skill
specifies execution order, required references, authority, and stopping conditions;
Fixed `.agents/bin/` scripts supply repository-specific commands, while `AGENTS.md`
supplies human-only constraints and repository context. An agent can also be a
reader of a human guide, so test that use when it is part of the product.

| Reader and task | Useful evidence |
| --- | --- |
| A person wants to control merging | Starting at the README, finds the merge choice and explains what Ask and Auto authorize, including required approvals. |
| A person wants to install and complete a first task | Follows the guide in a fresh session through a PR; record missing steps, wrong turns, questions, and corrections. |
| A maintainer needs help with review, usage, or upgrades | Finds the named guide from the entry page without knowing filenames or searching the repository. |
| An agent follows the procedure | In an isolated trial, takes the correct actions for a bounded task: preserves review-only scope, points an Ask-ready PR at GitHub merge, and respects Auto's required gates. |
| An agent consumes a rewritten guide | Completes the same representative task with the old and new guide; compare omitted requirements, incorrect actions, interventions, and available usage. |

Give a trial reader the document's normal entry point and task, without extra hints
from its author. Observe what they do and ask them to explain their next action.
An author's walkthrough or another model's prose review can find defects, but is not
a substitute for an observed fresh-reader result. An agent trial does not prove human
readability; a human review does not prove agent execution. Label each kind of evidence.
Use a human trial when making a human-usability claim and an agent trial when changing
execution instructions. Repeat ambiguous agent results before claiming reliability.

Match the effort to the change. A typo or repaired link needs a focused check; a
reorganization needs task-based navigation review; changed procedural instructions
need relevant behavior trials. For comparisons, hold the task, starting state, and
agent model/settings constant where possible. Report the tested revision, reader type,
result, corrections, and evidence gaps on the existing PR. Treat token savings as
secondary to correct task completion and human attention. Do not add wording tests
or infer success from the document's length.

## Show what a person will see

| Change | Useful evidence |
| --- | --- |
| Layout, styling, or visible output | Before/after screenshots of the affected view, including a narrow viewport when layout changes. |
| Interaction, animation, or timing | A short recording of the relevant flow, plus screenshots where they make comparison easier. |
| Backend or command-line behavior | Focused tests and concise before/after output; screenshots are usually unnecessary. |

The agent opens and inspects the captured images. It checks that they show the
intended state, rather than an error page, blank screen, or loading placeholder.
For a recording, it reviews the relevant frames and confirms the interaction is
visible. Capturing a file alone is not verification.

Use safe test data. Inspect files before publishing and keep credentials, private
task details, customer data, and unrelated screen content out of them. A public
PR's expandable sections are public too.

Publish evidence using an existing supported attachment or artifact route. Confirm
that the intended reviewer can open it; a local file path is not shared evidence.
Label the tested commit and the behavior shown. If the code changes, update affected
evidence or say clearly which part still applies. Missing access or failed capture
is an evidence gap, never a successful visual check.

## Keep the PR easy to read

Lead with the outcome and a short validation result. Show the most useful comparison
near the explanation; put longer test output and extra captures in a labeled
expandable section. Keep the evidence in one place and link to it from chat.

For example: “The menu now stays reachable on a narrow screen. The regression
test failed before the fix and passes now; desktop and mobile screenshots show
the result.” The PR's details can identify the commands, tested commits, and
recording of the menu opening and closing.

Screenshots and video complement automated tests. They do not replace required
GitHub checks or grant merge permission. No evidence manifest, new storage service,
recording daemon, or separate approval step is required.
