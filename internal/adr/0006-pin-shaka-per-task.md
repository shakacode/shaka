# 0006: Each task runs its own copy of Shaka

Status: proposed on 2026-10-28; awaiting maintainer approval.
Date: 2026-10-28. Tracks [issue #956](https://github.com/shakacode/shaka/issues/956).

## Context

Validation and review results go stale whenever the installed Shaka checkout moves, even
when the PR head and the repository's settings are unchanged. The agent then reruns full
validation and every local reviewer before it can publish or hand off, about 20 minutes
each time. [#922](https://github.com/shakacode/shaka/pull/922),
[#885](https://github.com/shakacode/shaka/pull/885),
[#735](https://github.com/shakacode/shaka/pull/735), and
[#840](https://github.com/shakacode/shaka/pull/840) all paid for it.

Two comparisons tie a result to the installed revision:

- `Evidence::Inputs.capture` puts `Doctor::InstallationIdentity` into the settings
  fingerprint as its `installation` component, and `Result#settings_reasons` treats any
  changed component except `source` as material.
- `PublicSettings.binding_reasons` compares the recorded public snapshot as a whole, and
  that snapshot holds `installation.revision`.

`evidence run` captures the same inputs before and after the command, so a move during a
run ends it as `not_completed` with `inputs_changed: true`.

The install moves often. On 2026-10-28 the source checkout's reflog shows 15
fast-forwards, each started by a session that updated after a merge, not by a timer.
A 20-minute validation run overlaps one of them often. Waiting until the install is
current before validating, the workaround in use today, does not prevent this: another
session can update during the run.

[ADR 0002](0002-install-locations-and-no-compatibility.md) decision 3 already names the
missing piece. It keeps scheduled updates opt-in "until each revision gets its own
folder", because updating the single source checkout changes files that open chats are
reading.

### Predecessor check

`shakacode/agent-workflows` at `d85eceae` has no per-task install copy and no
installation component in its evidence. Its installation guide allows repository-pinned
copies only for hosts that cannot load installed skills. Nothing is reused.

## Decisions

1. **A task runs one fixed copy of Shaka from intake to outcome.** At intake, after
   resolving the installed skill to its trusted source, the agent runs that helper's new
   `pin` command. `pin` copies the installed revision into its own folder and prints the
   copy's helper path, and the agent keeps that path for the whole task. The workflow
   already tells the agent to keep one absolute helper path, so only the path it keeps
   changes. Every later command, the workflow text, and the reference links it prints
   come from the copy, so a later update of the source checkout does not change the code
   the task runs or the procedures it reads.

   Two small windows stay. The host loads `SKILL.md` through the skill link, which still
   points at the source checkout, and an update can land between that load and `pin`.
   Nothing has run yet, so the task simply pins the newer revision. A host that rereads
   `SKILL.md` later in the chat reads the newer entry point, which only routes to the
   pinned helper the task already holds.

2. **Copies come from a fixed commit through the PR trial packager.** `pin` reads the
   source checkout's `HEAD`, checks out that commit in a temporary directory, and passes
   it to `Installer#run(link: false)`, as `trial prepare` does for a PR head, with
   `~/.local/share/shaka/revisions/` as the managed directory. Copying a commit rather
   than the working tree means a fast-forward during `pin` cannot mix two revisions, and
   local edits in the source checkout never enter a copy. The packager already rechecks
   the source hash after copying and refuses a source that changed. The package ID is
   content-addressed, so tasks on the same revision share one copy, and its atomic
   rename handles two sessions pinning at once. The copy's `.shaka-install.json` records
   the commit as a `revision` source, so `InstallationIdentity.read` and the
   description's workflow version line name the code that actually ran. A copy is about
   3 MB.

3. **Evidence binding stays exact.** The fingerprint keeps the whole installation
   identity and the public snapshot keeps comparing it. Nothing in `Evidence::Result`
   changes. A result binds only when the same Shaka code produced it and checks it, which
   is the guarantee #956 asks to keep. Because the pinned copy never moves, the reruns
   stop without weakening it, and a run in progress no longer reports `inputs_changed`
   from an install update.

4. **Resuming reuses the task's revision.** A resumed task reads the revision its PR
   description's workflow version line names and runs `pin --revision SHA`. That prints
   the helper path of the existing copy of that revision after verifying it. When the
   copy is gone, `pin` rebuilds it from the source checkout's history through decision 2's
   path, so earlier evidence still binds. Only when the source checkout no longer has
   that commit does `pin` copy the current revision instead and say that earlier evidence
   will not bind; the agent then reruns validation and review, as it does today. The
   public `installation.revision` field is not used here: it shows `REDACTED` unless the
   install's repository is recorded as `shakacode/shaka`, and the source checkout records
   its origin URL.

5. **Updates apply to the next task.** `update-check` from a pinned copy compares the
   copy's revision with official main, as it does for the source checkout, so it still
   reports when Shaka is behind. Its guidance adds that the update reaches the next task.
   A maintainer who needs a Shaka fix inside a running task asks for it, and the agent
   runs `pin` again; that choice accepts one rerun of validation and review.

6. **Copies are removed only after they stop being used.** Every helper run from a copy
   touches that copy's `last-used` file, so a task that keeps working, including a
   long `pr watch`, keeps its copy fresh. `pin` removes copies with no helper run for 14
   days, never the one it returns. A task idle longer than that loses its copy and
   decision 4 rebuilds it. `install --verify` reports how many copies exist and their
   total size.

## Alternatives considered

Each row gives the share of the 264 commits on `main` since 2026-10-14 that would still
supersede evidence when an install picks them up. The counts compare each commit's
changed paths with the option's file set; the closure is the `$LOADED_FEATURES` that
requiring each entry file adds under `skills/shaka/lib`.

| Option | Still supersedes | What it gives up |
| --- | --- | --- |
| Keep today's whole-revision identity | All | Nothing; this is the cost #956 reports |
| Fingerprint only the Ruby files that validation and review load, plus `config/` | 106 of 264 (40%) | Nothing for Ruby, whose closure is computed. Prompts and data files under `config/` need a hand-kept list, and a missed file lets stale evidence bind |
| Fingerprint a hand-picked list of evidence files | About 20% | Fails open: a new file that affects review but is missing from the list lets stale evidence bind |
| Rebind when `git diff` between the recorded and current revisions touches no relevant path | Same as the chosen list | Needs Git history, so trial packages cannot use it, and it needs the same relevance list |
| Pin per task (chosen) | None from updates | A task does not get Shaka fixes until it ends unless the maintainer asks |

The Ruby closure of `evidence/command.rb` and `local_review.rb` covers 232 of the 438
files under `skills/shaka/lib`, so most changes to Shaka still reach it. A process rule
alone, such as "do not update while a task runs", cannot hold with many concurrent
sessions on one machine, since any session can update.

## Consequences

- Validation and review evidence survives Shaka updates for the life of a task, and
  every in-progress run finishes against the code it started with.
- A pinned task can run older Shaka than the source checkout for hours. `update-check`
  keeps that visible, and decision 5 gives the explicit way to move.
- `SKILL.md` gains the `pin` step before `update-check`, and the workflow's intake line
  that keeps the helper path names the pinned path. These are entry-point instructions
  loaded on every task, so the implementation PR reports their growth.
- The implementation PR adds tests for both sides: evidence recorded by a pinned copy
  still binds after the source checkout fast-forwards, and evidence recorded before the
  agent repins to a newer revision is superseded. It also tests shared copies, a
  fast-forward during `pin`, rebuilding a removed copy, and that cleanup keeps a copy
  in use.
- ADR 0002's reason for keeping scheduled updates opt-in no longer applies to running
  tasks, apart from the `SKILL.md` windows in decision 1. Turning them on stays a
  separate decision.
