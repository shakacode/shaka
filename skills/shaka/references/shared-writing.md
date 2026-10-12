# Shared writing rules

Use these rules for publication prose and checkpoint reports. When trusted
`AGENTS.md` exists, read its writing preferences and any Markdown style file it
explicitly points to. Those preferences take precedence; current task instructions
can refine them.

- Lead with the outcome its reader notices.
- Give each sentence one main idea and a clear subject and verb.
- Put conditions beside the behavior they limit.
- Use familiar words; explain unfamiliar project terms through the behavior they name.
- Name the feature, user, or dependency behind references to an agreed design
  or earlier discussion; supply the context the reader needs.
- Keep exact commands, identifiers, risks, and evidence intact.
- Delete greetings, praise, and claims of significance that add no information.
  State each visible conclusion once; different wording or labels do not add meaning.

Replace “Adds validation of the configured base parameter” with
“Shaka now rejects an invalid base branch before the agent starts work.”
Keep explanations proportional to the change. Aim for sentences under 25 words
and paragraphs of about four sentences.

For advisory reviews, put the current-head recommendation, main reason, and task
owner's next action before the analysis. Name model settings with their provenance;
a configured model is not proof of a served model. Name the user benefit, scope,
and unfinished verification when they affect the decision. Distinguish verified
results, a recommendation to merge, and permission to merge. Keep unresolved
blockers visible. State whether a simpler alternative revises this PR or replaces
it. Supporting usage and history can remain collapsed.

State a risk as who or what is affected and what they would see fail: “API
clients get a 500 until the cache warms,” not “medium blast radius.” State a
rollback as what reverting the commit restores and what it leaves. Reverting code
does not restore stored data the code deleted or rewrote, or undo outside effects
such as sent email, charges, or published packages. Name each such effect and
how to recover from it, or that it cannot be recovered.

## Checkpoint sections

Give each existing field one job:

1. **Recommendation:** The owner recommends what happens to this PR and gives
   the main reason. A recommendation is not merge permission.
2. **Next action:** The owner names who does what next, rather than restating the
   recommendation.
3. **Verification conclusion:** State what the evidence establishes and what
   remains unverified. Leave the conclusion label to the renderer; do not repeat
   the owner's reason or next action.
4. **Unresolved concerns:** Give each problem's location, specific failure, and
   consequence. Put remedies in the alternative and supporting evidence in the
   analysis.
5. **Supporting analysis:** Give evidence, costs, and tradeoffs. Keep them collapsed;
   repetition of visible points is acceptable there.
