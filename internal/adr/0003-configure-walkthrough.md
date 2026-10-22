# 0003: Configuration walkthrough

Status: proposed; awaiting maintainer approval. Nothing here is shipped.
Date: 2026-10-21. Tracks [issue #817](https://github.com/shakacode/shaka/issues/817).

## Context

A maintainer tuning an existing repository has no guided path. First-time setup and
`doctor` are guided; changing settings means reading the
[settings reference](../../docs/settings.md), 25 settings across about 1,100 lines,
and working out from it what each reviewer receives.

That last part cannot be worked out from `config.yml`. Reviewer instructions come from
three sources that behave differently:

- `review.prompt_file` and `review.post_implementation.prompt_file` replace the packaged
  instructions (`skills/shaka/config/review-prompt.md` and
  `post-implementation-prompt.md`). `pr_description.opening_check` customizes the opening
  check the same way. The fixed rules in `ReviewPrompt::RULES` apply whatever the file says.
- `AGENTS.md` files at the trusted commit are appended as trusted criteria
  (`LocalReviewCriteria`). The root file always applies. A nested file applies only when
  the change touches its directory, so what a reviewer receives depends on the diff.
- `project_guidance` files are read by the working agent, never by a reviewer.

Changing a value is a settings PR that the feature guard refuses as a feature PR. The
existing [human review floors](../../skills/shaka/references/human-review-floors.md)
procedure already publishes such a change through `--flow migration` and lists
`shaka install --update` after merge when the change adds a key the repository did not
set before.

How often maintainers need this is unknown; the issue reports the gap, not a count.

This is a scope extension. No requirement in `internal/requirements.md` covers explaining
or changing an existing configuration, so approving this ADR is the maintainer's scope
decision, and the last delivery PR adds the requirement.

### Predecessor check

`shakacode/agent-workflows` (main, pushed 2026-10-18) has no settings explainer.
`agent-workflow-seam-doctor` merges defaults into a new policy file during init but
never compares current values with defaults or shows reviewer prompts. Its writing-style
resolver labels a repository, user, or packaged source, which is the same labeling idea
as decision 3, but the code is tied to its own layout. Nothing is reused.

## Decisions

1. **A `configure` entry in the existing skill.** `SKILL.md` gains one routing line, like
   `retrospective`, pointing to `references/configure.md`. That procedure loads only when
   the user asks to configure, explain settings, or see a reviewer's prompt. A separate
   skill would show up in host skill lists but adds install and update surface for every
   host.
2. **Ruby reports the settings; the agent explains them.** A new read-only
   `shaka configure settings --root DIR (--ref SHA | --local)` prints JSON with one entry
   per setting: key, effective value, packaged default, whether the repository
   sets it explicitly, whether that explicit value equals the default, and its
   `docs/settings.md` anchor. Explicit values come from the raw seam data that
   `RepositoryConfig` already keeps apart from its effective `to_h`. Effective values and
   defaults come from the resolver each consuming module uses, such as
   `OpeningSchema.effective`, which reads `defaults.yml`; the report never restates a
   default. A test fails when a schema key has no reference anchor, or when a repository
   setting in `defaults.yml` is missing from the report, so a new setting cannot be left out.
3. **Ruby shows each reviewer prompt from the code that sends it.**
   `shaka configure prompts --root DIR (--ref SHA | --local) [--head SHA --base REF]`
   prints the code review, checkpoint, and opening check prompts as labeled sections: `built-in`,
   `repository file PATH@SHA`, or `AGENTS.md PATH@SHA`, with the diff and earlier findings
   shown as placeholders. Without `--head`, it lists every nested `AGENTS.md` with the
   directory that triggers it. With `--head` and `--base`, it shows exactly what a review of
   that change gets. Prompt assembly for all three moves into one module that the
   runners and this command both call, so the report cannot drift from what reviewers
   receive.
4. **Changes leave as a migration-flow settings PR.** The procedure edits
   `.agents/shaka/config.yml`, runs `seam check --local`, and publishes with
   `evidence guard --flow migration` and `description --publication-flow migration`.
   Before editing, it tells the maintainer that installations need `shaka install --update`
   after merge when the change uses a key or value an older Shaka rejects: a new key, a
   new enum option, or a new nested shape. It lists that as an after-merge step in the PR,
   and lists it whenever it cannot tell. Switching between long-supported values lists no
   update.
5. **Reads are trusted; a draft is labeled.** Both commands read settings and prompt files
   at the `--ref` default-branch commit. With `--local` instead, as `seam check --local`
   does, they read the working tree and label every section as an untrusted draft, so a
   maintainer can see what reviewers would receive before publishing an edit. A draft
   report grants nothing; the settings change takes effect only when its PR merges.

## Alternatives considered

- **Extend `review-prompt` with source labels and write a short procedure.** It is smaller,
  but `review-prompt` covers only code review, needs a diff, and leaves settings and
  defaults to the agent. Agent-assembled comparisons can silently skip a setting, which
  fails the acceptance criterion that every setting is explained.
- **Let the agent read `config.yml`, `defaults.yml`, and the prompt files.** It needs no new
  code, but the agent would have to reconstruct the `AGENTS.md` applicability rule and the
  replacement rules, so its answer could differ from what reviewers receive.
- **A separate installable skill.** Covered in decision 1.

## Consequences

- New CLI surface: two read-only subcommands with behavioral tests, and a refactor that
  puts the review, checkpoint, and opening prompt assembly behind one module.
- `SKILL.md` grows by one line; the procedure costs words only when requested.
  `bin/report-instruction-growth` evidence goes with each PR.
- `docs/settings-guide.md` gains a short "Change your settings" section with a prompt; the
  settings reference stays the one place each setting is explained.
- Adding a setting later needs a reference anchor or the anchor test fails.

## Delivery

Recommendation: proceed in this order, each its own PR after this ADR is approved. The
smallest useful stop is after step 1: the prompt report covers what cannot be read from
`config.yml`, and steps 2 and 3 can wait for evidence that maintainers use it. Stopping
there gives up decision 2's guarantee that no setting is left out.

1. Shared prompt assembly and `configure prompts`, with tests that run each runner's real
   path and compare the prompt it sends with the report.
2. `configure settings` and the anchor test.
3. `references/configure.md`, the `SKILL.md` routing line, the guide section, and the
   requirement in `internal/requirements.md`.
