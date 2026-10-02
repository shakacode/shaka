# PR verification

Use a Shaka PR to understand the change, assess its evidence, and decide what
needs closer review. The same record helps you revisit decisions after merging.

## Read a PR for your decision

Start with the description for the outcome, open decisions, and steps besides
merging. Follow the code walkthrough for implementation choices and alternatives.
Then inspect the supporting evidence for the revision you are reviewing.

| Your question | Where to look |
| --- | --- |
| What changes for users? | The description, preview, and visual comparisons when applicable. |
| Why this approach? | The walkthrough, linked code, alternatives, and maintenance-cost assessment. |
| How was it checked? | Validation results and independent review covering the current revision, including gaps. |
| What happened to concerns? | Review findings, replies, and recorded fixes or reasons for declining a suggestion. |
| What do I need to do? | Open decisions and steps besides merging, with their timing and owner. |

For example, a CSV export PR may use a simple download instead of a background
job. The walkthrough should explain that choice; tests should exercise the
export behavior. You can then judge whether the approach suits the expected
volume and whether important cases are missing.

## Revisit a merged change

Assess the decision and the process separately:

- **Was the approach reasonable?** Compare the recorded goal, alternatives, and
  risks with what was known then and what you learned after deployment. A working
  feature can still introduce more maintenance than its benefit justifies.
- **What evidence supports the process?** Check which revision was tested and
  reviewed, how findings were handled, and which gaps or exceptions were reported.
  Missing evidence leaves a question open; it does not establish that a step
  passed or failed.

For the CSV export, later growth may justify a background job. The original
walkthrough helps distinguish changed needs from an assumption that lacked support.
The test and review records help you examine how that assumption was checked.

