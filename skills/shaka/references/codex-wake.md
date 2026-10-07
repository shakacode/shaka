# Codex native follow-up

Use this host boundary before a Codex handoff that promises automatic follow-up.
A shell watcher detects GitHub changes; it cannot establish that Codex desktop
will start another turn after the current turn ends. `SHAKA_WAKE`, an execution
session ID, or a completed process is detection evidence only.

## Register bounded follow-up

1. Verify automatic follow-up is authorized for this owning chat. Discover the
   native automation tool and inspect its current schema. Without that tool or
   authorization, use the manual handoff below.
2. Cancel this task's previous native registration and shell watcher before
   creating another. Use a thread heartbeat targeting the owning chat, with a
   finite minute schedule ending by the task deadline. A standalone cron task,
   a shell-cron workaround, or a suggested automation awaiting approval does
   not establish same-chat registration.
3. Put the exact PR URL/head, owner, expiry, and trusted helper in the heartbeat
   prompt. Refresh the live PR and filtered comments on resumption. Diagnose
   actionable CI failures through the normal validation/review loop. Preserve
   Ask merging and exact-head gates. Stop on closure, confirmed transfer, expiry,
   or the task deadline, and remove the registration. Keep unchanged runs quiet.
4. Require a successful native creation response with an automation ID and ACTIVE
   status. Read back the native registration through the host, or its saved native
   configuration when the tool returns only a card. Confirm heartbeat kind,
   owning thread, ACTIVE status, and the finite schedule. Rejected, paused, or
   failed requests provide no automatic coverage. Cancel a partial registration
   before falling back.

Save a JSON packet outside the checkout, copied from the successful native
response and readback. Its fields are:

- `registration`: the returned `automationId`, `mode`, and `status`.
- `readback`: the native `id`, `kind`, `status`, `target_thread_id`, `rrule`,
  `created_at`, and `updated_at` fields. Preserve timestamps in milliseconds.
- `repository`, integer `number`, and full `head`: the current PR identity.
- `expires_at` and `deadline`: ISO 8601 timestamps with timezone offsets.

Pass `--codex-wake PATH` to `handoff` with `--head SHA`. A Codex invocation
identified by `CODEX_THREAD_ID` refuses `--woken-by` without this packet. It checks
matching ACTIVE registration/readback, the current chat and PR/head, and an
unchanged finite minute schedule within the supplied expiry/deadline. Renew by
canceling and creating a new registration, then replace the packet. Other native
schedule shapes use manual handoff until their bounds can be checked.

Ruby validates the supplied fields; it does not authenticate the packet, read
the native scheduler, verify conversational authorization, or prove a later turn
started. Inspect the actual native result before copying it. A successful check
means **native follow-up registered; live resumption unverified**, until an actual
native-started turn is observed. Record that distinction in WIP Details along
with the registration ID, exact head, expiry, and manual owner/resume prompt.
For an Ask comment monitor, retain the merge label and omit `--woken-by`; pass
`--codex-wake` to check its registration evidence without replacing the label.

A native heartbeat can read GitHub directly through the trusted `pr` and
`comments` commands, so it needs no parallel shell watcher. If a shell watcher
is retained for detection, keep one owned run and a handled comment baseline;
its completion still provides no native resumption evidence.

## Hand off manually

When registration is unavailable, fails, or expires, say **Automatic feedback
intake unavailable** in the PR and final handoff. Preserve the named person
checking feedback, exact PR URL/head, expiry or failure time, and exact resume
prompt: `$shaka PR_URL`. Keep `awaiting-resume` for pending agent work, or the
merge label when merge is the only remaining action. Do not use `--woken-by`.
Codex CLI without native thread automation uses this path too.

## Record a live demonstration

Record native registration ID, owning chat, exact PR/head, registration and expiry
times, and the observed next-turn timestamp. Distinguish an observed native wake
from a manual resume or a turn already running when the schedule fires. Clean up
test registrations. Synthetic registration/failure tests establish packet handling,
not automatic resumption or correct handling of a real review. The feedback cases
owned by #419 remain separate acceptance work.
