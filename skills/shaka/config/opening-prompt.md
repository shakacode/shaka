You parse the opening paragraph of a pull request description. Do not judge it; extract structure only.

For each sentence of the opening paragraph, in order, up to three, analyze its MAIN clause only (ignore clauses introduced by so, which, because, when, before, unless):
- character: the grammatical subject, the noun doing the action.
- reader_facing: true if the character is someone or something a maintainer directly cares about (a person, a pull request, an issue, a repository, a tracker); false if it is a command, flag, file, agent, helper, or internal step.
- action: the main verb phrase.
- character_can_act: true if the character, being what it is, can perform every action of the main clause as written; false when a thing such as a repository, setting, file, or command is given a person's verb such as see, know, want, or decide, or a person's choice, such as naming what it should use.
- object: what the action is done to.
- hidden_actions: actions buried in nouns or gerunds (for example "attestation", "submitting", "validation").
- internal_terms: words a maintainer new to this tool would need explained.

When description prose follows the opening, also fill `unclear_terms`. Read the opening paragraph and that prose as a developer who knows Git, GitHub, and their own project but has never used Shaka, the tool that prepared this description. List only words that carry a meaning private to Shaka, so that this reader would have to ask what they mean: shorthand such as "the seam" or "bind the evidence", or an ordinary word used in a private sense, such as "the ledger reopened". Leave out:
- names a reader can look up: text in backticks, links, file paths, and bold labels;
- Git and GitHub words, and the words Shaka puts on the PR page: recommendation, code walkthrough, code review, checkpoint;
- ordinary English and software words used in their usual sense, such as agent, comment, reviewer, or test run, even when the reader might ask which one is meant;
- loose or vague wording, such as "both changes" or "the full run": judge vocabulary here, not clarity;
- technical terms of the project's own domain.

For each entry, `term` quotes the exact words, `where` names the label they sit under (Opening, Why, Scope), and `plain_wording` says the same thing in words that reader knows, short enough to replace them in the sentence. Most descriptions list nothing. Before listing a word, ask whether that reader could make a fair guess at it from the sentence; if so, leave it out.
