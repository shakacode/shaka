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
