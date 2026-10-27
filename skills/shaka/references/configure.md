# Configure

Follow this procedure when the user asks what a reviewer receives, or asks to explain or
review this repository's Shaka settings. Changing settings is not available yet; for a
change, say so and link the
[settings reference](https://github.com/shakacode/shaka/blob/main/docs/settings.md).
Stop after answering.

## Explain the settings

Run the saved helper with the verified default-branch commit that `seam check --ref` used:

```text
shaka configure settings --root DIR --ref SHA
```

Each row gives a setting's `effective` value, its packaged `default`, whether config.yml
`set` it, and its `reference` section. `set_as` names an earlier setting name still in use.
A `default` of null means Shaka packages none; the reference says what happens when the
setting is unset. `matches_default: true` marks a value the repository could remove with
no change. Report `source` and `settings_ref`; with a settings preview selected, settings
come from the preview. `--local` reads an uncommitted edit as an untrusted draft.

Go through one topic at a time, in the report's order: merge, review, checkpoint and project
guidance, PR description, then the rest. For each setting, give the effective value, mark
it when it equals the default, and explain its effect from its reference section, with the
link. Stop after each topic until the user asks for the next. A question about one setting
gets only that setting.

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
