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
