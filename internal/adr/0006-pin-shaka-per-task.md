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
   `pin --task KEY` command, where decision 4 defines the key. `pin` copies
   the installed revision into its own folder and prints the copy's helper path, and the
   agent keeps that path for the whole task. The workflow already tells the agent to keep
   one absolute helper path, so only the path it keeps changes. Every later command, the
   workflow text, and the reference links it prints come from the copy, so a later update
   of the source checkout does not change the code the task runs or the procedures it
   reads.

   Intake calls made before `pin`, such as `update-check`, `seam check`, `doctor`, and
   `claim`, still run from the source checkout. They record no evidence, so an update
   during them changes nothing that later binds; the task simply pins the revision
   current at `pin`. The host loads `SKILL.md` through the skill link, which still points
   at the source checkout. After `pin`, the agent follows the copy's own `SKILL.md`, and
   the copy's workflow says that entry point governs the task, so a host that rereads the
   source `SKILL.md` mid-chat cannot route the task to commands its helper lacks.

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

4. **A local record ties each task to its revision.** The key is the repository plus the
   task's feature branch, such as `shakacode/shaka justin808-claude/956-pin-shaka-per-task`,
   which `claim` reports at intake and the worktree or PR shows on resume. A review-only
   task, which has no branch of its own, uses the repository plus its PR number. `pin`
   records the revision it chose for that key in local state under
   `~/.local/share/shaka/revisions/`, outside every checkout. Running the same command
   again, on resume in a new chat or before any PR exists, returns the recorded
   revision's copy instead of the current install. `pin --task KEY --update` is the one
   way to move a task: it records the current install's revision, and the agent runs it
   only when the maintainer asks for a newer Shaka inside the task. Finish runs
   `pin --task KEY --release` once GitHub confirms the PR's outcome, which deletes the
   record, so a later task on a reused branch name starts from the current install. The
   revision never comes from PR or issue text, which a fork author or commenter can edit.
   The record itself is the maintainer's own local state, which the
   [trust model](../../docs/workflow.md#trust-model) does not defend against, so `pin`
   rebuilds whatever commit it names.

   When the copy is gone, `pin` rebuilds it from the source checkout's history through
   decision 2's path. Earlier evidence binds again only when the rebuilt copy's
   installation identity equals the recorded one; a changed origin URL spelling or a
   newer packager changes it. When the identity differs, or the commit is no longer in
   history, `pin` says that earlier evidence will not bind and the agent reruns
   validation and review, as it does today.

5. **Updates apply to the next task.** `update-check` from a pinned copy compares the
   copy's revision with official main, as it does for the source checkout, so it still
   reports when Shaka is behind. Its guidance adds that the update reaches the next task.
   A maintainer who needs a Shaka fix inside a running task asks for it, and the agent
   runs `pin --task KEY --update`; that choice accepts one rerun of validation and
   review. A copy has no Git checkout, so `update-check` reads the copy's revision from
   its `.shaka-install.json`.

6. **A copy stays while any record names it.** Each `pin` refreshes its record's
   timestamp, then removes records untouched for 60 days, which covers tasks abandoned
   before Finish, and then removes copies that no remaining record names. A running task
   always has a record, so cleanup never removes a copy a helper is using, and helper
   runs need no marker or lock. `pin` holds a lock in the revisions directory while it
   reads or changes records and copies, so two sessions' `pin` calls cannot interleave. A
   task idle past 60 days loses its record, pins the current install, and reruns
   validation and review. `install --verify` reports how many records and copies exist
   and the copies' total size.

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
| Rebind when `git diff` between the recorded and current revisions touches no relevant path | Same as whichever relevance list it uses (40% or about 20%) | Needs Git history, so trial packages cannot use it, and it needs the same relevance list |
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
- `SKILL.md` gains the `pin` step after `claim` reports the branch, and the workflow's
  intake line that keeps the helper path names the pinned path. These are entry-point
  instructions loaded on every task, so the implementation PR reports their growth.
- The implementation PR adds tests for both sides: evidence recorded by a pinned copy
  still binds after the source checkout fast-forwards, and evidence recorded before the
  agent repins to a newer revision is superseded. It also tests shared copies, a
  fast-forward during `pin`, rebuilding a removed copy with an equal and a changed
  identity, resuming before a PR exists, the same branch name in two repositories and
  review-only keys, `--update` moving a task while plain resume does not, `--release`
  letting a new task on the same branch start fresh, and that cleanup keeps every copy a
  record names.
- Tasks in flight when pinning ships rerun validation and review once: their earlier
  evidence names the source checkout's identity, and their first `pin` records a copy's.
- ADR 0002's reason for keeping scheduled updates opt-in no longer applies to running
  tasks once they pin; intake calls before `pin` still read the source checkout.
  Turning scheduled updates on stays a separate decision.
