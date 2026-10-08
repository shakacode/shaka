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

For advisory reviews, put the current-head recommendation, main reason, and task
owner's next action before the analysis. Name model settings with their provenance;
a configured model is not proof of a served model. Keep unresolved blockers visible.
State whether a simpler alternative revises this PR or replaces it, and explain
the disposition. Supporting usage and history can remain collapsed.

For example, replace “Adds validation of the configured base parameter” with
“Shaka now rejects an invalid base branch before the agent starts work.” A code
walkthrough can then explain the validation and its edge cases.

State a risk as who or what is affected and what they would see fail: “API
clients get a 500 until the cache warms,” not “medium blast radius.” State a
rollback as what reverting the commit restores and what it leaves. Reverting code
does not restore stored data the code deleted or rewrote, or undo outside effects
such as sent email, charges, or published packages. Name each such effect and
how to recover from it, or that it cannot be recovered.

When trusted `AGENTS.md` exists, read its repository writing preferences and any
Markdown style file it explicitly points to. Use the guidance above in every
repository; current task instructions can refine it. No style schema or prose
score is needed beyond the limits below. Self-edit the content JSON; do not rewrite the rendered GitHub
body or invoke a separate rewriting skill for Shaka's publication step.

## Point readers to the code

Reviewing code is easier than reading a wall of text about it. The diff already
shows what changed, so prose should say why, flag what needs a close look, and
link to it. A description sends the reader to the walkthrough; a walkthrough
links each step to the lines it explains.

Keep the text in proportion to the change. A three-line fix needs a sentence or
two, not a page. Describe the result at this head; review rounds belong in the
description's collapsed history, not in its visible sections.

Aim for sentences under 25 words and paragraphs of about four sentences.
`description` and `walkthrough` refuse text past the
[prose limits](https://github.com/shakacode/shaka/blob/main/docs/settings.md#prose_limits): long sentences, long
paragraphs, or more visible words than the change warrants. Split the text,
collapse supporting detail into `details`, or link to the code, then publish again.
Record each refusal in the description's review history details: what it
reported, a quoted passage or the word count, and what you changed.
