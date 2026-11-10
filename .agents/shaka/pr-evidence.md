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

Check this section on every PR, whether or not the rendering section applies.

A setting is a key that `.agents/shaka/config.yml` can set, as documented in
`docs/settings.md` at the PR's base or head. Command-line defaults under `runtime:` in
`skills/shaka/config/defaults.yml` are not settings: `config.yml` cannot set them.

When a PR adds, removes, or renames a setting, or changes its default or what it does,
add a `Settings changes` section to the description. Give each change a row with the
setting key and its value before and after. Use the shipped default when the key
is unset, as in "default `one` → default `all`", and "(not set)" where the key did
not exist. When only the behavior changes, say what the setting did before and does
now. Add what existing repositories must do: nothing, or the exact edit to
`.agents/shaka/config.yml`. Link the key's `docs/settings.md` anchor at the head, or at
the base for a removed key.

On any other PR, add the line `Settings changes: none.` so a reader can tell it was
checked.

Edits that only change this repository's own `.agents/shaka/config.yml` values are
policy changes, not setting changes. List them in the same section, marked
"this repository only", and write "None" in the Changelog section for them.
