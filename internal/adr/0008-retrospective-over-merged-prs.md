# 0008: Retrospectives over merged PRs

Status: proposed.
Date: 2026-11-13. Revision read: Shaka `48874c5`.
Related: [ADR 0001](0001-eval-and-release-gating.md),
[ADR 0007](0007-companion-skill-hooks.md), [issue #395](https://github.com/shakacode/shaka/issues/395).

## Context

[retrospective.md](../../skills/shaka/references/retrospective.md) analyzes coding sessions
the user names. It looks for navigation, check, instruction, and tool-overhead friction, reads
the helper call log, reports numbered findings, and stops until the user picks which ones to
pursue. It never starts unasked, "not after a PR, not on a schedule."

Sessions are a hard source. Transcripts live in one host, get summarized away, and are private,
so a session retrospective can only cover the chats the user still has open. Meanwhile every
Shaka PR already publishes a structured record on GitHub:

- **Timings:** time before the PR opened, time between checkpoints, and each wait on a person
  with its kind (answer, merge approval), per [timings](../../docs/reference/timings.md).
- **Usage and cost:** tokens and estimated dollars by model, including local review, in
  append-only comments.
- **Review evidence:** each reviewed commit's findings with dispositions (`fixed`, `dismissed`,
  `accepted`, and so on) and which reviewer reported them, per issue #395.
- **Verification and risk:** the checkpoint's risk rating, what ran on which head, and what
  stayed unverified.
- **Skills used:** each applied skill with source, revision, phase, and contribution.
- **CI and merge:** Actions runs on each head, and the merge time `pr watch` records.

[#1135](https://github.com/shakacode/shaka/pull/1135) added `shaka timings report`, which
totals timing categories across merged PRs, ranks them, and groups them by week, and taught
retrospective.md to use it for a retrospective of PR timings. That covers where time goes. The
rest of the record (cost, review value, CI repairs, risk, skills) is still read by hand: the
[30-day CI and hosted review study](../../docs/articles/ci-and-hosted-review-repairs.md)
showed what it can answer, but an agent assembled it one PR at a time.

### Predecessor check

Not done yet. Check `shakacode/agent-workflows` for PR-history analysis before implementation.

## Decisions

1. **Extend `timings report` into a PR record report.** Keep `timings report` as it is and add
   a sibling, `shaka pr-record report --repository OWNER/REPO` with `--prs N,M`, `--last N`, or
   `--since DATE`, that reuses its PR search and limit handling. It writes one JSON record per
   merged PR: the timing categories `timings report` already reads, usage by model, review
   rounds and finding dispositions by reviewer, risk rating, skills used, CI attempts with
   their outcome, and merge time. A field the PR does not carry is `UNKNOWN`, as in the PR itself. Ruby does
   the reading and arithmetic; the agent does the interpretation. Only published PR data is
   read, so no transcript or private session content enters the analysis.

2. **The PR timings retrospective grows into a PR retrospective.** `/shaka retrospective last
   20 PRs` (or a date range or PR list) runs both reports and analyzes across PRs. Timing
   findings keep using `timings report` totals, as retrospective.md says today. It looks for:

   - **Waiting on people:** long merge-approval waits on low-risk PRs suggest Auto with a
     review floor; long answer waits suggest questions that intake could have asked earlier.
   - **Slow checks:** validation steps that dominate time between checkpoints suggest scoped
     validation or a faster local command.
   - **Review value:** per reviewer, how many findings were fixed versus dismissed, and how
     many hosted review findings arrived after local review passed. This suggests reviewer
     order, count, or prompt changes.
   - **CI repairs:** failures the branch caused that local validation should have caught.
   - **Effort and cost:** spend per PR by model and effort against the risk rating, to spot
     high effort on low-risk work.
   - **Skills:** outcomes with and without each companion from ADR 0007, which feeds the
     `suggest` to `use` decision there.

   Findings use the existing table (observed behavior, evidence, proposed improvement,
   expected benefit, maintenance cost), with PR links as evidence. The report gives medians
   and the number of PRs behind each claim, and calls a pattern from fewer than five PRs
   insufficient evidence. Then it stops, and selected findings become ordinary Shaka tasks,
   exactly as the session mode does today.

3. **A repository can opt in to a short retrospective after each merge.** A new setting:

   ```yaml
   retrospective:
     after_merge: off      # off (default) | suggest | run
     window: 20            # PRs the after-merge run compares against
   ```

   With `suggest`, the agent that merged or saw the merge offers one line: "Want a quick
   retrospective of this PR against the last 20?" With `run`, it runs the PR mode on the merged
   PR against the window and reports in chat. Either way it posts nothing to GitHub, edits
   nothing, and stops after the findings. `off` keeps today's rule. The "never unasked" line in
   retrospective.md changes to "never unasked unless `retrospective.after_merge` says so," and
   the setting comes from the default branch like every other trusted setting.

4. **Session mode stays as it is.** It still covers what PR records cannot: navigation
   friction, ignored instructions, and tool overhead inside a session.

## Alternatives considered

- **Run the retrospective automatically after every merge by default.** It would surface
  improvements sooner, but it spends tokens on every PR in every repository, and most single
  PRs show nothing worth changing. Opt-in keeps the cost with the teams that want it.
- **Post retrospective findings on the PR.** Public findings about a team's waits and costs are
  operational data many teams would not want published. Chat-only reporting matches the
  session mode's privacy rule.
- **Fold everything into `timings report`.** One command, but its output and name are about
  time, and mixing cost and review data into it would change what existing callers get.
- **Let the agent read PRs directly with `gh` and no collector.** Simpler to start, but the
  numbers would differ between runs and models. A deterministic collector makes two
  retrospectives over the same PRs agree on the facts.
- **A hosted dashboard.** Useful for trends, but it is a separate product. The collector's JSON
  is the input such a dashboard would need, so this leaves the door open.

## Consequences

- New `shaka pr-record report` command, sharing PR search with `timings report`, with fixtures from real Shaka PR bodies and comments, and
  tests for each section parser and for `UNKNOWN` handling.
- The parsers depend on the description and comment formats the helper renders. A format change
  needs a collector change in the same PR; a test that renders through the helper and parses
  the result keeps them in step.
- retrospective.md extends its PR timings mode to the full record and the after-merge rule; `defaults.yml` and
  docs/settings.md gain `retrospective`; docs/working-with-shaka.md shows the prompts.
- PRs merged before a section existed report it as `UNKNOWN`, so early windows will be thin.
- ADR 0007's eval gate gets real-use data in addition to nightly eval runs.

## Delivery

1. `pr-record report` and its tests. No workflow change.
2. The broader PR retrospective in retrospective.md and the docs.
3. The `retrospective.after_merge` setting.
