# Keep changelog notes in PR descriptions

When every PR adds lines under `## [Unreleased]`, two open PRs usually conflict in
`CHANGELOG.md`. The fix takes an agent seconds. The rebase still gives the PR a new
commit, so Shaka runs validation and review again for a change that did not change.

Instead, each PR writes its changelog note in its own description. The release PR
gathers those notes into `CHANGELOG.md` once. Descriptions never conflict, and
reviewers still read the note beside the change.

## Set it up

Ask your agent:

```text
/shaka Move this repository's changelog notes into PR descriptions, following
https://github.com/shakacode/shaka/blob/main/docs/changelog-in-pr-descriptions.md
```

In Codex, use `$shaka` instead of `/shaka`.

The setup PR makes three changes:

1. **A Changelog section in your pull request template.** People who open a PR on
   GitHub see it prefilled. The comment says what to write:

   ```markdown
   ## Changelog

   <!-- One or two lines for users: what they can now do, or what changed for them.
   Write "None" for an internal change. Revise this whenever the change changes.
   The release copies these notes into CHANGELOG.md, so do not edit that file here. -->
   ```

2. **The template as your PR evidence guide.** Shaka's agent reads the template only
   when [`project_guidance.pr_evidence`](settings.md#project_guidance) is set. When you
   already have a guide, Shaka attaches the template to it. Otherwise, point the
   setting at the template:

   ```yaml
   project_guidance:
     pr_evidence: .github/pull_request_template.md
   ```

   The agent then fills the Changelog section and sees the template again each time
   it updates the description. When a later commit changes what users get, it revises
   the note.

3. **Contributor and release instructions.** Your contributing guide or `AGENTS.md`
   stops asking PRs to edit `CHANGELOG.md`. Your release steps build the version
   section from the notes of PRs merged since the previous tag. Entries already
   under `[Unreleased]` stay where they are and ship with the next release.

## What to check at release

Nothing checks the notes automatically. Whoever prepares the release reads each note
beside the PR it describes, fixes a note that went stale, and skips `None`. A
missed note costs one line in one release PR, instead of a conflict on every PR.

Shaka's own [release steps](https://github.com/shakacode/shaka/blob/main/contributing/releasing.md)
show one way to list the merged PRs and read their notes.
