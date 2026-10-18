# AI review on 350 Shaka PRs: an AI-generated study

*This report was written by an AI agent: Claude Code running Claude Opus 5.5, on
2026-10-17. The maintainer asked it to study the review comments on this
repository's pull requests (PRs) and to compare them with current guidance for
Claude code review. The agent collected the data, wrote the scripts, and drafted
this text. Corrections came from Shaka's own review loop: Codex and a fresh
Claude session reviewed the draft before it was published.*

## Data and limits

The study covers the 368 PRs opened in shakacode/shaka from 2026-09-19 to
2026-10-17. It excludes Dependabot PRs, which leaves 350.

- The agent read each PR's comments, reviews, and review threads through GitHub's
  GraphQL API, up to 100 items per list. PRs #268, #269, #284, and #286 have more,
  so their counts are partial.
- Local review data comes from the review comment Shaka publishes on each PR. It
  holds a table of reviewer runs and a list of findings, each classed as a
  `defect`, `risk`, or `nit`. Findings are counted once per PR, class, and title.
- "Fixed" and "dismissed" are the dispositions the implementing agent recorded.
  Nobody checked separately whether each finding was real.
- Outcomes of hosted bot threads come from keywords in the replies, so they are
  approximate.
- The hosted Claude review runs on a subscription token, so its cost is unknown.
  Anthropic's published figure of $15 to $25 per review applies to its managed
  Code Review product, which this repository does not use.

## Who writes the text in a PR

The 350 PRs hold about 21.5 million characters of discussion and 5.9 million of
descriptions. That is roughly 6.9 million tokens. How often agents read all of it
was not measured. The median PR has 10 posts and 37,600 characters of discussion;
at the 90th percentile it has 44 posts and 139,000 characters.

| Source | Posts | Characters | Share of discussion |
| --- | ---: | ---: | ---: |
| Shaka's published local-review comments | 477 | 6.36M | 30% |
| Other agent posts: walkthroughs, evidence, thread replies | ~3,300 | ~8M | ~37% |
| CodeRabbit | 638 | 3.10M | 14% |
| Hosted Claude review | 1,728 | 2.45M | 11% |
| Codex connector | 1,177 | 0.85M | 4% |
| People | n/a | ≈ 0.6M | ≈ 3% |

Agents wrote almost all of it. The largest single source was Shaka itself. Each
review loop opened a new comment, and that comment kept every round's full report,
including rounds that found nothing.

## The hosted Claude review

The workflow is `.github/workflows/claude-code-review.yml`. It ran on every push
and posted a new report each time: 1,000 reports on 343 PRs, a median of 2 per PR
and as many as 32. Its prompt was the generic example from Anthropic's action,
asking about code quality, bugs, security, and performance. It had no list of
things to skip and no severity scale.

On 2026-10-14 the reports began ending with a line that states their finding
count. Of the 111 runs since then, 95 (86%) found nothing. A report with no
findings had a median length of 658 characters. These PRs had already been
through local review, which is a likely reason; the study did not measure it.

Claude's 728 inline comments drew a fix-style reply about half the time. About a
quarter were declined, and 9% got no reply.

## The local adversarial review

Before a push, Shaka asks reviewers that did not write the change to read it.
This repository uses two, Codex and Claude, on each commit. The ledger covers 147
PRs, 374 review loops, and 884 reviewer runs.

| Reviewer | Runs | Runs with no findings | Estimated cost per run |
| --- | ---: | ---: | ---: |
| Codex | 452 | 86% | ~$0.09 |
| Claude | 422 | 15% | ~$0.25 |
| DeepSeek (optional trial) | 10 | 30% | unknown |

Only 33 Codex and 33 Claude runs recorded a cost, so the cost column is a small sample.
The ledger holds 792 distinct findings:

| Reported by | Findings | Defects | Risks | Nits | Recorded fixed | Recorded dismissed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Claude only | 719 | 43 | 336 | 340 | 212 | 158 |
| Codex only | 41 | 37 | 3 | 1 | 37 | 1 |
| Both | 27 | 22 | 3 | 2 | 25 | 0 |
| DeepSeek (optional trial) | 5 | 0 | 3 | 2 | 0 | 2 |

