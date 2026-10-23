# Check newly observed PR commits during a Codex run

`CodexDriver` connects the [native observer](codex-events.md) to
[protected verification and COMMENT publication](driver-reviews.md).
On turn start and each completed command item, it reads the declared PR's native
GitHub head. A different observed head triggers one verification and strict review
readback. Command text and output never select a commit, executable, or repository.

```ruby
driver = Shaka::Evaluation::CodexDriver.new(
  plan, github: absolute_gh_path, environment: agent_environment,
  verifier: { command: fixed_verifier_command, cwd: protected_checkout,
              environment: verifier_environment },
  max_attempts: operator_attempt_bound
)
result = driver.run(command: fixed_codex_command, cwd: agent_workspace,
                    directory: fresh_private_directory, seconds: cell_seconds)
```

The plan declares `repository`, PR `number`, `driver_actor`, and a
`clock_id` unique to this controller lifetime. The verifier must obtain and test
exactly `SHAKA_EVAL_HEAD`; it receives its own explicit environment. Keep its
checkout, credentials, controller directory and fixed command outside the agent's
access. The API does not establish that isolation.

Unchanged observations do not repeat verification, including a FAIL. A later
different head can recover; returning to an earlier SHA runs another check.
Attempts and cumulative executions count from one in this single run.
A flushed, synced private `ledger.jsonl` records each started attempt before work
and its completed receipt afterward. An exception records a failed attempt and
aborts capture without an aggregate result. A failed entry does not establish
whether execution or publication occurred; inspect retained evidence before
starting another controller. Instances cannot resume or retry ambiguous writes.

The fresh controller directory is mode 0700; the ledger is 0600. Raw native logs
and each verifier's bounded output stay beneath it. Discovery and verification
share the capture deadline; each GitHub transaction is also limited to 30 seconds.
The operator supplies a positive attempt bound. Cleanup retains the underlying
process APIs' termination grace.

The return contains `capture` and `verifications`. Receipt times remain those
of the original pipe read: controller work cannot move an already buffered
terminal event after publication. No terminal action is accepted here.
`command_capture_complete` stays false.

This is checkpoint-based discovery, without background polling. It can miss heads
between observations or a newly pushed head while GitHub still reports the prior
SHA. It does not wait for a PR to be created, qualify every tool route, assemble
delivery records, or produce release decisions. Complete activity capture and
terminal acceptance still require separate qualification.

## Public mechanics qualification

The [retained fixture PR](https://github.com/shaka-eval-repos/shaka-native-driver-qualification-866/pull/1)
exercised real GitHub APIs with scripted native events and a fixed verifier that
fetched each SHA and checked its blob. It produced
[FAIL](https://github.com/shaka-eval-repos/shaka-native-driver-qualification-866/pull/1#pullrequestreview-5624658254),
then [PASS](https://github.com/shaka-eval-repos/shaka-native-driver-qualification-866/pull/1#pullrequestreview-5624659257).
Moving the head after a further POST left a
[historical COMMENT](https://github.com/shaka-eval-repos/shaka-native-driver-qualification-866/pull/1#pullrequestreview-5624664881);
strict readback refused a usable entry.

Two earlier setup attempts exposed GitHub head propagation: one checkpoint saw
the previous SHA; another run aborted when discovery and verification disagreed.
The successful fixture synchronized setup and continued emitting checkpoints.
This establishes mechanics on that fixture, with zero model calls. It does not
qualify agent-authored pushes, protected checkout isolation, Linux integration,
complete capture, or measured Ask cells.
