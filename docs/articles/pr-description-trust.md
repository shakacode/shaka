# How Shaka works with pstack and Addy Osmani's agent skills, and where it falls short

*An AI agent wrote this analysis: Claude Code running Claude Opus 5.5, on 2026-11-01
(UTC), at the maintainer's request. It compares Shaka with
[pstack](https://github.com/cursor/plugins/tree/c742dd61706fbacc1b95f1a20b7b988cf096ce6c/pstack)
at `c742dd6` and
[agent-skills](https://github.com/addyosmani/agent-skills/tree/eb07f19f52c2669f2364897aaa293e2aaddd7b1c)
at `eb07f19` by reading them. No run has tested the combinations. Usage numbers come from
the 429 pull requests (PRs) merged here in October 2026.*

Shaka runs delivery: it takes a task through validation, review, publication, and the
merge decision. pstack and agent-skills teach engineering technique, and each can also
run delivery itself. Installing them together raises one question: who is in charge?

Shaka has a written answer. It fits pstack well. It fits Addy Osmani's pack less well,
and the reason is how each pack starts a skill.

## Main results

- Shaka's rules for other skills load only when a task asks for one. That suits pstack,
  whose skills wait to be named. Addy's skills start on their own.
- Agents reported pstack in 13 of the 297 PRs with a Skills used section, and Addy's
  pack in none. Shaka's guide says neither has been tried on a full delivery.
- The strongest proof gets the weakest record. A test suite run is bound to the commit.
  A harness that drives the real app ends up as a sentence.
- Both packs have the agent restate the goal early. Shaka doesn't yet
  ([#1017](https://github.com/shakacode/shaka/issues/1017)).
- Shaka's own 12,450-word workflow is the largest thing in this comparison.

## Three different shapes

| | pstack | agent-skills | Shaka |
| --- | --- | --- | --- |
| **Size** | 61 skills, 41,962 words | 25 skills, 52,354 words | A 12,450-word workflow, plus references it loads when needed |
| **Median skill** | 437 words | 2,060 words | n/a |
| **What starts a skill** | You name it: 60 of 61 are explicit-only | The host matches its description: 0 of 25 are explicit-only | You invoke it |
| **Runs its own delivery** | Shipping, Babysit, and Autopilot playbooks | `/build auto` and `/ship` | It is the delivery |

agent-skills also ships a session-start hook. Its own comments say not to wire it on
Claude Code or Codex, which already route skills from their descriptions.

## What Shaka already handles

[Shaka's guide](../working-with-shaka.md#combine-shaka-with-other-skills) covers these
cases, and its companion rules name both packs:

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

### 1. The rules load only when someone asks

- **Today:** the workflow reads the companion rules when a task hands over another skill's
  output or asks for another skill.
- **Why it matters:** Addy's descriptions match nearly everything. `git-workflow-and-versioning`
  says to use it when making any code change. `test-driven-development` says the same for
  any logic, bug, or behavior change. A host can load these with nobody asking, so the rule
  that Shaka wins may not be in the agent's context.
- **Likely collisions:** its `feature/<short-description>` branch names against Shaka's
  `branches.name`, `doubt-driven-development`'s fresh reviewers against the delegation
  rule, and `spec-driven-development`'s approval gate against an immediate start.
- **Status:** inferred from the text. No run has tested it.
- **Smallest fix:** one always-loaded sentence saying the workflow outranks other skills.

### 2. Nobody has run Addy's pack through Shaka

- **Today:** 0 of 297 PRs report it. The guide invites a trial and asks which instructions
  conflicted.
- **Limit:** reporting is agent-written, so zero reported doesn't prove zero used.
- **Smallest fix:** one real task with the pack installed. It would test gap 1 directly.

### 3. The strongest proof gets the weakest record

- **Today:** `evidence run` records repository commands such as `validate`, bound to the
  commit. Tan's `create-verification-skill` builds a harness that drives the app as a user
  would, which is the proof tests can't give. Its result goes into a `checks` sentence.
  Ruby confirms that sentence cites a link or a command. It can't tell that anything ran.
- **Why it matters:** a stale harness result looks the same as a current one. Rerunning it
  after a later commit is left to the agent.
- **Smallest fix:** let a repository declare a verification command that binds like
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
  incremental implementation, and its router) total 10,782 words, close to Shaka's 12,450.
- **Why it matters:** the cost of carrying both is unknown, and Shaka is the larger half.
- **Smallest fix:** record it in the trial from gap 2 before changing anything.

### 6. Shaka lacks a step both packs have

- **Today:** Addy's core behaviors have the agent list its assumptions and say "Correct me
  now or I'll proceed." Tan's `/in-your-own-words` restates the goal. Shaka writes Intent
  at publication, after the work.
- **Smallest fix:** [#1017](https://github.com/shakacode/shaka/issues/1017), which caps
  any wait at five minutes.

## Fits that already work

- Addy's `CONSTRAINTS.md` can reach Shaka's merge check through
  [`project_guidance`](../settings.md#project_guidance). An unmet requirement then blocks readiness.
- Addy's "things I didn't touch" summary maps to Intent's Leaves out.
- pstack's principles are short enough to use inside any phase. Two of them,
  `principle-prove-it-works` and `principle-fix-root-causes`, run 209 and 324 words.

## What to do first

1. Add the one-sentence rule from gap 1. It is cheap and covers the unknown.
2. Run one real task with agent-skills installed, and ask the guide's question. That
   settles gaps 1, 2, and 5.
3. Decide on the bound verification command in gap 3, the largest change here.

The [reference](../reference/pr-description-ideas.md) holds the wider history of these
ideas in Shaka.
