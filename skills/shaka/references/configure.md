# Configure

Follow this procedure when the user asks what a reviewer receives, asks to explain or
review this repository's Shaka settings, or asks to change a setting. Stop after answering,
or after handing off the settings PR.

## Explain the settings

Run the saved helper with the verified default-branch commit that `seam check --ref` used:

```text
shaka configure settings --root DIR --ref SHA
```

Each row gives a setting's `effective` value, its packaged `default`, whether config.yml
`set` it, and its `reference` section.
A `default` of null means Shaka packages none; the reference says what happens when the
setting is unset. `matches_default: true` says only that the value equals the default.
Do not call such a setting removable: some settings are required, and naming a file can
make it required. Report `source` and `settings_ref`; with a settings preview selected,
settings come from the preview. `--local` reads an uncommitted edit as an untrusted draft.

Group the settings by their first key, such as `merge`, `review`, or `pr_description`, and
go through one group at a time. For each setting, give the effective value, mark it when it
equals the default, and explain its effect from its reference section, with the link. Stop
after each group until the user asks for the next. A question about one setting gets only
that setting.

## Show a reviewer's prompt

Run the saved helper:

```text
shaka prompt show (review|checkpoint|opening) --root DIR --ref SHA [--head REV --base REV] [--reviewer PROVIDER/FAMILY]
```

- Pass the verified default-branch commit that `seam check --ref` used. The command reads
  settings and prompt files at that commit, the way the reviewers do. When a settings
  preview is selected, settings come from the preview, as they do for the reviewers; say so.
- Add `--head` and `--base` when the user asks about a specific change. A nested
  `AGENTS.md` reaches a reviewer only when the change touches its directory. Without a
  change, the output shows the root file and lists each nested one with its directory.
- For `review`, the output uses the first configured reviewer unless you pass `--reviewer`.
  Reviewers can differ in source lookup and in a per-reviewer `replacement_prompt_file`.
- To preview an uncommitted settings edit, pass `--local` in place of `--ref`. Every
  section is then labeled an untrusted draft. Tell the user a draft grants nothing and
  takes effect only when its settings PR merges.

List the sections in the order the reviewer reads them, each with its source, and mark
the ones the repository controls: replacement prompts, `AGENTS.md` files, and custom
instructions. Summarize long built-in text unless the user asks for it verbatim. A
`placeholder` stands for data the reviewer gets at run time, such as the diff or earlier
findings. No reviewer reads `project_guidance` files; the working agent does.

## Change a setting

A settings change is its own PR. Ruby refuses a feature PR that changes Shaka's
configuration, and the description publisher refuses it too.

1. Read the current value with `configure settings --ref`. Before editing, tell the
   maintainer whether installations must update after merge, as the next section says.
2. Start a branch from the fresh default branch. Edit the file the report names as
   `config_path`, keeping its comments. Set only the keys the change needs.
3. Show the result with `configure settings --root DIR --local`, and with `prompt show
   NAME --local` when the change names a prompt or instructions file. Run
   `seam check --root DIR --local`; a failure stops the change.
4. Publish through the migration flow: `evidence guard --flow migration` before staging and
   push, and `description --publication-flow migration`. Put the update step from the next
   section in `steps_besides_merging`, or `none` when that section lists none.
5. The change takes effect when its PR merges. To try it on one task first, follow
   [settings preview](settings-preview.md).

### Say when installations must update

An installation older than a key, an option, or a nested shape refuses the whole settings
file, so every task on it stops. Whether a teammate's installation is that old cannot be
checked from the repository, so list the update on every settings PR that adds or changes
a setting's value. A change that only removes keys, or writes no setting, such as one that
edits only a prompt file or a comment, lists none.

Date each new key and each new named option, such as a new choice for a setting, by
searching the saved helper's source for the key's heading or the option:

```text
git -C SOURCE log --reverse --format='%cs %h' -S '## `KEY`' -- docs/settings.md
git -C SOURCE log --reverse --format='%cs %h' -S 'OPTION' -- docs/settings.md
```

Give the date as unknown when the search finds nothing or only an unrelated mention. Give no date for a new
number, path, or text under a key the repository already sets. Say in the step that
installations older than the date refuse the settings, so the maintainer can judge whether
anyone needs it.

List it as `after merge`: Update Shaka (`shaka install --update`), who: everyone running
Shaka on this repository, where: each machine with an installation, verify: `shaka doctor
--brief` reports Repository seam HEALTHY. Ruby checks none of this; the agent applies it.
