# Welcome and setup diagnosis

Use this path when Shaka is invoked without a task or with `doctor` alone.
Resolve the trusted installed helper as the skill directs before running it.

For an invocation with no task, run the saved helper without arguments for the
welcome guide, then run its `doctor` command. For `doctor` alone, run that
diagnostic directly. Pass `--root` when the user names a checkout and `--host`
when the current host is known. Doctor is read-only; it can report missing
repository setup while still listing CLIs.

Explain what is ready and the first useful fixes, using the report's evidence.
Distinguish CLIs found on PATH from verified sign-in or working reviews. Offer
the reported installation links for missing tools, and explain why a second
provider can help independent review. Keep optional tools optional.
Installation, sign-in, and repository setup are separate actions the user can
request; the diagnostic itself changes nothing.

For the empty invocation, show one copyable task example and the setup or resume
prompt that fits the report. Ask one question about what the user wants to do
next. For `doctor`, finish with the next steps and stop. Neither path begins
task planning or PR delivery. Continue through `workflow` only once the user
gives a task.

For repository setup, `seam init` writes under `.agents/shaka/`. Version-one
configuration directly under `.agents/` keeps working; use the
[configuration layout upgrade](migration.md#upgrade-the-configuration-layout)
when the user wants to move it.
