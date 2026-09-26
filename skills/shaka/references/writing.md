# Writing guidance

Before publishing, reread each summary for these points:

- Lead with the outcome its reader notices.
- Give each sentence one main idea and a clear subject and verb.
- Put conditions beside the behavior they limit.
- Use familiar words; explain necessary technical terms.
- Keep exact commands, identifiers, risks, and evidence intact.
- In replies, state the decision and use the thread's existing context.
- Delete greetings, praise, repeated explanations, and claims of significance
  that add no information.

For example, replace “Adds validation of the configured base parameter” with
“Shaka now rejects an invalid base branch before the agent starts work.” A code
walkthrough can then explain the validation and its edge cases.

Use the `writing_style.guide` returned by trusted `shaka seam check` output when
the repository has `.agents/writing-style.md`. `AGENTS.md` can still supply
broader project instructions and writing preferences, including a pointer to
another Markdown style file. Read such a pointer from the trusted branch, not
the candidate change. When they conflict, current task instructions win,
followed by user-level writing instructions, trusted `AGENTS.md` instructions,
then the conventional style defaults.

Self-edit the content JSON; do not rewrite the rendered GitHub body or invoke a
separate rewriting skill for Shaka's publication step. No prose score or style
schema is needed.

## Loading repository defaults

`shaka seam check --root ROOT --ref SHA` reads the optional
`.agents/writing-style.md` from the same resolved default-branch commit as the
repository settings. It returns the text as `writing_style.guide`. A candidate
change cannot replace that guide while its own PR is being described.

The file must be non-empty UTF-8 text in a regular file, at most 100 KiB.
The loader checks size before reading content and rejects symlinks, directories,
and submodules. Markdown is the convention, not a syntax check.

Local and implicit candidate checks validate the file without returning its
prose; invalid candidate files fail the check. Under `--ref`, an invalid guide
instead produces a warning on stderr and in `writing_style_warning`, and the
guide is omitted. Report the problem and continue using the remaining writing
instructions. Required repository policy stays available.

`shaka doctor` checks repository configuration but does not validate this style
file. Use `shaka seam check --root ROOT --local` to check a candidate file.
For an existing `AGENTS.md` pointer to this conventional path, replace any symlink
with a regular file before adopting automatic loading. Other style-file pointers
remain supported through the trusted `AGENTS.md` instructions above.

Ruby verifies file loading and validation, not writing quality or compliance
with the guide. Applying preferences and resolving their precedence remain agent
responsibilities; review actual output before claiming improved writing.
