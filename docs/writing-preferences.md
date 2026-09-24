# Writing preferences

A PR should make the reviewer's job easier. Start with what changed for the user
and why, then provide the evidence needed to judge it. Keep implementation detail
in the walkthrough and longer records in expandable sections.

Shaka's [default writing guidance](../skills/shaka/references/writing.md) is part
of the installed skill. To customize it for a repository, put preferences in
`AGENTS.md`, or create `.agents/writing-style.md` and add a pointer to `AGENTS.md`:

```text
Before writing PR descriptions, walkthroughs, or review replies, read
.agents/writing-style.md and apply its writing preferences.
```

For example, the file might ask for short paragraphs, before/after examples, and
plain language for readers unfamiliar with the implementation. The agent follows
the version from trusted repository instructions. The file is ordinary Markdown;
Shaka does not auto-discover it or require another configuration key.
