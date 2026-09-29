# Evaluate a Shaka change

Use a small, recorded experiment when tests prove a skill or plugin change works
but do not establish that it helps a maintainer. [Shaka #206](https://github.com/shakacode/shaka/issues/206)
tracks these evaluations. Record each attempt in the [experiment index](https://github.com/shakacode/shaka/blob/main/eval/README.md),
including failed harness runs. A green test, a completed PR, and an improvement in
human attention or cost are different claims.

## Set up a sandbox

ShakaCode contributors can use a team-authorized evaluation organization. Other
contributors can use their own GitHub organization or account and public test
repositories. The procedure does not depend on a particular computer, GitHub
login, or coding-agent subscription. Public repositories test public GitHub
delivery mechanics; they do not test private-organization features or hide prior
solutions from later agents.

Prepare Docker, Git, a coding agent, and a GitHub CLI whose **final agent image**
supports the trusted Shaka helper's exact commands. In particular, exercise
`gh pr checks --required --json name,state,bucket,link` there before a model call.
Check authenticated integration separately; a CLI help or parsing check alone
does not establish access to required checks, reviews, or Git push.

Keep two roles distinct:

- An operator creates the repository, configures protection, and grants access.
  Operator credentials stay outside the agent container.
- A non-admin agent identity gets Write only on its active test repository.
  Set its organization base repository permission to none, avoid sibling-repo
  grants, and verify the effective access before each run. The GitHub credential
  may be reusable if organization policy permits, but the temporary repository
  grant is removed after the run. Store credentials outside source and logs.

Use a separate coding-agent sign-in for the sandbox if the host supports one.
Do not mount a contributor's normal agent home, SSH keys, GitHub configuration,
or Docker socket into the agent. A reusable sandbox sign-in is an operator
choice: document where it is stored and how to revoke it. It may still require
reauthorization later.

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
isolation, permitted network egress, denied off-list destinations, and target-only
GitHub access. Do not relax a failed gate or substitute a model to keep the run
moving. Treat a wrong initial failure, unsupported CLI, missing access, or empty
reference-repair diff as a **harness error**, not a result for the candidate.

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
access. A later measured case must not reuse a public solved fixture as if its
solution were hidden; use separately isolated private cells when the approved
experiment needs hidden evidence.

## First value case: PR #250

[PR #250](https://github.com/shakacode/shaka/pull/250) proposes loading an optional
`.agents/writing-style.md` from the trusted default-branch commit. Its tests and
CLI check demonstrate the loader mechanism, not that automatic loading improves
writing or saves maintainer effort. The cheaper comparison is an `AGENTS.md`
pointer to the same style guide. The PR is on hold and must not be merged as a
side effect of its evaluation.

An offline smoke check against one pinned trusted ref found no `writing_style`
field with the baseline helper and a guide with the candidate helper. That
check used no model and did not exercise a fresh consumer delivery; it does not
resolve the value question.

Pin the historical comparison to the PR's base `ceb9989d249e04b70e5d6871f384ae2ce2a89269`
and candidate `e387b5da92f979bc7571d6e3a4ed91bc8eb0e02e`, then refresh their
live status before execution. If the candidate changes, treat that as a new
revision. Current-main compatibility and merge readiness require their own
checks; a result against the historical base does not establish either.

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

The next test has not run. Agree on its fixture, model, budget, and permitted
repository visibility before provisioning resources or calling a model. Record
the result even if it is negative or inconclusive.
