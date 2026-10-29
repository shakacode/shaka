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
   come from the copy, so a later update of the source checkout changes nothing the task
   reads or runs.

2. **Copies reuse the PR trial packager.** `pin` calls `Installer#run(link: false)`, the
   path `trial prepare` uses, with the source checkout as the source and
   `~/.local/share/shaka/revisions/` as the managed directory. The package ID is
   content-addressed, so tasks on the same revision share one copy, and the packager's
   atomic rename already handles two sessions pinning at once. The packager records the
   copied commit as a `revision` source in the copy's `.shaka-install.json`, so
   `InstallationIdentity.read`, the published `installation.revision`, and the workflow
   version line all name the code that actually ran. A copy is about 3 MB. `pin` refuses
   a source checkout with local changes, which the packager would record as a
   `development` source, so every copy matches one commit.

3. **Evidence binding stays exact.** The fingerprint keeps the whole installation
   identity and the public snapshot keeps comparing it. Nothing in `Evidence::Result`
   changes. A result binds only when the same Shaka code produced it and checks it, which
   is the guarantee #956 asks to keep. Because the pinned copy never moves, the reruns
   stop without weakening it, and a run in progress no longer reports `inputs_changed`
   from an install update.

4. **Resuming reuses the task's copy.** A resumed task reads the revision its PR
   description's workflow version line names, or the `installation.revision` its saved
   evidence results recorded, and runs `pin --revision SHA`. That prints the helper path
   of an existing, verified copy of that revision. When no copy remains, `pin` makes a
   new copy from the current install and says that earlier evidence will not bind, and
   the agent reruns validation and review, as it does today.

5. **Updates apply to the next task.** `update-check` from a pinned copy compares the
   copy's revision with official main, as it does for the source checkout, so it still
   reports when Shaka is behind. Its guidance adds that the update reaches the next task.
   A maintainer who needs a Shaka fix inside a running task asks for it, and the agent
   runs `pin` again; that choice accepts one rerun of validation and review.

6. **Old copies are removed when unused.** Each `pin` touches a `last-used` file in the
   copy it returns. `pin` then removes copies unused for 14 days, skipping the one it just
   returned. A task paused longer than that loses its copy and follows decision 4's
   fallback. `install --verify` reports how many copies exist and their total size.

## Alternatives considered

Each row gives the share of the 264 commits on `main` since 2026-10-14 that would still
supersede evidence when an install picks them up.

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
  agent repins to a newer revision is superseded. It also tests shared copies, the
  resume path, and cleanup.
- Hosts with ADR 0002's opt-in scheduled updates can turn them on safely once this
  ships, because no running task reads the source checkout after intake.
