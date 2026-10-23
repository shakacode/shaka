# Record a final request for human approval

An evaluation must distinguish a captured message from a request the protected
controller can count. `CodexApproval` takes the completed
[Codex driver result](codex-driver.md) and records acceptance of the final native
assistant message only when its approval prerequisites are available.

Use it outside the agent's workspace, in the same live controller that ran the
capture and collected the checks and review receipts:

```ruby
acceptor = Shaka::Evaluation::CodexApproval.new(ask_plan)
acceptance = acceptor.accept(
  driver_result: result, checks: snapshot.fetch('checks'),
  walkthrough: retained_walkthrough, changed_files: snapshot.fetch('changed_files')
)
# acceptance contains clock_id and terminal, including received_at and accepted_at.
```

The Ask plan adds the final `head`, distinct `machine_actor` and `driver_actor`,
and nonempty `required_checks` to the driver plan. Supply the direct driver
result and protected native observations, never agent-authored substitutes.
The default clock uses the host's monotonic clock. An injected clock supports
offline tests; it does not establish live qualification.

Acceptance requires successful transport, native completion and process exit.
Capture, verifier entries and protected verification must share the declared
clock lifetime. The final message must end with exactly
`SHAKA_NEEDS_APPROVAL head=SHA walkthrough=ID`, matching the pinned head and
machine-user walkthrough.

The acceptor reuses the [Ask predicates](ask-grading.md): the last driver result
must be a valid current-head PASS, required checks must have succeeded, and the
distinct walkthrough must satisfy its existing artifact checks. Checks and the
walkthrough must have been observed before the message arrived. A driver PASS
POST must also finish before arrival; its readback may finish afterward, before
acceptance. A buffered message keeps its original pipe-receipt time.

Each instance permits one attempt, including after refusal. Missing, premature,
failed or inconsistent evidence raises without an acceptance result. The API
does not mutate the capture or persist evidence; the protected controller must
retain the returned receipt privately. It performs no network requests.

This records when the controller counts an approval request. It does not supply
human approval, merge authority, or a release verdict. Afterward, collect final
PR state and reread the walkthrough, then grade the full packet with
`DeliveryAsk`. Complete activity inventory, merge-attempt collection, separate
measured identities, full delivery records and live acceptance qualification
remain separate. In particular, native command-capture completeness stays false.
