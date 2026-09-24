# PR verification

## Keep the PR easy to read

Lead with the outcome and a short validation result. Show the most useful comparison
near the explanation; put longer test output and extra captures in a labeled
expandable section. Keep the evidence in one place and link to it from chat.

For example: “The menu now stays reachable on a narrow screen. The regression
test failed before the fix and passes now; desktop and mobile screenshots show
the result.” The PR's details can identify the commands, tested commits, and
recording of the menu opening and closing.

Screenshots and video complement tests. Required GitHub checks and merge
approvals still apply.

Shaka uses your repository’s test and validation commands, plus browser tools
when needed. It works with your existing test framework.

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
do not need invented failing tests. The validation command can select checks
for the affected files; required security checks still apply.

## Documentation changes

Check links and rendered pages. For a substantial rewrite, also check whether a
reader can complete the intended task. An agent follows the
[documentation-verification procedure](../skills/shaka/references/documentation-verification.md)
when assessing navigation or changed instructions.

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
