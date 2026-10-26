# Configure

Follow this procedure when the user asks what a reviewer receives: the code review,
checkpoint, or opening check prompt. Explaining every setting and changing settings are
not available yet; for those, say so and link the
[settings reference](https://github.com/shakacode/shaka/blob/main/docs/settings.md).
Stop after answering.

## Show a reviewer's prompt

Run the saved helper:

```text
shaka prompt show (review|checkpoint|opening) --root DIR --ref SHA [--head REV --base REV] [--reviewer PROVIDER/FAMILY]
```

- Pass the verified default-branch commit that `seam check --ref` used. The command reads
  settings and prompt files at that commit, the way the reviewers do.
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
