# Publish a protected result for the current PR head

`DriverReview` runs a fixed verifier and posts its result as a head-bound
COMMENT review. It returns evidence only after GitHub readback confirms the
review's identity, author, head, exact body, and current open PR.

```ruby
writer = Shaka::Evaluation::DriverReview.new(
  plan, github: absolute_gh_path, environment: verifier_environment
)
entry = writer.run(command: fixed_verifier_command, cwd: protected_checkout,
                   directory: fresh_private_directory, attempt: 1, executions: 1)
```

The controller supplies `repository`, `number`, the full `head` SHA,
`driver_actor`, and its `clock_id` in the plan. The agent never selects
commands or credentials through event text. Invoke this API from the native
observer after the controller resolves a new head; head discovery is still
the caller's responsibility. [CodexDriver](codex-driver.md) connects these calls
to bounded native activity checkpoints and a private ledger.

Before and after verification, the writer reads the native PR and requires
the same open, unmerged, same-repository head. It supplies that SHA through
`SHAKA_EVAL_HEAD`, overriding any environment value. The fixed verifier must
obtain and test exactly that revision in a protected checkout. Passing this
input does not independently qualify its checkout, hidden tests, or isolation.
Keep driver credentials and private receipts separate from the agent.

Exit code zero produces `driver-verification: PASS`; other exits produce
`FAIL`. The fixed result line includes the SHA, attempt ordinal and cumulative
verifier execution count. The review is explicitly labeled as a scripted fixture.
The writer never approves, merges, or edits a PR.

One instance allows one attempt. The controller owns cumulative counts and
the retained verification ledger; the existing Ask grader checks count ordering.
All native requests and verifier work share a deadline of at most 30 seconds.
Verifier cleanup can add its documented termination grace. Output remains private
and bounded through [protected verification](protected-verification.md).

The returned entry contains the verification receipt, POST completion time and
[native review readback](delivery-readback.md), with the controller clock identity.
A head change after POST or a changed review refuses usable evidence. Posting is
not atomic with head movement: an older head can retain the historical review.
An error after a write may leave a review on GitHub. Do not automatically retry;
inspect the native review history before deciding whether another attempt is needed.

This API supplies one driver-review entry for the existing assertions. Complete
activity capture, terminal acceptance, delivery records and release decisions
still need their own evidence.
