# Retain Codex native events

`CodexEvents` retains private observations from one `codex exec --json`
invocation. The protected controller feeds each stdout JSONL record as it arrives,
then calls `finish` after EOF and reaping its owned process.

```ruby
require_relative 'lib/shaka/evaluation/codex_events'

reader = Shaka::Evaluation::CodexEvents.new(clock_id: controller_clock_id)
# Inside the controller's bounded process transport:
reader.receive(native_stdout_line)
# After EOF and process reap:
capture = reader.finish(exit_code: native_process_status.exitstatus)
```

The receipt retains native events, their ordinal and host-monotonic receipt time,
thread ID, byte count and the SHA-256 digest of the exact supplied bytes.
Native timestamps never replace the controller clock. Raw events may contain
private output or credentials; keep this receipt and the original stream outside
agent mounts and public summaries. Parsing a saved stream records replay time,
not its original arrival time.

A `terminal` candidate requires native turn completion, exit code zero and a
nonempty completed agent message. Every reported item must have a completion
event; an unfinished command or tool leaves the invocation incomplete even after
`turn.completed`. The last completed message supplies its text.
Reasoning and tool output cannot supply it. The reader supplies `received_at`;
the protected controller still owns acceptance and any queued PASS readback.
Failed or incomplete runs retain observations with no terminal candidate.
`native_status: completed` describes the invocation, not delivery success.

Unknown envelopes, malformed or duplicate-key JSON, invalid event order, item ID
reuse and broken clocks raise `IOError` and invalidate the capture permanently.
One stream supports one thread and one turn. Limits are 1 MiB per line, 64 MiB
total and 100,000 events. Use the locked evaluation bundle. The receiver launches
no process and enforces no read deadline; its caller owns timeout and cleanup.

`command_capture_complete` is always false. The reader preserves command and
other native item data without interpreting shell text, proving execution,
inventorying merge attempts or detecting an API call hidden inside a script.
The [Ask grader](ask-grading.md) therefore cannot pass its `no_merge` assertion
from this capture. Live transport/isolation qualification, hidden verification,
full tier 3 D2 assembly and release verdicts remain separate work.

The [official Codex JSONL contract](https://learn.chatgpt.com/docs/non-interactive-mode#make-output-machine-readable)
supplies the supported envelope names. This reader adds no model call or schedule.
The [Linux collection check](reports/codex-linux-collection.md) records the tested
container recipe, native sandbox failure, costs and remaining release prerequisites.

## Read a live process

`CodexCapture` connects the reader to an operator-selected process on a POSIX host:

```ruby
require_relative 'lib/shaka/evaluation/codex_capture'

capture = Shaka::Evaluation::CodexCapture.new(environment: selected_child_environment).run(
  command: pinned_codex_argv, cwd: agent_workspace, directory: new_private_directory,
  seconds: 60, clock_id: controller_clock_id
)
```

The command starts with an absolute executable path. Its arguments, environment,
workspace and output directory come from the protected operator. The operator
reserves the evaluation budget before calling it and accounts for usage afterward.
The capture does not select models, discover credentials or provide agent isolation.

The new directory is private, with exclusive `stdout.jsonl` and `stderr.log` files.
Stdout retains the reader's bounds; stderr is limited to 8 MiB. Both pipes drain
under one deadline. Parent exit triggers group cleanup before waiting for EOF;
timeout or invalid output also terminates and reaps the owned process.
Raw output remains private, including after failure.

`transport_status` describes collection, not task success. A timeout returns
`timed_out` with no terminal candidate. Native failure or missing completion also
cannot produce a terminal. `command_capture_complete` remains false, including
after a successful live invocation. This connection does not qualify full command
coverage, GitHub delivery, hidden verification or a release verdict.
