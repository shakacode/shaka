# PR verification

## Keep the PR easy to read

Lead with the outcome and a short validation result. Put the most useful comparison
beside the explanation; keep longer output and extra captures in expandable
sections. Publish evidence once and link to it from chat.

For example: “The menu stays reachable on narrow screens. The regression test
failed before the fix and passes now; desktop and mobile screenshots show the
result.” Details can hold commands, tested commits, and a recording of the menu.

Shaka uses your existing tests and validation commands, plus browser tools when
needed. Required GitHub checks and approvals still apply.

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
| Layout, styling, or visible output | Test on desktop and mobile; capture before/after screenshots of both. |
| Interaction, animation, or timing | A short recording, with screenshots where they help comparison. |
| Backend or command-line behavior | Focused tests and concise before/after output. |

Inspect screenshots for the intended state, not an error page, blank screen, or
loading placeholder. Review the relevant video frames to confirm the interaction
is visible. Screenshots and video complement tests.

Use safe test data. Before publishing, check for credentials, private task details,
customer data, and unrelated screen content. Expandable sections on public PRs
are public too.

For a user-visible change, the agent also uses the change by hand on the head it
pushes, and repeats that pass after any later commit that changes runtime behavior.
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
