# What 350 pull requests taught us about AI code review

Shaka records every review it runs, so you can measure whether your reviewers
earn their cost. We measured four weeks of this repository's own pull requests
(PRs), from 2026-09-19 to 2026-10-17. Here is what we found and what we are
changing.

Every PR in this repository goes through up to five AI reviewers:

- **Before the push**, Shaka runs a *local adversarial review*. A fresh Claude
  session and a Codex session each read the change. Neither of them wrote it.
  Every finding goes into a ledger as a `defect`, `risk`, or `nit`, along with
  what happened to it: fixed, dismissed with evidence, or documented.
- **After the push**, GitHub runs a hosted Claude review. The Codex connector and
  CodeRabbit also comment.

The ledger made this study possible. Each PR's published review comment holds the
same structured table, so one script could read all of them.

## Most PR text is agents writing to agents

The 350 PRs (Dependabot excluded) carry about 21.5 million characters of
discussion and 5.9 million of PR descriptions. That is roughly 6.9 million
tokens that any later agent reading a PR must load. A typical PR has 10 posts
and 37,600 characters of discussion.

| Source | Share of discussion |
| --- | ---: |
| Other agent posts: walkthroughs, verification evidence, replies to review threads | ~37% |
| Shaka's published local-review comments | 30% |
| CodeRabbit | 14% |
| Hosted Claude review | 11% |
| Codex connector | 4% |
| Text written by people | ≈ 3% |

The largest single source was Shaka itself. Each review loop opened a new
comment holding every round's full report, including rounds that found nothing.

## Local reviewers: one precise, one thorough

| Reviewer | Runs | Runs with no findings | Estimated cost per run |
| --- | ---: | ---: | ---: |
| Codex | 452 | 86% | ~$0.09 |
| Claude | 422 | 15% | ~$0.25 |

The cost figures are averages from the 33 runs per reviewer that reported cost.

After removing repeats, the ledger holds 792 distinct findings:

| Reported by | Findings | Defects | Nits | Fixed | Dismissed |
| --- | ---: | ---: | ---: | ---: | ---: |
| Claude only | 719 | 43 | 340 | 212 | 158 |
| Codex only | 41 | 37 | 1 | 37 | 1 |
| Both | 27 | 22 | 2 | 25 | 0 |

- **Codex** rarely speaks, and when it does, it is almost always a real defect
  that gets fixed.
- **Claude** finds more that gets fixed: 212 findings against 37. But nearly
  half of what it reports are nits, and about a fifth gets dismissed. Each of
  those still costs the implementing agent a triage step and a ledger entry.

Dropping Claude would lose those 212 fixes. The better move is to make it quieter.

## The hosted review mostly confirms work that was already reviewed

The hosted Claude review ran on every push, with a broad prompt. It was told
to look for "code quality, bugs, security, performance". Since its reports
started declaring a finding count, 95 of 111 runs (86%) found nothing. The
local review had already caught the problems.

Anthropic's current guidance points the other way. Its
[code-review plugin](https://github.com/anthropics/claude-code/blob/main/plugins/code-review/commands/code-review.md)
works like this:

- It flags only high-signal problems: code that won't run, output that is
  definitely wrong, or a quotable project rule.
- It checks each finding again before posting it.
- It keeps an explicit list of what not to flag, ending with "If you are not
  certain an issue is real, do not flag it."

The hosted review is still worth keeping. It is the one reviewer that the
implementing agent cannot run or impersonate.

## What we are changing

1. **Hosted review that knows about Shaka.** A PR that already has a published
   Shaka local review gets a short, high-signal pass. A PR from someone not
   using Shaka gets the full review. This matters for teams where only some
   contributors use Shaka. In review:
   [shakacode/shaka#640](https://github.com/shakacode/shaka/pull/640).
2. **A quieter local Claude reviewer.** Its prompt will omit nits unless asked
   and require a concrete failing case for every risk. We will measure for two
   weeks before changing Shaka's built-in prompt.
3. **Shorter review publications.** A round with no findings will become a
   single line in the published comment instead of a full report.
4. **Fewer overlapping bots.** CodeRabbit produced 14% of the text and a small
   share of the fixes. We will turn off its summaries or remove it.
5. **Measurement you can repeat.** A command that prints these tables for any
   date range, so each change above can be checked against this baseline.

## Run the same study on your repository

Ask your agent:

```text
$shaka Study the review comments on this repository's PRs from the last four
weeks. Compare each reviewer's findings and dispositions with what was fixed,
and recommend changes to the review process.
```

**Limits of these numbers:**

- They come from one repository with one main maintainer.
- Thread outcomes for the hosted bots come from keyword matching on replies.
- Hosted Claude cost is unknown because it runs on a subscription token.
- Four very busy PRs had more than 100 comments, so their counts are partial.
