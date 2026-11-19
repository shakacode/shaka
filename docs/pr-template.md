# Use your pull request template

Shaka's agent can fill your pull request template in every PR description it writes.
It fills the sections you list and follows the notes you leave under each heading.
One more line lets you choose where Shaka's own sections appear.

## Turn it on

Shaka uses your template only when the
[`project_guidance.pr_evidence`](settings.md#project_guidance) setting names a PR
evidence guide: a file the agent reads before it writes a description, saying what
to run and report. The template itself can be that file. Ask your agent:

```text
/shaka Use our pull request template for PR descriptions
```

In Codex, use `$shaka` instead of `/shaka`.

The agent opens a settings PR that points `pr_evidence` at your template:

```yaml
project_guidance:
  pr_evidence: .github/pull_request_template.md
```

If `pr_evidence` already names a guide of your own, such as
`.agents/shaka/pr-evidence.md`, leave the setting as it is. Shaka also finds your
template and shows it to the agent right after the guide, so the agent follows both.
It looks for `pull_request_template.md` or `PULL_REQUEST_TEMPLATE.md` in `.github/`,
the repository root, then `docs/`, and uses the first one it finds. When that template
cannot be read, the agent still sees the guide, with a note saying why, and
descriptions keep the usual order.

Shaka reads the template from your default branch. A PR that edits the template is
still described with the merged version. When you select a
[settings preview](settings.md#where-shaka-reads-a-prompt-file), Shaka reads the
preview's template instead. Changing the template makes earlier
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
- When your template has a heading Shaka already writes, such as `## Summary` or
  `## Verification`, nothing in that section is skipped. The agent puts what it asks
  for into Shaka's own section, so the description shows one Summary, not two.
- Shaka's sections keep their own rules. For example, **Decisions to make** appears
  only when a decision waits on you.
- Nothing checks that the agent followed a comment. Put anything a command can check
  in your [validate script](settings.md#standard-command-scripts) or CI.
- Keep standing rules, such as when to edit `CHANGELOG.md`, in `AGENTS.md`. Use the
  evidence guide for what to run or report.

[Keep changelog notes in PR descriptions](changelog-in-pr-descriptions.md) shows a
complete setup built on one template section.

## Choose where Shaka's sections go

Without a marker, your sections come after all of Shaka's, just above the closing
credit line. To put some of yours first, add this line where Shaka's sections should go:

```markdown
<!-- shaka -->
```

GitHub hides the line, so someone who opens a PR by hand never sees it. For example,
with this template:

```markdown
## Rollout

<!-- How to turn the change on in production. -->

<!-- shaka -->

## Changelog

<!-- One line for users, or None. -->
```

the description reads in this order:

1. The line naming the agent, then the recommendation and review links
2. **Rollout**
3. Shaka's sections, in their usual order, starting with **Summary**
4. **Changelog**
5. The Shaka credit line

Shaka reads the template in a strict format, so nothing depends on guessing:

- The marker is its own line, exactly `<!-- shaka -->`.
- A section heading is a line that starts with `## ` at the left edge. Shaka skips
  lines inside code blocks and inside HTML comments that start a line.
- Headings match by their words, ignoring case, spacing, and closing `#` marks, so keep
  notes on their own line.
- Shaka's sections stay together in their usual order. A heading Shaka already
  writes, such as `## Summary`, does not move them. If the agent writes its own section
  under such a heading anyway, it stays after Shaka's.
- When the agent writes a section your template does not name, it comes right after
  Shaka's sections.
- The opening lines never move. The first line names the agent that wrote the
  description. The recommendation, any decisions waiting on you, and the review links
  follow, so the decision comes first. The credit line stays last.

Each time the agent reads a template that holds the marker, Shaka confirms it found the
marker, restates these rules, and notes a repeated heading or marker.
To see it yourself, ask your agent:

```text
/shaka Show how Shaka reads our pull request template
```
