# Writing preferences

Lead with what changed and why. Show the evidence needed to judge it; keep
implementation detail in the walkthrough and longer records in expandable sections.

For a task, tell the agent how you want it to write:

```text
Keep PR descriptions short. Lead with what changed for the user,
use before/after examples, and put implementation details in the walkthrough.
```

For persistent repository defaults, put your preferences in `AGENTS.md` or link
from it to a separate style file. For example:

```text
Before writing documentation, PR descriptions, code walkthroughs,
or review replies, read .agents/writing-style.md and apply its prose preferences.
```

The agent follows trusted repository instructions. Shaka does not automatically
load a style file. See its [default writing guidance](../skills/shaka/references/writing.md).
