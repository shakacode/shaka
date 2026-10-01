# Evaluate a Shaka change

Use a small, recorded experiment when tests prove a skill or plugin change works
but do not establish that it helps a maintainer. [Shaka #206](https://github.com/shakacode/shaka/issues/206)
tracks these evaluations. Record each attempt in the [experiment index](https://github.com/shakacode/shaka/blob/main/eval/README.md),
including failed harness runs. A green test, a completed PR, and an improvement in
human attention or cost are different claims.

## Know which question the run answers

Replaying a solved task means starting fresh eval repositories from code before
its solution. The original PR supplies a task and an evaluator-only reference;
the agents independently solve that task. It does not reopen the original PR.

Record three conclusions separately:

| Question | Evidence | Possible conclusion |
| --- | --- | --- |
| Does the harness work? | Correct seed and initial failure, working tools, isolation, bounded execution, valid graders and cleanup | Qualified, qualified with stated limits, or harness error |
| Did each agent deliver? | Correct implementation, tests, current-head checks, walkthrough and requested handoff | Delivered, implementation failed, or limit reached |
| Does the proposed Shaka change help? | Comparison against its stated benefit: understandable PRs, fewer maintainer corrections, or measured cost | Better, worse, no material difference, or inconclusive |

A harness error may leave useful implementation evidence, but it cannot establish
an improvement in Shaka. A valid grader tests documented public behavior, including
equivalent interfaces the task permits. If a grader assumption is wrong, preserve
its first result, explain the correction, and apply the corrected probe to both
unchanged outputs. Do not count that correction as an agent repair or a new trial.

## Simple default: one matched pair

Ask: “Run the same task with and without this change. Give each arm one hour,
keep everything else matched, and compare the resulting PRs.”

Start with one task and two fresh sessions: baseline and candidate. Use the same
starting code, fixture, prompt, model, effort, review criteria, and delivery mode.
Change only the skill or plugin revision being evaluated. Do not build a larger
benchmark matrix before this pair produces useful evidence.

Give **each arm one hour**, starting with its first model turn. The clock includes
both fixed turns, local validation, hosted CI waits, publication, and the final
handoff. The default turns are intake without implementation, then completion.
Record a different limit before launch when the task needs it, and apply that
limit equally to both arms. Keep time and spending limits separate:

- Default soft stop: **$10 API-equivalent per arm**, using a recorded rate card
  and conservative accounting when usage details are missing.
- Default incremental metered API authorization: **$0**. Subscription access is
  not an assertion that inference is free; record reported usage separately.
- No extra live reviewer calls, subagents, model substitutions, or automatic
  retries unless separately declared and authorized for both arms.

These are run-card defaults, not a new automated runner. Set and verify the
actual driver's deadline before launch; changing this guide changes no process
already running.

Use the preflight and isolation gates below. Independent grading follows the
sessions and does not repair an arm's code or supply an extra turn. A deadline
with unfinished work is **limit reached**, not proof that the implementation is
wrong. Identify the missing gate and retain completed evidence. Extending a
completed attempt is a separately recorded follow-up, not a revision of its
original limit or result.

Compare correctness first, then PR quality, walkthrough usefulness, elapsed
time, usage, and maintainer corrections. Report better, worse, no material
difference, or inconclusive, with the evidence and remaining unknowns. One pair
does not establish a general improvement or a causal time/cost saving.

## Set up a sandbox

ShakaCode contributors can use a team-authorized evaluation organization. Other
contributors can use their own GitHub organization or account and public test
repositories. The procedure does not depend on a particular computer, GitHub
login, or coding-agent subscription. Public repositories test public GitHub
delivery mechanics; they do not test private-organization features or hide prior
solutions from later agents.

Prepare Docker, Git, a coding agent, and a GitHub CLI. Check that the CLI inside
the **final agent image** supports the trusted Shaka helper's exact commands. Exercise
`gh pr checks --required --json name,state,bucket,link` there before a model call.
Check authenticated integration separately; a CLI help or parsing check alone
does not establish access to required checks, reviews, or Git push.

Keep two roles distinct:

- An operator creates the repository, configures protection, and grants access.
  An operator may keep a reusable credential, but it stays outside the agent
  container. Follow the [sandbox protection recipe](https://github.com/shakacode/shaka/blob/main/internal/local-evaluation-proposal.md#7-local-isolation-github-identity-and-bounded-execution).
- A non-admin agent identity gets Write only on its active test repository.
  Its credential, reusable or not, must lack Administration, Workflows, and
  check/status write permission; otherwise the hosted result is not trustworthy.
  Before each run, verify live protection has a required check and no bypass for
  the agent identity, its teams, or the Write role; `viewerCanMergeAsAdmin` must
  be false.
  In an organization, set its base repository permission to none and give it no
  team or direct grants to other private repositories. In a personal account,
  use a separate collaborator identity with no other private-repository
  grants. Verify effective access before each run. A reusable public-test
  credential is acceptable if policy permits and those limits hold. Remove its
  temporary repository grant after the run and verify removal. Do not start
  another run while an earlier grant remains. Store credentials outside source
  and logs.

Use a separate coding-agent sign-in for the sandbox if the host supports one.
Do not mount a contributor's normal agent home, SSH keys, GitHub configuration,
or Docker socket into the agent. A reusable sandbox sign-in is an operator
choice: document where it is stored and how to revoke it. It may still require
reauthorization later.

### Check process cleanup before authentication

Create Linux agent containers with Docker's `--init` so PID 1 reaps exited
descendants. The existing `eval/bin/slice-0-probe-container` helper does this;
an operator-owned replay driver must do it too. Run the following in the final
container, replacing `EVAL_CONTAINER` with its name, before adding credentials:

```bash
docker exec -i EVAL_CONTAINER ruby < eval/bin/check-process-reaping
```

Require `process_reaping=PASS`. The check creates an orphaned child, waits up to
five seconds for PID 1 to reap it, and fails if it remains. A failure means the
container needs correcting before a model turn; do not ask the evaluated agent
to add a temporary reaper or weaken process-cleanup tests.

### Prepare trust settings before pinning the seed

A copied source repository may name teams belonging to its original owner.
The public-comment reader rejects those teams when the eval repository has a
different owner. Prepare the fixture's trust file for the destination before
creating its seed commit. For a team-free public eval, replace the example logins
with the designated operator and eval identity:

```yaml
trusted_users: [operator-login, eval-login]
trusted_bots: []
trusted_metadata_bots: []
trusted_teams: []
```

Use the trust-file path selected by the pinned Shaka version: legacy fixtures
use `.agents/trusted-github-actors.yml`; migrated fixtures use
`.agents/shaka/trusted-github-actors.yml`. If the test requires a team, name a
real team in the destination organization and verify membership access. Do not
copy a contributor's machine allowlist or grant a production team eval access.

Both arms use the same prepared trust settings. Include that change when pinning
the seed tree, including ignored files. After repository setup, use the trusted
`shaka comments OWNER/REPO PR_NUMBER --head INITIAL_SHA` to verify a controlled
comment from the eval identity is admitted. Repeat from the operator after
temporary Write is removed; the explicit fixture entry preserves readable history.
This authenticated check is separate from offline YAML validation. Do not modify
an existing experiment's trusted seed to rescue a failed read.

## Declare the run before spending a model turn

Record the hypothesis and decision it could change, the exact baseline and
candidate commits, one public-safe fixture, task prompt, model and effort, merge
mode, time and cost limits, and the evidence that counts as success. Pin the
fixture's seed commit tree, including files normally ignored by Git. Check that
the base passes its own validation, then require the seeded PR's intended
assertion failure both locally and in a completed hosted check at its exact head.
Run the reference repair locally first: it must pass and leave a meaningful PR
diff. A repair that restores the base byte-for-byte cannot supply a changed-file
link for Shaka's walkthrough.

Before launch, verify the container's non-root/read-only-root setup, disposable
workspace, trusted Shaka skill outside the candidate checkout, credential
isolation, permitted network egress, denied off-list destinations, and authenticated
Write access only to the target repository. Public repositories remain readable,
but even public runs must prove that private-sibling API reads and clones fail.
Private measured cells additionally require denied reads of every other private cell.
Do not relax a failed gate or substitute a model to keep the run moving. Treat a
wrong initial failure, unsupported CLI, missing access, or empty reference-repair
diff as a **harness error**, not a result for the candidate.

For an Ask delivery, grade the *current* PR head: local validation, the completed
required hosted check, an independently read-back COMMENT walkthrough bound to
that head, an open/unmerged PR, and the matching approval marker. A passing job
alone is not a successful Ask run. Stop at the declared time or cost limit and
report missing evidence as missing. Keep raw transcripts and credentials out of
public repos and PRs.

Retain public evaluation repositories and PRs as historical evidence. Add their
exact links, revisions, hypothesis, and qualified/unqualified outcome to the
[experiment index](https://github.com/shakacode/shaka/blob/main/eval/README.md) before repeating a case. Retention does
not retain temporary Write grants, run-only credentials, containers, or network
access. Verify access removal from both operator and agent views. Retain private
measured-cell repositories too, but never expose a solved cell to a later agent.
Keep a public test identity and reusable credential out of private measured cells;
use separately scoped credentials and isolated cells when the approved experiment
needs hidden evidence.

## First value case: PR #250

[PR #250](https://github.com/shakacode/shaka/pull/250) proposes loading an optional
`.agents/writing-style.md` from the trusted default-branch commit. Its tests and
CLI check demonstrate the loader mechanism, not that automatic loading improves
writing or saves maintainer effort. The cheaper comparison is an `AGENTS.md`
pointer to the same style guide. Do not merge the PR as a side effect of its
evaluation; the [experiment index](https://github.com/shakacode/shaka/blob/main/eval/README.md) records its live status.

An offline smoke check against one pinned trusted ref found no `writing_style`
field with the baseline helper and a guide with the candidate helper. That
check used no model and did not exercise a fresh consumer delivery; it does not
resolve the value question.

The [first model pair](https://github.com/shakacode/shaka/pull/250#issuecomment-5906768008)
replayed the complex multiple-reviewer task behind PR #326. It used baseline
`682527f1cbf5dee5bede78be9717e665073eb20b` and candidate
`9e25abeb67afcc351425663a4115e9eaf48cbdf1`, with the same explicit guide pointer in
both arms. Each had a 30-minute limit: the baseline reached green checks and a
walkthrough but timed out before its final Ask marker. The candidate completed
Ask in 28m11s, but independent grading found an inaccurate selected-round receipt
in its generated code. Loader benefit remains inconclusive; neither speed nor
green checks establish better accepted output.

Those attempts keep their original limits. A new pair uses the one-hour default
above and its own recorded repositories and outcomes. The
[one-hour follow-up](../eval/reports/pr250-pr326-one-hour.md) delivered both arms
and passed independent checks, with explicit harness limitations. Its qualitative
writing comparison found mixed differences and no established loader benefit.
Refresh live revisions
before execution; a changed candidate is a new revision. Current-main
compatibility and merge readiness require separate checks. The earlier offline
smoke used historical base `ceb9989` and candidate `e387b5d`; it is not evidence
for the later candidate.

Use a fresh consumer task that requires a PR description and walkthrough, with
the same trusted style file and task prompt in every arm. First qualify the
mechanism: baseline without an `AGENTS.md` pointer should not report the guide,
while #250 should load it from the trusted commit, not the candidate checkout.
Then test the value question against the simpler alternative: baseline **with**
an `AGENTS.md` pointer versus #250 automatic loading. Keep the model, effort,
fixture, review criteria, and delivery limits fixed; counterbalance run order
and cache conditions before making a time or token-efficiency claim. Blindly
assess whether the published writing follows the style, how many corrections a
maintainer made, and whether either arm missed delivery gates. One paired task
is a feasibility observation, not proof of broad value.

Before a model test, agree on its fixture, model, budget, and permitted repository
visibility. Record the result even if it is negative or inconclusive.