Codex reports little, and nearly everything it reports is a defect that gets
fixed. Claude has far more findings recorded as fixed, 212 against Codex's 37.
Nearly half of Claude's findings are nits, though, and about a fifth were
dismissed. The implementing agent has to triage and record each one.

## Current guidance from Anthropic

These sources were checked on 2026-10-17.

- Anthropic's [code-review plugin](https://github.com/anthropics/claude-code/blob/main/plugins/code-review/commands/code-review.md)
  reports only high-signal issues: code that will not compile or parse, output
  that is definitely wrong, or a break from a project rule it can quote. Another
  agent checks each issue, and the plugin drops any that fail. It also lists what
  to skip: pre-existing issues, anything a linter catches, general quality and
  test coverage, problems that depend on particular inputs, and subjective nits.
  Its instruction is "If you are not certain an issue is real, do not flag it."
- Anthropic's own repository runs the review
  [only when a PR opens](https://github.com/anthropics/claude-code-action/blob/main/.github/workflows/claude-review.yml),
  and skips PRs from forks. The plugin stops if Claude has already commented.
- The managed product
  [re-reviews only what changed](https://code.claude.com/docs/en/code-review-pull-requests)
  since its last review, and posts fewer nits when it does. Its `REVIEW.md` file
  can cap nits and skip paths, but the GitHub Action does not read that file.
- The action's `use_sticky_comment` option keeps one comment per PR. Here it
  would break the check this repository added in #507, which looks for a new
  report during each run.
- Anthropic [reports](https://claude.com/blog/code-review) that engineers marked
  fewer than 1% of the managed product's findings as incorrect. It has published
  no comparable number for the action.

## Findings and proposals

1. The local Claude reviewer reports many nits and weak risks, but it also
   accounts for most of the recorded fixes. Of its 719 findings, 340 were nits
   and 158 were dismissed. The proposal is to change this repository's prompt,
   `.agents/shaka/review-prompt.md`, before Shaka's built-in one. It would copy
   the plugin's list of things to skip, leave out nits unless asked, and require
   a concrete failing case for every risk. A two-week measurement would follow.
   Changing only the nit rule leaves the 174 fixed Claude risks alone. Tightening
   the risk rule could lose some of them.
2. The hosted Claude review finds little after local review, and its prompt goes
   against Anthropic's guidance. The proposal is a high-signal prompt that refers
   to the review rules in `AGENTS.md`. Running it less often needs a code change
   first. Shaka's merge watcher (`skills/shaka/lib/shaka/pr_watch/review_gate.rb`)
   waits for a `claude-review` result on the current commit, so a skipped run
   would leave it waiting. The hosted review is worth keeping in some form,
   because it is the one Claude review that runs on GitHub, outside the session
   that wrote the code.
   [shakacode/shaka#640](https://github.com/shakacode/shaka/pull/640) takes this
   up. A PR that already has a published Shaka local review gets the short pass;
   a PR from someone not using Shaka gets the full review.
3. Shaka's own review comments are the largest single source of text, at 6.36
   million characters. Shortening a round with no findings to one line would cut
   roughly half of that, by estimate. The full reports would then need a durable
   home outside GitHub. Separately, 96 of the 97 review comments published since
   2026-10-15 lack the `🤖` writer line in their first four lines. Shaka requires
   that line on AI-written posts, so the publishing code should be checked.
4. Three hosted bots overlap. CodeRabbit produced 3.1 million characters, and
   about 52 of its 116 inline threads drew a fix-style reply. For the Codex
   connector it was about 490 of 616. Turning off CodeRabbit's summaries in its
   repository configuration would remove most of its text.
5. Shaka's retrospective procedure could not run this study. It analyzes only the
   coding sessions a user names, and it does not read repository history. A
   command that prints these tables for any date range, from the published review
   comments, would let each change above be measured against this baseline.

## Run the same study on your repository

Ask your agent:

```text
$shaka Study the review comments on this repository's PRs from the last four
weeks. Compare each reviewer's findings and dispositions with what was fixed,
and recommend changes to the review process.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
