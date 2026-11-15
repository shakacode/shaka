# Why Shaka stays small

Shaka carries one task to its requested outcome: usually a reviewed pull
request, sometimes a plan or review only. One agent task owns delivery through
review, merge, or handoff.

Shaka uses the work item and GitHub as its shared record, avoiding a separate
tracking system.

## Keep facts where people look for them

- When there is a work item, it holds the reason for the work: priority, scope,
  and dependencies. For tasks started from a description, capture that context
  in the PR.
- GitHub holds delivery evidence: commits, checks, reviews, and the PR outcome.
- The agent task holds experiments and unpushed work. That context is temporary.

![The work item holds why the work exists and GitHub holds delivery evidence; a fresh PR reader reconstructs the task from those two. The agent task is temporary.](img/where-facts-live.svg)

A fresh PR reader should be able to reconstruct the owner, blocker,
revision, and next step from the work item and GitHub. An unfinished PR carries a
short [recovery note](working-with-shaka.md#resume-unfinished-work) for that
purpose. The note helps someone continue the work.

## Put repeatable checks in code

Ruby handles configuration validation, comment filtering, and merge checks. Skill
instructions guide the agent’s decisions. This keeps repeatable checks testable
and reduces the instructions the agent must interpret.

The agent runs Ruby commands and reads their output; it does not load their source.
Measured in November 2026, the installed `skills/shaka` directory held:

| Content | Lines | Size |
| --- | --- | --- |
| Ruby (485 files) | 44,942 (84%) | 1.74 MB (77%) |
| Markdown references and prompts (52 files) | 5,942 (11%) | 0.36 MB (16%) |
| YAML workflow, settings, and data (5 files) | 2,311 (4%) | 0.16 MB (7%) |

For a task, the agent reads `SKILL.md` (316 words) and the workflow that
`shaka workflow` prints (about 12,100 words). It loads a reference only when that
reference's condition applies, such as a review or a retrospective. The Ruby has
about 76,000 lines of tests under `test/`, which stay out of the installed skill.

Words and bytes show size, not tokens; each model counts tokens differently. To
check the instruction size yourself, ask your agent:

```text
Run bin/report-instruction-growth in my Shaka checkout and summarize the word counts
```
