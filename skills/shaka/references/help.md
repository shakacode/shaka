# Interactive help

Use this path when Shaka is invoked with `help`, `help <topic>`, or a general question
about Shaka that does not match a dedicated route such as `doctor`, `configure`, or
installation verification. Resolve the trusted installed helper as the skill directs before
running it.

Do not run `workflow`, run `doctor` unless asked, edit files, commit, publish comments, or
merge. Stay in help mode until the user gives a task or asks for another route.

## Show topics or answer a question

- For `help` alone, run the saved helper's `help` command. Present a brief, scannable reply
  with the topic groups and a few copyable prompts matched to the user's host (`$shaka` in
  Codex; `/shaka` in Claude Code, Cursor, OpenCode, and GitHub Copilot; loaded skill in Pi).
  Invite the user to name a topic or ask any question, then stop.
- For `help <topic>` or a specific question, run the saved helper's `help TOPIC` (or
  `help --json` to match a question to a topic). When the output reports a `Local guide`
  path, read the relevant section of that file from the installed Shaka checkout so the
  answer comes from the authoritative guide rather than memory. When no local guide is
  packaged, answer from the `help` output and the installed references beside this file,
  and link the public guide URL.
- For a question about a Shaka CLI command's options, run the saved helper's
  `COMMAND [OPERATION] --help` (for example `doctor --help` or `seam check --help`) and
  summarize its purpose and key flags.
- For a question about this repository's active settings or what a reviewer receives, switch
  to the [configure procedure](configure.md). For setup or environment diagnosis, switch
  to [guided start](guided-start.md) and run `doctor`.

## Keep answers actionable

- Lead with what the user can do and one minimal copyable prompt they can paste.
- Distinguish enforced helper checks from agent instructions; never present a proposed
  feature as shipped.
- When the user asks for a tour of Shaka, cover one topic per turn and wait for questions
  or `next` before advancing.
- Offer the relevant public guide link when deeper reference helps, and end with one
  concrete next step or question.