Shaka makes the recorded work inspectable. It does not prove that every workflow
instruction was followed or that the tests and review were sufficient. See
[what is enforced](workflow.md#what-is-enforced).

## Keep the PR easy to read

Lead with the outcome and a short validation result. Put the most useful comparison
beside the explanation; keep longer output and extra captures in expandable
sections. Publish evidence once and link to it from chat.

For example: “The menu stays reachable on narrow screens. The regression test
failed before the fix and passes now; desktop and mobile screenshots show the
result.” Details can hold commands, tested commits, and a recording of the menu.

Shaka uses your existing tests and validation commands, plus browser tools when
needed. Required GitHub checks and approvals still apply.

## Reconsider the finished result

Before calling a change ready to merge, Shaka asks whether the result solves the
original problem for the intended users and earns its maintenance cost. It compares
the actual scope and complexity with the plan and considers simpler alternatives.
Unexpected growth or repeated repairs can prompt this review earlier.

The final walkthrough or a separate PR comment explains one conclusion:
**Proceed**, **Simplify/reframe**, or **Do not merge**. Substantive unresolved concerns
hold readiness and Auto even when technical checks pass. This judgment rests with
the agent; Ruby does not verify that it happened or assess its quality.

For example, a settings page may satisfy the task but introduce an interface most
users never need. The agent can recommend extending an existing setting instead
before more work builds around that page. Maintainers can customize the
[default review prompt](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/post-implementation-validation.md#customize-for-the-project)
with their audience and architectural priorities.

## Change one behavior at a time

The agent writes a focused test, confirms it fails because the behavior is broken
or missing, then fixes the code and simplifies it while tests stay green. Tests
exercise behavior through public interfaces; matching implementation details or
instruction wording does not prove the result.

When automation is impractical, record the limitation and useful before/after
evidence. Wording edits need documentation checks, not invented failing tests.
Validation can select checks for affected files; required security checks still apply.

## Documentation changes

Check links and rendered pages. For a substantial rewrite, check whether a reader
can complete the intended task. See the agent's
[documentation-verification procedure](../skills/shaka/references/documentation-verification.md).

## Show what a person will see

| Change | Useful evidence |
| --- | --- |
| Layout, styling, or visible output | Test on desktop and mobile; capture before/after screenshots of both, with [annotations explaining meaningful changes](#show-what-changed-between-captures). |
| Interaction, animation, or timing | A short recording, with screenshots where they help comparison. |
| Backend or command-line behavior | Focused tests and concise before/after output. |

Inspect screenshots for the intended state, not an error page, blank screen, or
loading placeholder. Review the relevant video frames to confirm the interaction
is visible. Screenshots and video complement tests.

Use safe test data. Before publishing, check for credentials, private task details,
customer data, and unrelated screen content. Expandable sections on public PRs
are public too.

For any on-screen change other than command-line output, the agent also uses the
change by hand on the head it pushes, and repeats that pass after any later commit
that changes runtime behavior.
When the PR has a preview deployment, it checks the preview too, or says why not.

Attach captures to a PR comment with GitHub CLI 2.99 or later, then open the
comment to confirm each path became an uploaded link. A local path is not shared
evidence.

```sh
gh pr comment 42 --attach './before-desktop.png#Menu before, desktop' \
  --attach './after-desktop.png#Menu after, desktop' --attach './menu-open.mp4'
```

Text after `#` is an image's alt text; a video takes no alt text.

Label the tested commit and behavior. After code changes, refresh affected
evidence or explain which part still applies. When a capture cannot be published,
the PR records why: `uploader_absent` (no attachment route is available),
`uploader_denied` (the upload was refused), or `upload_failed:` with the error.

## Show what changed between captures

See the resulting UI with a few numbered boxes, highlights, or arrows explaining
what changed. The original before and after captures stay available, so a reviewer
can inspect the change beyond those callouts.

For example, when three sidebar links are added, three boxes on the new screenshot
identify them. A pixel difference can instead highlight every following row because
it moved. For a removed element, a labeled before crop supplies the missing context.

The agent compares the whole affected view before choosing annotations and labels
both intended and unexpected changes. Callouts explain the comparison; they do not
prove that the UI works. The [visual-evidence procedure](../skills/shaka/references/visual-diff.md)
provides the agent's capture, annotation, and publication steps.

Comparable captures use the same route, viewport, theme, scroll position, test data,
and interaction step. When layout changes, animation, or live data prevent alignment,
the comparison explains that limit. A short recording remains useful for timing and interaction.

Pixel differences are optional diagnostic evidence, kept in expandable details when
useful for investigating subtle color, opacity, or unintended changes. Rendering
noise and moved content can dominate them; a highlighted pixel is not itself a defect.

## Show whether it is faster or slower

Some changes aim to speed up page load, rendering, or bundle size, or could slow them.
Others change what a page loads or how it is cached or streamed. For these, the agent
compares the base with the change on pages and metrics that reach the change. It uses
the repository's own benchmark when there is one, and
[ShakaPerf](https://github.com/shakacode/shakaperf#usage) otherwise.

The PR reports the verdict: improvement, wash, regression, or ambiguous. It names the
pages, metrics, sample count, and the base and change commits. Any regression or
ambiguous result, and a wash for an intended speed-up, go back for a fix or for the
maintainer to accept. When no comparison can run, the PR says the speed was not measured.

## Approval and attention labels

[Working with Shaka](working-with-shaka.md#find-prs-waiting-on-you) lists the labels
and your next action.

You don't create these labels. The first time the agent needs one in a repository,
it creates it: `awaiting-answer` in amber, `awaiting-merge-approval` in purple, and
`awaiting-resume` in blue, each with a description. Recolor or reword them freely; the agent never changes a
label that already exists. Creating a label needs write access; with triage access
the agent can still apply labels someone else created.

When the PR description lists decisions for you, its publication helper applies
`awaiting-answer` and removes `awaiting-resume`. The helper refuses to publish
those decisions while `awaiting-merge-approval` is set.
An empty decisions list removes that section and `awaiting-answer`, and leaves the other
two labels in place.

To approve, tell the agent in chat. An **Approve** review on GitHub also counts
when it comes from a login you named to the agent as a merge approver; GitHub does
not let the account that opened the PR approve it. Return to the chat so the agent
can act on the approval. If GitHub requires updating the branch first, the agent
rebases, revalidates, and merges without asking again. When a branch rule requires
GitHub approval of the new commit, it asks for that approval. When the rebase changes
behavior, with or without conflicts, it explains the difference and asks you to
approve the new commit. While it waits for either approval, the PR keeps its
`awaiting-merge-approval` label.

A PR carries at most one of these labels. The agent removes it when work resumes.
Search `is:open label:awaiting-answer`, `is:open label:awaiting-merge-approval`, or
`is:open label:awaiting-resume` to see your queue. Nothing but the agent clears these labels, so one can go stale
if the agent stops before work resumes; remove it by hand.

## Squash merge details

When a PR is ready for your merge, the agent posts the squash commit message as the
PR's last comment, just above the merge button: a title such as `Add CSV export (#42)`
and a short plain-text body that says what changed and why, followed by the branch
commits' `Co-authored-by` lines. Each block has a copy button; paste them into
GitHub's squash merge boxes. When the head changes, the agent posts a new comment
and deletes the old one. When the agent merges under **Auto**, it sends the same
message itself, except through a merge queue, which uses the repository default.

GitHub fills those boxes from a repository setting, by default with every branch
commit's title. To start from the PR title and an empty body instead, set **Settings →
General → Pull Requests → Allow squash merging** to **Default to pull request title**.
