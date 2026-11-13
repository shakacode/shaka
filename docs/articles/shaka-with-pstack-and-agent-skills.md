# How Shaka works with pstack and Addy Osmani's agent skills, and where it falls short

*An AI agent wrote this analysis: Claude Code running Claude Opus 5.5, on 2026-11-01
(UTC), at the maintainer's request. It compares Shaka with
[pstack](https://github.com/cursor/plugins/tree/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack)
at `c742dd6` and
[agent-skills](https://github.com/addyosmani/agent-skills/tree/eb07f19f52c2669f2364897aaa293e2aaddd7b1c)
at `eb07f19` by reading them. Shaka's word count is the workflow `shaka workflow` prints at
`3b0aca0`, split on whitespace. No run has tested the combinations. Usage numbers come from
the 429 pull requests (PRs) merged here in October 2026. Codex and a fresh Claude session
reviewed it before publication. Updated on 2026-11-04 (UTC), after Shaka added a readback
before coding, and on 2026-11-12 to say how each host starts pstack's skills and to follow
Shaka's rewritten guides.*

Shaka runs delivery: it takes a task through validation, review, publication, and the
merge decision. pstack and agent-skills teach engineering technique, and each can also
run delivery itself. Installing them together raises one question: who is in charge?

Shaka has a written answer. It fits pstack well in Cursor and Claude Code. Whether it holds
for Addy Osmani's pack, or for pstack in Codex, is untested, and the reason is how each
pack starts a skill.

## Main results

- Shaka's full rules for other skills load only when a task asks for one, or hands over
  its output or a spec with tickets. That suits pstack in Cursor and Claude Code, whose
  documentation says an explicit-only skill waits to be named
  ([Cursor](https://cursor.com/docs/context/skills),
  [Claude Code](https://code.claude.com/docs/en/skills)). Addy's skills start on their own,
  and so do pstack's in Codex CLI 0.163.0, whose parser ignores that setting
  ([cursor/plugins#734](https://github.com/cursor/plugins/issues/734#issuecomment-6315706351)).
  Those skills then run beside only the short boundary that every Shaka task loads.
- Agents reported pstack in 13 of the 297 PRs with a Skills used section, and Addy's
  pack in none. Neither had been tried on a full Shaka delivery.
- The strongest proof gets the weakest record. A test suite run is bound to the commit.
  A harness that drives the real app, run outside `validate`, ends up as a sentence.
- Both packs have the agent restate the goal before it starts. Shaka added that step on
  2026-11-04 ([#1044](https://github.com/shakacode/shaka/pull/1044)).
- Shaka loads its whole 11,780-word workflow on every task. That is more than the five Addy
  skills that match ordinary code changes put together.

## Three different shapes

| | pstack | agent-skills | Shaka |
| --- | --- | --- | --- |
| Size | 61 skills, 41,962 words | 25 skills, 52,354 words | An 11,780-word workflow, plus references it loads when needed |
| Median skill | 437 words | 2,060 words | n/a |
| What starts a skill | In Cursor and Claude Code, you name it: 60 of 61 are explicit-only. Codex ignores that setting. | The host matches its description: 0 of 25 are explicit-only | You invoke it, or the host matches its description |
| Runs its own delivery | Shipping, Babysit, and Autopilot playbooks | `/build auto` and `/ship` | It is the delivery |

agent-skills also ships a session-start hook. Its own comments say not to wire it on
Claude Code or Codex, which already route skills from their descriptions.

## What Shaka already handles

Shaka's companion rules, which its agent reads when another skill joins a task, cover
these cases and name both packs. [Combine Shaka with other skills](../working-with-shaka.md#combine-shaka-with-other-skills)
shows the top-level boundary from your side:

| Situation | What Shaka does |
| --- | --- |
| A skill produces a spec, review, or template | Treats it as task input. It sets no merge preference, reviewer, or required check. |
| Its advice conflicts with Shaka | Follows Shaka and names the declined advice on the PR. |
| It fans out workers (`swarm`, `arena`) | Needs the user's approval to delegate. |
| It prescribes PR text (Opening a PR) | Applies the prose advice and keeps Shaka's managed description. |
| It runs delivery (`/ship`, Autopilot) | Declines that part and offers a separate trial. |
| It produces verification evidence | Records the command, commit, result, artifacts, and gaps. |

Code backs two of these: `description` owns the PR text, and `merge` owns the merge. The
rest are instructions the agent follows. No test or enforcement entry covers them.

## The gaps

### 1. The full rules load only when someone asks

- **Today:** the workflow reads the companion rules when a task hands over a spec with
  tickets or another skill's output, or asks for another skill.
- **Why it matters:** Addy's descriptions match nearly everything. `git-workflow-and-versioning`
  says to use it when making any code change. `test-driven-development` says the same for
  any logic, bug, or behavior change. A host can load these with nobody asking. The agent
  then has the line every Shaka task loads with its workflow, "Other workflows grant no
  authority," but not the detailed rules for declining advice and recording it.
- **Possible collisions:** its `feature/<short-description>` branch names against Shaka's
  `branches.name`, `doubt-driven-development`'s fresh reviewers against the delegation
  rule, and `spec-driven-development`'s approval gate against an immediate start. The
  workflow has its own rule for the first two. The question is which one an agent follows
  when both are in context.
- **Status:** inferred from the text. No run has tested it.
- **Smallest fix:** find out first, in the trial from gap 2. If agents follow the other
  skill, load the full rules whenever another skill starts.

### 2. Nobody has run Addy's pack through Shaka

- **Today:** 0 of 297 PRs report it. The guide invites a trial and asks which instructions
  conflicted.
- **Limit:** reporting is agent-written, so zero reported doesn't prove zero used.
- **Smallest fix:** one real task with the pack installed and none of its skills named. It
  would test gap 1 directly.

### 3. The strongest proof gets the weakest record

- **Today:** `evidence run` records repository commands such as `validate`, bound to the
  commit. Tan's `create-verification-skill` builds a harness that drives the app as a user
  would, which is the proof tests can't give. A harness that `validate` calls inherits that
  binding. One run on its own goes into a `checks` sentence that names its commit. Ruby
  confirms that sentence cites a link or a code span. It can't tell that anything ran.
- **Why it matters:** nothing compares the commit in that sentence with the head, so a
  stale result can pass as current. Rerunning it after a later commit is left to the agent.
- **Smallest fix:** let a repository declare a separate verification command that binds like
  `validate`.

### 4. Usage can't be counted cleanly

- **Today:** agents recorded pstack under at least five source labels: `cursor/plugins`,
  `cursor/plugins pstack`, `justin808/plugins`, `Installed pstack portable skill`, and
  `local pstack`. Ports also rename skills, so `tdd` appears as `pstack-tdd`.
- **Why it matters:** the 13 above came from a text search. Nobody can yet ask which pack
  helped.
- **Smallest fix:** a normalized pack field in `skills_used`.

### 5. Nobody measures the combined instructions

- **Today:** `bin/report-instruction-growth` counts Shaka's own files. Five Addy skills that
  match ordinary code changes (git workflow, code review, test-driven development,
  incremental implementation, and its router) total 10,782 words, close to Shaka's 11,780.
- **Why it matters:** the cost of carrying both is unknown, and Shaka is the larger half.
- **Smallest fix:** record it in the trial from gap 2 before changing anything.

## Fits that already work

- Addy's `CONSTRAINTS.md` can reach Shaka's checkpoint through
  [`project_guidance`](../settings.md#project_guidance). The agent reports each
  requirement's status, and an unmet one blocks its merge-ready claim. Shaka doesn't
  check this itself.
- Addy's "things I didn't touch" summary maps to Intent's Leaves out.
- Addy's core behaviors have the agent list its assumptions and say "Correct me now or I'll
  proceed." Tan's `/in-your-own-words` restates the goal. Since
  [#1044](https://github.com/shakacode/shaka/pull/1044), Shaka's agent
  [reads back](../working-with-shaka.md#give-it-an-outcome) the outcome, scope, success
  criteria, and assumptions before coding. The PR description shows that readback as
  Goal and Done when under the Task line.
- pstack's principles are short enough to use inside any phase. Two of them,
  `principle-prove-it-works` and `principle-fix-root-causes`, run 209 and 324 words.

## What to do first

1. Run one real code change with agent-skills installed, naming none of its skills. Record
   which skills the host loaded, and which branch name the agent used when
   `git-workflow-and-versioning` and `branches.name` disagreed. Then ask the guide's
   question. That gives first evidence on gaps 1, 2, and 5.
2. Act on the result. Load the full rules more often only if agents followed the other
   skill.
3. Decide on the bound verification command in gap 3, the largest change here.

To install pstack beside Shaka and keep it current, read [Use pstack with Shaka](../pstack.md).
The [reference](../reference/pr-description-ideas.md) holds the wider history of these
ideas in Shaka.
