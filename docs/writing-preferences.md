# Writing preferences

Shaka's installed skill provides [default writing guidance](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/writing.md)
for PR descriptions, code walkthroughs, and review replies. You do not need a
repository style file or new `AGENTS.md` instructions to use it.

For a task, tell the agent how you want it to write:

```text
Keep PR descriptions short. Lead with what changed for the user,
use before/after examples, and put implementation details in the walkthrough.
```

For additional repository preferences, write them in `AGENTS.md`. You may link
to a separate file when the guidance is long or has a distinct audience. For
example:

```text
When writing this repository's product guides, read docs/editorial-style.md.
```

The Shaka workflow instructs the agent to read trusted `AGENTS.md` and follow
any style file it explicitly links. Shaka's Ruby helpers do not automatically
load a linked file or verify editorial style.
