# Rehearse a first Shaka task

Run this rehearsal on demand before a release or after changing onboarding.
A fresh environment tests the installation and delivery path. Only a person new
to Shaka can supply the separate new-user evidence for [#277][acceptance].

## Prepare a run

1. Run `eval/bin/first-task-seed NEW_DIRECTORY` from the Shaka source checkout.
   The command fetches only the synthetic [trial seed][seed], with its checkout
   action pinned for the evaluation organization's policy and no Shaka settings
   or solution. It creates a local checkout and does
   not create a remote, install Shaka, or change an existing directory.
2. In the seed, run `bin/setup` and `bin/validate`. Confirm `bin/greet --plain Ada`
   does not yet print `Hello, Ada`. Host the seed on a fresh, authorized GitHub
   test repository. Follow the identity, protection, and access cleanup requirements from the
   [sandbox setup](../contributing/evaluating-changes.md#set-up-a-sandbox); leave the
   seed unchanged, including omitting the copied-fixture trust file.
   Check that the default branch is at the seed, has no Shaka settings, and
   requires the `test` check. Give the trial identity permission to open a PR
   without administrative access. Keep prior runs out of the trial workspace.
3. Qualify the final runtime before spending a model turn. The coding-agent CLI
   must be available to login shells and able to complete the documented
   installation and Git writes through normal approvals. An unavailable approval
   channel is a harness failure. Keep normal permissions enabled; record any
   pre-approved write roots separately from default-profile evidence. Do not
   weaken installation ownership checks when a sandbox hides the real owner.
4. Use a clean Codex profile and a fresh chat with no Shaka installation, copied
   preferences, or earlier trial context. Follow the [Start here guide][guide]
   and send its installation request first:

   ```text
   Install Shaka from https://github.com/shakacode/shaka.
   ```

   After installation, start a fresh chat to load the skill, then send only the
   task below. A missing `$shaka` skill does not test Shaka delivery; preserve a
   run that bypasses it as a failure. Choose individual setup if asked. Record
   the installed source revision and any help, approval, retry or manual
   workaround. Keep the evaluator's notes out of the chat.

## Task to send

```text
$shaka Add a --plain flag to greet that omits the exclamation point. Go.
```

## Check the result

From outside the trial chat, check the actual PR and run the command on its head.
`bin/greet --plain Ada` should print `Hello, Ada`; `bin/greet Ada` should still print
`Hello, Ada!`. The PR must stay open for the human's merge decision, pass hosted
checks, and have review and validation evidence for the head and settings used.
Check that the diff contains no Shaka settings and that public metadata contains
no private paths, content or fingerprints. The one-line prompt does not ask the
agent to compensate for missing defaults.

Record the PR URL and head, host/profile, installed revision, setup and delivery
time, human/CI waiting, interventions, and pass, fail or blocked. Keep available
model, effort and token evidence on the PR by commit; mark missing or shared
attribution explicitly. A failed setup
or incomplete PR is a result. If a person runs it, ask what they understood from
the PR and settings block before explaining either. Keep raw logs local and use
[the existing issue][acceptance] for public-safe acceptance evidence. A rehearsal
pass does not substitute for participant feedback or authorize a release.

[acceptance]: https://github.com/shakacode/shaka/issues/277
[seed]: https://github.com/shaka-eval-repos/shaka-first-task-1131-20261110-r2/tree/0eebcc10cc0d05ae33e0d1a95bc6a052cea4f5fd
[guide]: https://shaka.shakacode.com/docs/getting-started
