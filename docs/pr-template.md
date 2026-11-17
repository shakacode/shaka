# Use your pull request template

Shaka's agent can fill your pull request template in every PR description it writes.
It fills the sections you list and follows the notes you leave under each heading.
One more heading lets you choose where Shaka's own sections appear.

## Turn it on

Shaka reads the template beside your PR evidence guide, the file the agent reads
before it writes a description. Ask your agent:

```text
/shaka Use our pull request template for PR descriptions
```

In Codex, use `$shaka` instead of `/shaka`.

The agent opens a settings PR that points
[`project_guidance.pr_evidence`](settings.md#project_guidance) at your template:

```yaml
project_guidance:
  pr_evidence: .github/pull_request_template.md
```

When you already have a separate evidence guide, keep it. Shaka then shows the agent
your template after the guide. It looks for `pull_request_template.md` or
`PULL_REQUEST_TEMPLATE.md` in `.github/`, the repository root, then `docs/`, and
uses the first one it can read. When the template cannot be read, the agent sees
the guide and a note saying why.

Shaka reads the template from your default branch. A PR that edits the template is
still described with the merged version. Changing the template makes earlier
validation and review results for open PRs out of date.

## Tell the agent what each section needs

Put instructions in an HTML comment right below a heading. GitHub hides the
comment in the rendered description. The agent applies it to the change at hand.

```markdown
## Rollout

<!-- Say how to turn the change on in production. Omit this section when
nothing needs to be turned on. -->
```

- The agent fills each section unless its comment says to leave it out for this
  change. It then drops both the heading and the body.
- A heading Shaka already writes, such as `## Summary`, tells the agent to put that
  content in Shaka's own section instead of adding a second one.
- Shaka's sections keep their own rules. For example, **Decisions to make** appears
  only when a decision waits on you.
- Nothing checks that the agent followed a comment. Put anything a command can check
  in your [validate script](settings.md#standard-command-scripts) or CI.
- Keep standing rules, such as when to edit `CHANGELOG.md`, in `AGENTS.md`. Use the
  evidence guide for what to run or report.

[Keep changelog notes in PR descriptions](changelog-in-pr-descriptions.md) shows a
complete setup built on one template section.

## Choose where Shaka's sections go

Without a Shaka heading, your sections come after all of Shaka's, just above the
closing credit line. To choose the spot, add one of these headings to the template:

| Heading | Shaka's other sections appear |
| --- | --- |
| `## Shaka` | In one collapsed block labeled Shaka, which readers expand |
| `## Shaka Inline` | Expanded, at that spot |

For example, with this template:

```markdown
## Summary

<!-- What changed and why. -->

## Shaka

## Rollout

<!-- How to turn the change on in production. -->
```

the description reads in this order:

1. The line naming the agent, then the recommendation and review links
2. **Summary**
3. A collapsed **Shaka** block holding Intent, Verification, Shaka metrics, and the rest
4. **Rollout**
5. The Shaka credit line

With `## Shaka Inline` in place of `## Shaka`, item 3 shows the same sections expanded.

The order follows these rules:

- Each `##` heading in the template puts its section at that spot. The section can be
  yours or Shaka's. For example, `## Verification` keeps verification outside the fold.
- When the agent writes a section your template does not name, it joins Shaka's sections.
- Shaka reads only `##` headings. It skips those inside code blocks and inside HTML
  comments that start a line.
- The opening lines never move. The first line names the agent that wrote the
  description. The recommendation, any decisions waiting on you, and the review links
  follow, so the decision comes first. The credit line stays last.
- The fold never hides what you act on. **Summary**, **Before and after merge**,
  **Human comments**, and an unfinished PR's **WIP Details** stay in view just above it.
- Text inside the fold does not count toward [prose limits](settings.md#prose_limits),
  like the body of any collapsed block.

The heading only marks a spot; the description has no section called Shaka. People who
open a PR on GitHub without Shaka see the heading in the template. A comment under it,
such as `<!-- Shaka fills this in. -->`, tells them to leave it.
