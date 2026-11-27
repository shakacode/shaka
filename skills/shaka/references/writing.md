# Shared writing rules

- Use these rules for publication prose and checkpoint reports.
- When trusted `AGENTS.md` exists, read its writing preferences and any Markdown
  style file it explicitly points to. Those preferences take precedence; current
  task instructions can refine them.

## Plain language and organization

- Prefer lists for instructions, findings, and explanations with multiple points.
  Use numbered lists when order matters or readers need to refer to individual points.
- Lead with the outcome its reader notices.
- Make each sentence readable alone. Name its subject with a short noun, and start no
  sentence with it, this, that, or such. Move a long qualifier into its own sentence.
- Give each sentence one main idea and a clear subject and verb.
- Make the subject a person who acts, or a thing doing what things do. Do not give
  a repository, setting, or file a person's verb such as "see" or "know".
  - Instead of: “A repository can now name the providers whose reviewers read
    every commit, and see on the PR when one could not.”
  - Write: “Maintainers can now list the AI providers that review every commit.
    When one cannot review, the review comment says so.”
- Put a condition before the instruction or behavior it limits: "When the base
  is stale, rebase first," not "Rebase first when the base is stale."
- Keep the space between sentences empty. Skip a lead-in that announces the next
  sentence and a closing sentence that restates the last.
- When the order already shows the relation, drop "therefore", "thus", "so",
  "however", and "but", and split the joined clauses into separate sentences.
- Use familiar words; explain unfamiliar project terms through the behavior they name.
- Write a question for a person by the
  [question rules](delivery.md#when-the-agent-asks-questions).
- Explain a PR’s problem and benefit for a maintainer who has not read the issue or design.
  For preparatory work, connect this part to the later user outcome.
- Keep exact commands, identifiers, risks, and evidence intact.
- Delete greetings, praise, and claims of significance that add no information.
  State each visible conclusion once; different wording or labels do not add meaning.
- Describe observable behavior rather than implementation jargon. For example:
  - Instead of: “Tier 3 needs a bounded reader for native events.”
  - Write: “We need to test whether agents follow the PR workflow, including waiting
    for merge permission. The PR reads Codex’s reported activity for those tests.
    Running and grading the full workflow remains future work.”
- Keep explanations proportional to the change. Keep the average sentence under
  about 15 words; no sentence should need more than 25. Keep paragraphs to about
  four sentences when prose is useful.
- Revise by deleting first. Ask whether the reader will follow each sentence,
  not whether they could.

## Squash commit messages

- After the outcome, name the failure the change ends.
- State the outside fact behind a change before the change, such as "Windows
  ignores shebang lines."
- When three or more changes touch one area, give the area a short label line
  and list one change per bullet. List known limits and follow-up issues the
  same way, each bullet a full sentence with its own verb.
- A squash body may list more than the description summary allows. Take the
  extra changes, limits, and follow-ups from the description's Intent and
  limitations.
- Replace internal terms with what the part does.
  - Instead of: “Without a job, only a leader Ruby has not reaped is ended.”
  - Write: “When no job is available, a stop ends only the check's main Ruby
    process.”
