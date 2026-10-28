# 0005: Which local reviewers a machine is expected to run

Status: accepted on 2026-10-26; not yet implemented. Nothing here is shipped.
Date: 2026-10-25. Tracks [issue #882](https://github.com/shakacode/shaka/issues/882).

## Context

`review.local_review_agents` is the only place that lists reviewers, and it lives in the
repository. Whether a listed reviewer can run depends on each machine: its CLI, an API key
such as `OPENROUTER_API_KEY`, and an account.
[#837](https://github.com/shakacode/shaka/pull/837) made this repository's DeepSeek and Grok
entries active. On a machine with Grok but without `OPENROUTER_API_KEY`, at `8a71c661`:

- `shaka doctor` reports `[DEGRADED] Reviewer CLIs` with
  "This repository configures deepseek/openrouter reviews, but local setup is incomplete."
- Every `shaka reviewer` call returns the same text in `setup_notices`, which
  [review.md](../../skills/shaka/references/review.md) tells the agent to relay once per task.

Neither warning changes what runs. This repository sets `provider_coverage: [anthropic,
openai]`, so selection never picks DeepSeek or Grok unless a task names one. Selection
also already skips a reviewer whose setup is missing (`ReviewerSelection::NOT_SET_UP`).

Both warnings come from `Doctor::CliInventory.setup_notices`, which flags every configured
entry that is not installed. `Doctor::ReviewerClis#readiness` and `Reviewer#setup` are its
only consumers.

How often this happens outside this repository is unknown. The issue reports one
repository; the maintainer accepted a doctor warning for optional reviewers in
[#837](https://github.com/shakacode/shaka/pull/837#discussion_r4374088394) and asked for
this issue in the same review.

R18 in `internal/requirements.md` covers reviewer fallback and skipping missing reviewers. It
does not cover per-machine settings, so decision 2 is a scope extension.

### Predecessor check

`shakacode/agent-workflows` has no `local_review_agents` and no user-level reviewer file.
Its `bin/agent_doctor/configuration.rb` reads `Dir.home` only to locate host homes and
coordination state. Nothing is reused.

## Decisions

1. **Report a missing reviewer only when automatic selection can pick it.** When
   `provider_coverage` is set, entries from providers it does not name run only on a
   task's request: `ReviewCoverage.candidates` keeps only covered providers, and
   `test_a_listed_reviewer_outside_coverage_does_not_run` holds that. `setup_notices` leaves
   those entries out, so `doctor` stays HEALTHY and the agent relays nothing. `doctor` still
   lists them, set up or not, with "(optional: runs only when a task names it)" in place of
   "(configured)". This needs no new setting: Ruby derives it from
   the two settings that already decide selection. When a task does name an optional
   reviewer that is not set up, `shaka review run` fails with `executable_missing` or
   `credentials_missing` and names what is missing, as it does today. Without
   `provider_coverage`, any listed entry can be picked as a fallback, so every entry keeps
   today's notice.

2. **A per-machine list of the reviewers a developer expects to run.** An optional file
   at `~/.agents/shaka/reviewers.yml` names the reviewers this machine is expected to run.
   Entries take the shape of `review.local_review_agents` entries, so the same `model` and
   `effort` rules and warnings apply:

   ```yaml
   version: 1
   reviewers:
     - provider: anthropic
       model_family: claude
       model: claude-opus-5-5
       effort: high
     - provider: openai
       model_family: codex
   ```

   When the file exists, `setup_notices` and `doctor` report a missing reviewer only if
   the file lists it or `provider_coverage` names its provider. Without coverage, that
   narrows today's notices to the reviewers the developer expects. With coverage, it turns
   decision 1's warning back on for an uncovered reviewer the developer relies on, such as
   Grok. The file is bounded:
   - A machine entry matches every repository entry with the same `provider` and
     `model_family`; its `model` plays no part in matching, and two machine entries with
     the same pair make the file malformed. An entry that matches nothing is
     ignored, and `doctor` names it once as unused here. That note is informational: it
     keeps `doctor` HEALTHY and never enters `setup_notices`. So the file cannot add a
     reviewer: the repository's list stays the accepted set and its order stays the preference.
   - Its `model` and `effort` fill only what each matched repository entry leaves unset.
     A task's choice wins over both, and the repository's value wins over the machine's.
     An unset value counts as no team choice; a team that wants a fixed model or effort
     names it. In this repository, neither the Claude nor the Codex review entry names a
     model or effort, so a developer could pin both for their own reviews. DeepSeek names
     both, so the file cannot change them.
   - It does not change which reviewer is selected. Selection already skips reviewers that
     are not set up on the machine.
   - It cannot quiet a covered provider. Coverage gaps keep their warning and their place
     in the published review, because coverage is the repository's statement of who must
     review.
   - It applies with every settings source: team, individual, and preview. It is a fact
     about the machine, like the comment allowlist, not a repository setting.

   It sits beside `~/.agents/trusted-github-actors.yml` under the `.agents` settings
   convention. [ADR 0002](0002-install-locations-and-no-compatibility.md) keeps `~/.agents/`
   for settings and refuses it as an install directory, so the two do not collide. A
   malformed file is an error: `doctor` reports it with the file path, and `shaka reviewer`
   and `shaka review run` refuse to start until it is fixed, so a review never silently
   drops a developer's model or effort. An absent file keeps decision 1's behavior.

3. **Review evidence records machine-supplied model and effort.** Decision 1 and the
   reporting part of decision 2 change warnings only, so they stay out of the settings
   fingerprint. A machine `model` or `effort` changes what a review runs, so it enters
   that review's settings record and fingerprint, labeled as machine-supplied. Two
   developers whose files differ then produce distinguishable review evidence, and changing
   a machine `model` or `effort` that a review uses supersedes earlier review evidence on
   that machine, as any settings change does. The published review shows the model and
   effort each round used, as it does today. Ruby reads the file through `Dir.home`, and
   tests set `HOME` to a temporary directory.

## Alternatives considered

- **An `optional: true` flag on a `local_review_agents` entry.** It is one repository
  field and keeps the home directory clear. Decision 1 gives the same quiet result here
  with no field to maintain, because coverage already says which entries are optional.
  Both lose the warning for a developer who relies on an uncovered reviewer; only
  decision 2 restores it.
- **Let the per-machine file add reviewers.** A developer could review with a model the
  repository never accepted, and the published review would name a reviewer the
  repository's order does not contain. Deferred until someone asks for it.
- **Let the machine's `model` and `effort` override the repository's.** It would help a
  developer whose account cannot use the model the repository names. But any developer
  could then lower the effort the team chose, and individual settings never override team
  settings ([which settings apply](../../docs/settings.md#which-settings-apply)). A
  developer without access can name a model for one task instead.
- **A flat list of `provider/model_family` names.** It is shorter, but it has no place for
  `model` and `effort` and reads differently from `local_review_agents`.
- **Fold this into individual settings.** Individual setup is a whole repository
  configuration used only when no team settings exist
  ([which settings apply](../../docs/settings.md#which-settings-apply)), so it cannot
  describe a machine working across repositories that have team settings.
- **Change nothing.** The maintainer accepted the warning. The cost is a DEGRADED doctor
  line and a relayed notice on every task, for every developer without that setup.

## Consequences

- Decision 1: `CliInventory.setup_notices` takes only inventory entries today, so its two
  callers, `ReviewerClis#readiness` and `Reviewer#setup`, pass the coverage they already
  read. Behavioral tests cover covered, uncovered, and no-coverage repositories. The
  comment above the optional entries in `.agents/shaka/config.yml` and the
  `provider_coverage` section of `docs/settings.md` change to say doctor no longer warns
  about them.
- Decision 2 adds a home-directory file that Shaka reads, a loader that reuses the
  `local_review_agents` entry schema, the model and effort merge in reviewer selection,
  and tests. `docs/settings.md` "Which settings apply?" changes to name a second
  home-directory exception, because it changes what the reader sees there. The
  file is not in `defaults.yml`, because it is not a repository setting. `doctor`
  reports whether the file exists and what it lists. Because the file is machine-wide, a
  malformed one stops local reviews in every repository on that machine until it is fixed;
  that is the price of never dropping a developer's model or effort silently.
- Decision 1 alone loses one warning: a developer who relies on an uncovered reviewer
  learns that its setup broke only when a task names it and `shaka review run` reports
  `executable_missing` or `credentials_missing`. Decision 2 restores the earlier warning
  for developers who list that reviewer.
- No workflow instruction changes: `review.md` already says to relay `setup_notices`, and
  there will be fewer of them.

## Delivery

The maintainer approved both decisions on 2026-10-26, as two PRs in order:

1. Decision 1, which fixes the reported symptom in this repository.
2. Decision 2, with machine `model` and `effort`, after decision 1 merges.
