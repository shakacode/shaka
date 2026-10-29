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
   resolving the installed skill to its trusted source, the agent runs that source
   helper's new `pin --task KEY` command, where decision 4 defines the key. `pin` copies
   the installed revision into its own folder and prints the copy's helper path. The agent
   keeps two paths for the task: the source helper, used after pinning only for `pin` and
   its variants, and the copy's helper, used for every other command. The workflow already
   tells the agent to keep the source helper path, so the copy's path is the one addition.
   The workflow text and the reference links come from the copy, so a later update of the
   source checkout does not change the code the task runs or the procedures it reads. This
   holds for evidence because `InstallationIdentity.read` locates `.shaka-install.json`
   relative to its own file, so the running copy reports its own identity to
   `Evidence::Inputs.capture`.

   Intake calls made before `pin`, such as `update-check`, `seam check`, `doctor`, and
   `claim`, still run from the source checkout. They record no validation or review
   evidence, so an update during them changes nothing that later binds; the task pins the
   revision current at `pin`. The host loads `SKILL.md` through the skill link, which
   still points at the source checkout, and may reinject it mid-chat, for example after
   context compaction. Every revision's `SKILL.md` therefore keeps one rule: a task that
   already holds a pinned helper keeps using it. That rule is agent-enforced; no code
   stops an agent from calling the source helper for other commands.

2. **Copies come from a fixed commit through the PR trial packager.** `pin` reads the
   source checkout's `HEAD`, checks out that commit in a temporary directory, and passes
   it to `Installer#run(link: false)`, as `trial prepare` does for a PR head, with
   `~/.local/share/shaka/revisions/` as the managed directory. Copying a commit rather
   than the working tree means a fast-forward during `pin` cannot mix two revisions, and
   local edits in the source checkout never enter a copy. The packager already rechecks
   the source hash after copying and refuses a source that changed. The package ID is
   content-addressed, so tasks on the same revision share one copy, and its atomic rename
   means an interrupted `pin` never leaves a partial copy. The copy's
   `.shaka-install.json` records the commit as a `revision` source, so
   `InstallationIdentity.read` and the description's workflow version line name the code
   that actually ran. A copy is about 3 MB.

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
   `pin --task KEY --release` once GitHub confirms the PR's outcome, and a review-only
   task runs it at its requested outcome. Release deletes the record, so a later task on
   a reused branch name or PR starts from the current install. The revision never comes
   from PR or issue text, which a fork author or commenter can edit.
   The record itself is the maintainer's own local state, which the
   [trust model](../../docs/workflow.md#trust-model) does not defend against, so `pin`
   rebuilds whatever commit it names.

   When the copy is gone, as after `--prune`, `pin` rebuilds it from the source checkout's
   history through decision 2's path. Earlier evidence binds again only when the rebuilt
   copy's installation identity equals the recorded one; a changed origin URL spelling or
   a newer packager changes it. When the identity differs, or the commit is no longer in
   history, `pin` says that earlier evidence will not bind and the agent reruns validation
   and review, as it does today.

5. **Updates apply to the next task.** `update-check` stays an intake call of the source
   helper, and its guidance adds that an update reaches the next task. A maintainer who
   needs a Shaka fix inside a running task asks for it, and the agent runs the source
   helper's `pin --task KEY --update`; that choice accepts one rerun of validation and
   review.

6. **Only the source helper changes records, and pruning is explicit.** Every `pin`
   variant runs from the source helper, so the current packager builds every copy and
   one revision at a time reads and writes the records. Records carry a format version;
   `pin` treats a record it cannot read as absent, so a format change costs one rerun
   rather than a wrong revision. `pin` holds a lock in the revisions directory while it
   reads or changes records and copies. Nothing removes a copy automatically, so no
   running helper can lose its files. `pin --prune` removes only copies that no record
   names, so it is safe while tasks run. A record ends only through `--release`;
   `install --verify` lists each record with its key and age, so the maintainer can
   release one a task abandoned. It also reports the copies' total size and warns above
   500 MB.

## Alternatives considered

Each row gives the share of the 264 commits on `main` since 2026-10-14 that would still
supersede evidence when an install picks them up. The counts compare each commit's
changed paths with the option's file set; the closure is the `$LOADED_FEATURES` that
requiring each entry file adds under `skills/shaka/lib`.

| Option | Still supersedes | What it gives up |
| --- | --- | --- |
| Keep today's whole-revision identity | All | Nothing; this is the cost #956 reports |
| Fingerprint only the Ruby files that validation and review load, plus `config/` | 106 of 264 (40%) | Little for Ruby, whose closure is computed, though a lazy `require` escapes it. Prompts and data files under `config/` need a hand-kept list, and a missed file lets stale evidence bind |
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
  letting a new task on the same branch start fresh, an unreadable record format, and
  that `--prune` keeps every copy a record names.
- Tasks in flight when pinning ships rerun validation and review once: their earlier
  evidence names the source checkout's identity, and their first `pin` records a copy's.
- ADR 0002's reason for keeping scheduled updates opt-in no longer applies to running
  tasks once they pin. Intake calls before `pin` still read the source checkout, and a
  host can reinject the source `SKILL.md`, limited by decision 1's rule.
  Turning scheduled updates on stays a separate decision.
