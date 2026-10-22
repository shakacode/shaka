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
nonempty completed agent message. The last completed message supplies its text.
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
