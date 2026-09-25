# Writing preferences

Lead with what changed and why. Show the evidence needed to judge it; keep
implementation detail in the walkthrough and longer records in expandable sections.

For a task, tell the agent how you want it to write:

```text
Keep PR descriptions short. Lead with what changed for the user,
use before/after examples, and put implementation details in the walkthrough.
```

For persistent repository defaults, add `.agents/writing-style.md`:

```markdown
# Writing style

- Lead with the outcome a user notices.
- Keep PR descriptions short; put implementation detail in the walkthrough.
- Use before-and-after examples when they clarify behavior.
```

`shaka seam check --ref SHA` reads this optional file from the same immutable
default-branch commit as the repository settings. The conventional format is
Markdown; Shaka requires non-empty UTF-8 text in a regular file of at
most 100 KB so the loader can bound memory and prompt use before reading it.
Directories, submodules, and symlinks are rejected. A change in the current PR
therefore cannot rewrite the style used to describe or review that PR. Local and
implicit candidate checks reject an invalid file before merge but never return
its prose.

An invalid optional style file produces a warning and is omitted from the seam
output. The warning appears on stderr and as `writing_style_warning` in the JSON,
so the agent reports it and continues with the baseline guidance; review, merge,
branch, and command policy remain available.

Current task instructions take precedence, followed by user-level writing
instructions, trusted `AGENTS.md` writing instructions, and the conventional
defaults. An ordinary one-task request can therefore stay direct: “Keep this PR
description to three bullets.” Use `AGENTS.md` for broader project constraints
and instructions. The
conventional file adds repository defaults to Shaka's
[default writing guidance](../skills/shaka/references/writing.md); it does not
replace that baseline. Shaka does not need an `AGENTS.md` pointer to load the
conventional file. Add a pointer only when other agent workflows also need the
repository style.

Repositories that already use this path through an `AGENTS.md` pointer should
replace a symlink with a regular UTF-8 file and keep it within the 100 KB bound
before adopting this Shaka version. Candidate checks reject the old shape so an
invalid guide does not first surface after it reaches the trusted branch.
