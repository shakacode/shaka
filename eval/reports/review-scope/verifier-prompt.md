# Review-scope verifier prompt

This file pins the escape-audit verifier for Stage 2 of the
[review-scope preregistration](../review-scope-preregistration.md). The verifier checks
claims about a change at the two arms' final heads, labelled `P` and `Q`, without knowing
which arm produced which. Every scored session sends the text under [Prompt](#prompt) with
its placeholder filled. A change to that text or to the session below after the first
priced call makes a new eval.

## Session

One fresh session per item, after both escape audits, so one reader judges both heads. It
reads the prompt on standard input and runs in the checkout described below:

```bash
claude -p --model claude-opus-5-5 --effort high --max-budget-usd BUDGET \
  --permission-mode bypassPermissions --disallowedTools WebFetch WebSearch \
  --output-format stream-json --verbose --no-session-persistence < PROMPT_FILE > STREAM
```

- `BUDGET` is the verifier budget from the preregistration's Per item stop rule.
- The session runs without GitHub credentials, like the Stage 2 implementer sessions.
- `STREAM` keeps every tool call. Its final `result` event holds the answer and the
  session's usage.
- **Isolation:** the operator reads the tool calls in `STREAM`. A session that touched
  `/Users/justin/claude/shaka-state/`, the run records, the coding hosts' session stores
  (`~/.claude/projects/`, `~/.codex/sessions/`), or a checkout other than its own and the
  temporary worktrees it made is void. So is a session that made any network call, such as
  `curl`, `gh`, or `git fetch`. A void session counts as a provider error under the
  preregistration's Retries rule.

## Checkout

- Built from a Git bundle with no remote, as the Stage 2 fixture is, and cloned into
  `/Users/justin/claude/shaka-worktrees/PR-heads`.
- Branches:
  - `main`: the item fixture's `main`.
  - `start`: the first reviewed commit.
  - `common`: the shared cycle 1's final head, where both forks began, recorded when the
    forks are created. It is not derived from `P` and `Q`, because a fork may rewrite
    history.
  - `P` and `Q`: the two forks' final heads. One random bit per item, such as the parity
    of `openssl rand -hex 1`, decides which fork's head is `P`. Only the run record holds
    that mapping.
- Nothing else from either loop: no ledger, goal file, reviewer report, or session
  transcript.

## Claims

- **Claims:** every defect and risk that either reviewer reported in either escape audit;
  the item's K items whose historical fix added no test; and the item's verifier decoys from
  the Decoys table. Nothing says which audit, if any, a claim came from.
- K items whose historical fix added a test are not claims. The operator runs that test at
  `common`, `P`, and `Q` instead.
- **Claim text:** the numbered report item, verbatim, without its item number. For an audit
  finding it comes from the audit's report. For a K item or a decoy it comes from the
  historical report first collated to it. No coverage section, attestation line, or text
  naming the reviewer, model, round, cost, or arm.
- **Format:** each claim is a line `### ID` followed by its text. Each id is `c` and 8
  random hex digits, recorded with the claim's source. Claims are listed in id order.

## Reading the answer

- The answer is the last `json` fenced block in the final `result` event: one object per
  claim.
- **K for the item:** a K item leaves K only when `common` is `no`, because the shared cycle
  1 fixed it. `unclear` or no answer at `common`, or at either head, leaves it inconclusive:
  reported, not scored.
- **Missed by an arm:** a K item still in K whose value at that arm's head is `yes`.
- **Escapes:** audit claims joined by `same_as` are one problem. A problem is an escape at a
  head when any of its claims has `yes` there, so a problem one audit found also counts at
  the other head when that head holds it. A problem counts as a loop-introduced escape, the
  L4 count, only when none of its claims has `start` equal to `yes` or `unclear`.
- **Decoys:** a verifier decoy passes when it gets `no` at both `P` and `Q`.
- **Unclear:** `unclear` at a head leaves that claim inconclusive there. It never counts as
  absent.
- **Retries:** a missing or malformed answer from a session that did not stop at its budget
  counts as a provider error under the preregistration's Retries rule: the identical prompt
  goes to one more fresh session. A budget stop gets no retry. A claim still without an
  answer is unverified and reported.
- The run record names this file's commit, the claim ids and sources, the answer, and the
  usage record.
- The review signal report's procedure has a fifth step, checking the fix. An escape has no
  fix, so that step has no counterpart here.

## Prompt

The text between the two fence lines below, with `{{CLAIMS}}` replaced.

````text
This checkout holds one change to a code repository. Its branches:

- `main`: the project's main line. `git merge-base main start` is the commit the change was built on; call it `base`.
- `start`: the change when its review began.
- `common`: the change at a later point.
- `P` and `Q`: two later versions of the change, each worked on from `common`.

Each claim below says something is wrong in the change. For every claim, decide whether the problem it describes exists at each of `base`, `start`, `common`, `P`, and `Q`. Work through the claims in order:

1. Read the claim. Name the input, state, or statement it says leads to a wrong result, and that wrong result.
2. Check that input or state at each commit. Read the code or text with `git show COMMIT:PATH` and follow its callers; a claim's line numbers may come from another version. When the cited code is identical at two commits, the answer carries over. When a short probe can show the behavior, run it: add a worktree for the commit in a temporary directory outside this checkout, write the probe there, run it, and remove the worktree. Ruby tests run with `bundle exec ruby -Itest FILE`. Otherwise argue from the code or text.
3. Answer `yes` when the problem exists at that commit and `no` when it does not, including when the cited code is absent. A plausible claim that the code disproves is `no`. Answer `unclear` only when neither reading nor a probe settles it.
4. When a claim describes the same problem as an earlier claim, set `same_as` to the earlier claim's id.

Leave every branch as it is: make no commits, move no branch, and push nothing. The work needs no network access.

Claims:

{{CLAIMS}}

End your reply with one ```json block holding an array with one object per claim, in the order above. Each object has these fields:

- `id`: the claim id.
- `base`, `start`, `common`, `P`, `Q`: each `yes`, `no`, or `unclear`.
- `same_as`: an earlier claim id, or null.
- `checked_by`: `run` when a probe decided `P` or `Q`, otherwise `read`.
- `evidence`: the file and lines, or the probe and its result, that decided `P` and `Q`.
````
