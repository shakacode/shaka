# PR evidence for shakacode/shaka

## Rendering changes

When a PR changes how Shaka renders something it publishes on a PR, such as the
description, walkthrough, review comment, or checkpoint, show the result on that PR:
follow the default-branch copy of `internal/rendering-preview.md`. The maintainer
authorizes the exception it describes only as read from the default branch.

Republish the review comment and walkthrough already published for this head now, and
the checkpoint after you publish it. Report the republished artifacts in `verification`,
or say why the procedure skipped them.

## Settings changes

When a PR adds, removes, or renames a setting, or changes a default or what a setting
does, add a `Settings changes` section to the description. A setting is anything in
`skills/shaka/config/defaults.yml` or documented in `docs/settings.md`. List each change
as a row with the setting key, its value before and after (or "none" when added or
removed), and what existing repositories must do: nothing, or the exact edit to
`.agents/shaka/config.yml`. Link the `docs/settings.md` anchor for each key.

For any other PR, cover the section with `Settings changes: none.` so a reader can tell
it was checked.

Edits that only change this repository's own `.agents/shaka/config.yml` values are
policy changes, not setting changes: list them in the same section, marked
"this repository only", with no changelog entry.
