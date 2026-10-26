# 0004: Which local reviewers a machine is expected to run

Status: proposed on 2026-10-25. Nothing here is shipped.
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
   task's request. `setup_notices` leaves them out, so `doctor` stays HEALTHY and the
   agent relays nothing. `doctor` still lists them, with "(optional: runs only when a task
   names it)" in place of "(configured)". This needs no new setting: Ruby derives it from
   the two settings that already decide selection. When a task does name an optional
   reviewer that is not set up, `shaka review run` fails with `executable_missing` or
   `credentials_missing` and names what is missing, as it does today. Without
   `provider_coverage`, any listed entry can be picked as a fallback, so every entry keeps
   today's notice.

2. **A per-machine list for repositories without `provider_coverage`.** An optional file
   at `~/.agents/shaka/reviewers.yml` names the reviewers this machine is expected to run:

   ```yaml
   version: 1
   reviewers: [anthropic/claude, openai/codex]
   ```

   When the file exists, `setup_notices` and `doctor` report a missing reviewer only if
   the file lists it or `provider_coverage` names its provider. The file only narrows
   reporting:
   - It cannot add a reviewer. A listed identity the repository does not configure is
     ignored, and `doctor` names it once as unused here. The repository's list stays the
     accepted set and its order stays the preference.
   - It does not change selection. Selection already skips reviewers that are not set up
     on the machine.
   - It cannot quiet a covered provider. Coverage gaps keep their warning and their place
     in the published review, because coverage is the repository's statement of who must
     review.
   - It applies with every settings source: team, individual, and preview. It is a fact
     about the machine, like the comment allowlist, not a repository setting.

   It sits beside `~/.agents/trusted-github-actors.yml` under the `.agents` settings
   convention. [ADR 0002](0002-install-locations-and-no-compatibility.md) keeps `~/.agents/`
   for settings and refuses it as an install directory, so the two do not collide. A
   malformed file is an error that `doctor` reports with the file path. An absent file keeps
   decision 1's behavior.

3. **Neither changes review evidence.** Both decisions change warnings, not which reviewer
   runs, so neither enters the settings fingerprint or the evidence result. Ruby reads the
   file through `Dir.home`, and tests set `HOME` to a temporary directory.

## Alternatives considered

- **An `optional: true` flag on a `local_review_agents` entry.** It is one repository
  field and keeps the home directory clear. But it decides for every developer at once: a
  maintainer who relies on Grok and loses its sign-in gets no warning. Decision 1 gives
  the same quiet result for this repository with no field to maintain, because coverage
  already says which entries are optional.
- **Let the per-machine file add reviewers.** A developer could review with a model the
  repository never accepted, and the published review would name a reviewer the
  repository's order does not contain. Deferred until someone asks for it.
- **Fold this into individual settings.** Individual setup is a whole repository
  configuration used only when no team settings exist
  ([which settings apply](../../docs/settings.md#which-settings-apply)), so it cannot
  describe a machine working across repositories that have team settings.
- **Change nothing.** The maintainer accepted the warning. The cost is a DEGRADED doctor
  line and a relayed notice on every task, for every developer without that setup.

## Consequences

- Decision 1: a few lines in `CliInventory` and `ReviewerClis`, with behavioral tests for
  covered, uncovered, and no-coverage repositories. The comment above the optional entries in
  `.agents/shaka/config.yml` and the `provider_coverage` section of `docs/settings.md`
  change to say doctor no longer warns about them.
- Decision 2 adds a home-directory file that Shaka reads, a loader with schema checks,
  and tests. `docs/settings.md` "Which settings apply?" changes to name a second
  home-directory exception. The file is not in `defaults.yml`, because it is not a
  repository setting. `doctor` reports whether the file exists and what it lists.
- No workflow instruction changes: `review.md` already says to relay `setup_notices`, and
  there will be fewer of them.

## Delivery

Recommendation: ship decision 1 as one PR after this ADR is approved. It fixes the
reported symptom in this repository. Hold decision 2 until a repository without
`provider_coverage` reports the same noise, because nothing yet shows that it happens.

## Open question

Should decision 2 ship now with decision 1, or wait for that second report? Recommended:
wait. Decision 1 removes the warning seen here, and decision 2 adds a home-directory file
Shaka must support across hosts.
