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
`set` it, and its `reference` section. `set_as` names an earlier setting name still in use.
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

Answer with the sections in order and each one's source. Lead with the parts the
repository controls: replacement prompts, `AGENTS.md` files, and custom instructions.
Summarize long built-in text unless the user asks for it verbatim. A `placeholder` stands
for data the reviewer gets at run time, such as the diff or earlier findings. No reviewer
reads `project_guidance` files; the working agent does.

## Change a setting

A settings change is its own PR. Ruby refuses a feature PR that changes Shaka's
configuration, and the description publisher refuses it too.

1. Read the current value with `configure settings --ref`, then tell the maintainer, before
   editing, whether installations must update after merge, as the next section decides.
2. Start a branch from the fresh default branch. Edit the file the report names as
   `config_path`, keeping its comments. Set only the keys the change needs.
3. Show the result with `configure settings --root DIR --local`, and with `prompt show
   NAME --local` when the change names a prompt or instructions file. Run
   `seam check --root DIR --local`; a failure stops the change.
4. Publish through the migration flow: `evidence guard --flow migration` before staging and
   push, and `description --publication-flow migration`. List the update step from the next
   section in `steps_besides_merging`, or `none` when that section says no update is needed.
5. The change takes effect when its PR merges. To try it on one task first, follow
   [settings preview](settings-preview.md).

### Say when installations must update

An installation older than a key, an option of a choice, or a nested shape refuses the
whole settings file, so every task on it stops. An unneeded update costs one command.

- No update is needed when every key path and value the change writes already appears in
  the trusted `config_path` at `--ref` (`git show REF:CONFIG_PATH`). Every working
  installation already loads those.
- Otherwise list the update, and name when the key or value entered the reference, from
  the saved helper's source: `git -C SOURCE log --reverse --format='%cs %h' -S 'TEXT' --
  docs/settings.md`. The maintainer judges whether their team's installations are older.
- List it whenever you cannot tell.

List it as `after merge`: Update Shaka (`shaka install --update`), who: everyone running
Shaka on this repository, where: each machine with an installation, verify: `shaka doctor
--brief` reports Repository seam HEALTHY. Ruby checks none of this; the agent applies it.
