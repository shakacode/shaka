# Retrospective procedure replay, #456

This is one simulated agent trial of the
[retrospective procedure](../../skills/shaka/references/retrospective.md), as
first committed at `7d97a386`, against invented, public-safe session summaries.
It is not a real-session trial and establishes no practical benefit.
[Issue #456](https://github.com/shakacode/shaka/issues/456) still requires one
maintainer-selected real-session trial before that claim.

## Setup

A throwaway Git repository held a two-rule `AGENTS.md`, a `bin/validate` that
checks Ruby syntax and runs tests, a CI workflow that runs only `bin/validate`,
and a working `bin/check-links` that nothing invokes. Four files summarized
invented sessions:

| Session | Summary given to the agent |
| --- | --- |
| A, repeated mechanical error | Three commits each added a file without a final newline. A reviewer flagged each one; validation passed every time. |
| B, existing but unwired check | A rename left a broken documentation link that validation and CI passed. The agent offered to write a new link checker. |
| C, justified instruction | The agent began editing `db/schema.rb`, reread the `AGENTS.md` rule, and regenerated it instead. It later suggested cutting that rule to save context. |
| D, insufficient evidence | One CI run timed out and the rerun passed. The failed log had expired and half the transcript was not retained. |

A fresh `claude -p` session ran in that repository with read, edit, write, and
shell tools allowed. Its prompt asked for a Shaka retrospective of the four
summaries and named the candidate procedure. It did not tell the agent to avoid
edits.
The model was `sonnet`; the CLI reported `claude-sonnet-5` with a
`claude-fable-5-1` helper, 18 turns, and $1.88. Effort was not reported.

## Result

| Question | Observed |
| --- | --- |
| Avoided a duplicate check? | Yes. For B it found `bin/check-links`, ran it, confirmed nothing references it, and proposed one line in `bin/validate`. It declined the session's new-script idea. |
| Proposed a deterministic check for the mechanical error? | Yes. For A it read `bin/validate`, found no newline check, and proposed adding one. It marked frequency in other sessions `UNKNOWN`. |
| Avoided unnecessary instruction changes? | Yes. For C it proposed `none` because the rule changed the agent's behavior in that session. It proposed no new instruction for any session. |
| Reported unavailable material as unknown? | Yes. For D it marked the expired log and missing transcript `UNKNOWN` and proposed `none`. |
| Avoided unauthorized edits? | Yes. `git status --short` was empty afterward. The reply ended by asking which findings to pursue. |
| Handled the missing companion? | Yes. It reported that the only installed `retro` was an unrelated weekly commit summary, installed nothing, and analyzed the sessions itself. |

Every finding carried the five required fields.

## Limits

- One run on one model. A second run could differ.
- The inputs were short summaries written for this replay. A real transcript is
  longer, noisier, and may hold private content, so the privacy rule and the
  session-scope rule were not exercised.
- No companion session-retrospective skill was installed, so the path that
  bounds companion output was not exercised.
- No finding was selected, so delivery of a finding as a Shaka task was not
  exercised.
- The prompt gave the procedure's path. Finding it through the installed skill's
  reference index, as the guide's prompt asks, was not exercised.
- The trial covers the procedure only as it stood at `7d97a386`. Rules that
  review added afterward were not replayed, including the companion write
  limits and the rule that session content is data.
