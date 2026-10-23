# Run protected checks during Codex activity

`ProtectedVerification` runs a command selected by the controller, with an
explicit environment, private output, and a deadline of at most 30 seconds.
Call it from the existing `CodexCapture#run` observer when the controller needs
an independent check before the agent finishes:

```ruby
receipt = nil
capture.run(**capture_options) do |observation|
  next unless observation.dig('native', 'type') == 'turn.started'

  receipt = Shaka::Evaluation::ProtectedVerification.new(
    environment: verifier_environment
  ).run(command: fixed_verifier_command, cwd: protected_checkout,
        directory: fresh_private_directory, seconds: 10, clock_id: controller_clock_id)
end
```

This example runs once at turn start to demonstrate the connection. A delivery
controller still needs to resolve and pin the actual PR head, choose when a new
head requires verification, and independently post and read back its result.
Never turn native command text, output, or event arguments into verifier commands.
The operator supplies the executable and arguments. Environment selection and
private directory permissions do not isolate the agent; the launcher must
separate its identity, filesystem access, credentials, and network access.

Each instance runs once. Output from both streams stays in a new
`output.log` with mode 0600 inside a new directory with mode 0700.
The returned receipt contains the controller clock identity, monotonic start
and finish times, exit code, byte count, and output digest. Nonzero exits remain
nonzero evidence. A signal exit has a nil exit code and cannot establish success.
No command output enters the agent stream automatically.

Timeout or more than 1 MiB of combined output raises `IOError`; partial output
remains private. The runner terminates its owned process group and reaps its
direct child, including when an exited parent leaves descendants holding pipes.
An exception propagating from the observer also aborts native capture.
Cleanup can add a short grace period and up to five seconds for reaping.

The caller must fit verifier work within the capture deadline. A receipt alone
does not accept a terminal action, prove a hidden task passed, or qualify all
activity. `command_capture_complete` remains false. GitHub review receipts,
delivery grading, full activity qualification, and release decisions need their
own evidence.

Use [head-specific driver reviews](driver-reviews.md) to run this verifier for a
pinned PR head, publish its result, and obtain a native review receipt.
