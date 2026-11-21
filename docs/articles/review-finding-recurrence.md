# Which review findings repeat, and which could a check catch?

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, from 2026-11-15 to
2026-11-20. It summarizes a study of one month of Shaka's local review findings. Every
number below comes from the
[report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-finding-recurrence.md),
which gives the method, the per-kind tables, and the limits. No person has rechecked the
classification.*

## Conclusions

1. **About a quarter of findings fit a repeating kind.** Of 1,716 fixed or dismissed
   defects and risks, the agent assigned 406 (24%) to 18 kinds that each appear on 3 or
   more PRs. That share is what one reader observed, not a bound: missed findings push
   it up, and repeated or loosely fitting ones push it down.
2. **The largest kind needs judgment, not a lint rule.** Docs or instructions that
   describe behavior the code lacks were raised on 53 PRs and fixed on 47. A test that
   checks names would catch about 1 in 10 of them.
3. **The most promising check fell short once mapped.** A follow-up,
   [#1222](https://github.com/shakacode/shaka/pull/1222), found that a single isolating
   Git runner would catch none of the 7 Git defects as a literal check, and 3 to 5 with
   broader detection. It recommends deferring it for cost and trust reasons. Another
   follow-up, [#1224](https://github.com/shakacode/shaka/pull/1224), shipped a test that
   refuses long heredoc prose in Ruby.
4. **Reviewers still raise risks in areas a check covers.** Four such risks were
   dismissed after a search, a heading slug, or a loader run showed nothing depended on
   the edit.
5. **Checks draw review too.** One deterministic scanner drew 38 findings over the 7 PRs
   that built and extended it before it was removed.

## Why this ran

Lauren Tan's talk
[All Code Is Slop (Except Mine)](https://www.youtube.com/watch?v=O_zcc6Xl12g) and pstack's
[encode-lessons-in-structure skill](https://github.com/cursor/plugins/blob/bf0c7cd80a/pstack/skills/principle-encode-lessons-in-structure/SKILL.md)
say to turn each repeated correction into a lint rule, test, or script. The skill adds
that a lesson needing judgment should get a more prominent instruction with an example of
the failure. The [evidence-first review article](evidence-first-review.md) left open how
often Shaka's findings repeat. This study counts them.

## Recommendation

**Evaluate first.** The data supports trying a few small checks, not a general shift from
prose to checks.

- Trial report-only changed-line coverage, since many test findings name an untested
  path.
- For the docs-versus-code kind, follow the skill's judgment branch: make the workflow's
  existing "update text that describes the old behavior" instruction more prominent, with
  one failure example from this data, and compare findings before and after.
- Defer the Git runner check and checks that would audit every docs claim about
  enforcement.

## Limits

- One agent classified findings, mostly from titles, and chose the kinds after reading a
  sample. No second reader checked it.
- Catch and cost estimates are judgments. No candidate check was replayed against history.
- Dismissals are the agent's own judgment and were not rechecked.

## Rerun it

The report's "Rerun it" section gives the collection and parsing steps. The
[JSON file](https://github.com/shakacode/shaka/blob/main/eval/reports/review-finding-recurrence.json)
records the kind and disposition of the 412 classified findings, with ledger comment IDs
for spot checks. The search patterns, scripts, and comment snapshot are not published, so
a rerun sorts findings again and will give different counts.
