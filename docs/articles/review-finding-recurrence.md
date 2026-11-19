# Which review findings repeat, and which could a check catch?

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, on 2026-11-15 and 2026-11-16.
The agent sorted 1,716 fixed or dismissed review defects and risks from one month of Shaka pull
requests (PRs) into kinds. It read the title of every finding it counted and drafted
the text. No
person has rechecked the classification. The
[report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-finding-recurrence.md)
lists the method, every kind, and the
[412 classified findings](https://github.com/shakacode/shaka/blob/main/eval/reports/review-finding-recurrence.json).*

## Conclusions

1. **About a quarter of review findings repeat a kind seen on 3 or more PRs.** 406 of
   1,716 fit 18 recurring kinds, 6 more fit a kind seen on 2 PRs, and 1,304 were not
   classified. Misses push the true share up and repeats push it down, so 24% is the
   observed share.
2. **The kinds that repeat most compare prose with code.** Docs that promise behavior
   the code lacks were raised on 53 PRs and fixed on 47. A test that checks names would catch about 1 in 10
   of them. The rest need someone, or something, to read both.
3. **The best-looking check fell short when mapped.** Git calls that inherit the
   caller's Git setup produced 13 findings on 5 PRs, 7 of them defects, though 2 of those
   defects concerned quoting and file modes rather than missing isolation. A follow-up mapping,
   [#1222](https://github.com/shakacode/shaka/pull/1222), found that a test requiring one
   isolating runner catches at most 3 of the 7 defects and recommends deferring it.
4. **Reviewers still raise risks in areas a check covers.** Where an anchor check and a
   quote loader existed, reviewers raised 4 risks about what those checks read. The
   agent dismissed all 4 after a search showed nothing depended on the edit.
5. **Checks cost review too.** One deterministic scanner drew 38 review findings over the
   7 PRs that built and extended it, before it was removed.
6. **Recommendation: evaluate first.** Trial a report-only coverage check. For the prose
   kinds, which need judgment, try a more prominent instruction with a failure example. Since the study, [#1224](https://github.com/shakacode/shaka/pull/1224)
   shipped a heredoc-prose test, and the Git runner test is deferred.

## Why this ran

Lauren Tan's talk
[All Code Is Slop (Except Mine)](https://www.youtube.com/watch?v=O_zcc6Xl12g) puts lint
rules, types, and tests at the base of a trust pyramid, and prose at the narrow top. Each
time an agent needs correcting, she turns the correction into a check where she can.
pstack's
[encode-lessons-in-structure skill](https://github.com/cursor/plugins/blob/bf0c7cd80a/pstack/skills/principle-encode-lessons-in-structure/SKILL.md)
gives the same advice for lessons code can check. For a lesson that needs judgment, it
says to make the instruction more prominent and add an example of the failure mode.

The [evidence-first review article](evidence-first-review.md) marked this advice
Evaluate first for Shaka, because nobody knew how often findings repeat. Shaka leans the
other way today: `shaka enforcement` reports that 89 of 100 audited workflow rules are
enforced by nothing but the agent.

## Main results

| Kind | PRs raised / with a fix | Findings | Candidate check and cost | Share it would catch | Verdict |
| --- | ---: | ---: | --- | --- | --- |
| Docs or instructions describe behavior the code lacks | 53 / 47 | 71 | Test that names in docs exist; medium | About 1 in 10 | Evaluate first |
| A changed path has no test, or the test passes without the fix | 39 / 25 | 51 | Report-only changed-line coverage; medium | Up to half name an untested path | Evaluate first |
| Unexpected input escapes as a raw Ruby error | 38 / 23 | 45 | Readers that raise a Shaka error; high | Up to 32, with a reader for every input | Evaluate first |
| Prose says code enforces a rule only the agent follows | 19 / 14 | 25 | Enforcement audit over docs; high | Flags candidates only | Defer |
| An older installed helper meets newer settings | 15 / 9 | 19 | Previous release run in CI; medium to high | Most fixed ones | Evaluate first |
| A study's claim does not match its data | 14 / 11 | 43 | Figures computed by a script; per study | About 8 arithmetic errors | Defer |
| Symlinks, case-insensitive disks, or Windows | 14 / 13 | 18 | Windows and case-insensitive CI; CI minutes | Most fixed ones | Evaluate first |
| An unnamed caller might break | 13 / 0 | 14 | Review prompt change, not a check; low | None; all 14 were dismissed | Evaluate a review prompt change |
| A default or packaged prompt kept as a Ruby literal | 10 / 5 | 10 | Heredoc and fallback tests; low | The 5 fixed ones | A heredoc-prose test shipped in [#1224](https://github.com/shakacode/shaka/pull/1224); not checked against #837 and #901 |
| Git subprocess inherits the caller's Git environment | 5 / 5 | 13 | One isolating Git runner; medium | At most 3 of 7 defects, per #1222 | Deferred after [#1222](https://github.com/shakacode/shaka/pull/1222) |
| Changelog rule broken; the rule changed mid-month | 4 / 4 | 4 | CI refusing `CHANGELOG.md` edits; low | 1 of 4 | Defer |

"With a fix" counts PRs where the agent fixed at least one finding of the kind. The
report lists 7 more kinds with their checks and costs.

- 1,716 defects and risks were fixed or dismissed on 323 PRs. The recurring kinds touch
  183 of those PRs.
- 30% of the in-scope findings were dismissed. No risk in the unnamed-caller kind was fixed, partly by definition: fixed "may break" findings that named a cause went to other kinds.
- Hosted claude-review added little: 22 reports listed findings, 21 of them before
  2026-10-19.

## The ideas, tested

### 1. Turn each repeated correction into a check

- **Idea:** a repeated correction is a missing lint rule, type, or test.
- **In Shaka:** review findings are the corrections. When local review runs, an AI reviewer
  reads each commit. Shaka posts each PR's findings in a review record comment, called a ledger,
  where the agent marks each one fixed or dismissed with a reason. A *kind* here is a
  group of findings one check could catch.
- **Result:** repeats exist, but most fall where code cannot judge. The two largest
  prose kinds were fixed on 47 and 14 PRs. Checking them needs a comparison of what a sentence
  means with what the code does.
- **Exceptions:**
  - Git subprocess calls produced 7 defects on 5 PRs, 5 of them about missing isolation, including filters that could
    run during an export ([#962](https://github.com/shakacode/shaka/pull/962)).
  - During the month, `AGENTS.md` said of two rules that no test enforced them: defaults belong in
    `defaults.yml`, and only release PRs edit `CHANGELOG.md`. Defaults or prompts kept in
    Ruby were fixed on 5 PRs. The changelog rule changed during the month, and 1 finding broke the
    current form.
- **Limit:** the catch shares are the agent's judgment from finding titles. No check was
  built.

### 2. Checks replace review

- **Idea:** once a check exists, review has less to look for.
- **In Shaka:** `bin/check-docs-navigation` has checked docs anchors since
  [#616](https://github.com/shakacode/shaka/pull/616). The `enforcement.yml` loader fails
  when a quoted rule leaves the workflow.
- **Result:** reviewers still raised 4 risks that an edit might break an anchor or a
  quote the checks read. The agent dismissed each one after a search or heading slug showed nothing
  depended on the edit. Two of the 3
  anchor findings that were fixed fell outside the check's reach.
- **Limit:** the month holds two days before the anchor check and none before the loader,
  so it cannot show whether the checks reduced defects. The reviewer packet does not list the checks that passed.
  Whether listing them would cut these risks is untested.

### 3. Prose is the weakest layer

- **Idea:** rules written as prose sit at the top of the pyramid, where they hold least.
- **In Shaka:** 89 of 100 audited workflow rules are agent-only.
- **Result:** reviewers read the diff and the PR description, not the agent's session.
  None of the 412 classified findings reports an agent breaking a delivery rule
  mid-task; the unclassified findings were not searched for one. What the classified
  findings do show is prose describing enforcement wrongly:
  - 14 PRs fixed prose that called an agent-only rule enforced.
  - 3 PRs fixed `enforcement.yml` drift from the workflow.
- **Limit:** this data cannot say how often agents break the 89 rules.

### 4. A check is cheap to keep

- **Idea:** deterministic checks cost less than repeated review.
- **Result:** not always. The seam upgrade reference scanner was 1,832 lines of Ruby that
  parsed Markdown and shell. The 7 PRs that built and extended it drew 38 review
  findings, 33 of them fixed, until [#997](https://github.com/shakacode/shaka/pull/997)
  removed it.
  `enforcement.yml` has about 900 lines and changed in 26 commits over the month.
- **Limit:** one scanner is one example, and these are findings on new code rather than
  upkeep after it landed. Most proposed checks here are much smaller.

## Recommendation

**Evaluate first.** The data supports trying a few small checks, not a general shift
from prose to checks.

| Option | Evidence | Verdict |
| --- | --- | --- |
| Boundary test: every Git subprocess uses one runner that clears `GIT_*`, global config, filters, and hooks | 13 findings, 7 defects, 5 PRs; the test would catch the 4 to 6 where isolation was missing, if it covers `eval/` seed tooling too. 35 library files had a quoted `git` string; spawn sites are uncounted | Deferred: [#1222](https://github.com/shakacode/shaka/pull/1222) found it catches at most 3 of 7 defects, demands isolation the maintainer rejected, and touches 40 files |
| Tests refusing a Ruby fallback for a `defaults.yml` key, and long English string literals in `skills/shaka/lib` | 5 fixed findings: 3 settings fallbacks and 2 prompt texts. The agent dismissed the other 5 and kept them in Ruby | Heredoc part shipped in [#1224](https://github.com/shakacode/shaka/pull/1224); fallback part not built |
| CI step refusing `CHANGELOG.md` edits on non-release PRs | The rule changed mid-month; 1 finding broke its current form | Defer |
| Report-only changed-line coverage | Up to 26 of 51 test findings name an untested path; coverage misses paths unit tests already run | Evaluate on the next 10 PRs |
| Tell reviewers which checks passed, and to name a caller before warning about one | 4 risks in checked areas dismissed after a search or slug showed nothing depended on the edit, and 14 by showing callers unaffected; dismissals were not rechecked | Evaluate: compare dismissals over a week |
| Make the workflow's stale-text instruction more prominent, with one failure example from this data | The rule exists, yet docs that describe missing behavior were fixed on 47 PRs; pstack's skill prescribes this for lessons that need judgment | Evaluate: compare stale-text findings before and after |
| Check every docs claim about enforcement | High upkeep, cannot judge truth | Defer |

## Data and limits

- **Data:** Shaka's published local review ledgers updated 2026-10-15 to 2026-11-16:
  672 ledgers, 3,533 findings on 370 PRs. In scope are defects and risks that were fixed
  or dismissed.
- **Classifier:** one agent, Claude Opus 5.5, read and sorted every counted finding,
  mostly from titles. No second reader checked it.
- **Recall:** a hand check of 150 unmatched findings found 30 that belonged to a counted
  kind. Counts can also run high from repeats of one problem across ledgers. The agent chose the kinds after reading a sample, so 24%
  measures those kinds, not a list fixed in advance.
- **Dismissals:** the agent's own judgment. No dismissed finding was rerun or rechecked.
- **Catch and cost:** estimates, not measurements. No candidate check was built or
  replayed against history.
- **Scope:** one repository, one maintainer, one month, changing review prompts.
  CodeRabbit and other bots were out of scope.

## Rerun it

The [report](https://github.com/shakacode/shaka/blob/main/eval/reports/review-finding-recurrence.md)
gives the parsing rule and kind definitions. The JSON file records the verdict for each of the 412 classified findings. The
search patterns and scripts are not published, so a rerun sorts findings again and will
give different counts. To run the study on your own repository, ask your agent:

```text
$shaka Find which kinds of fixed or dismissed review findings recur across this repository's PRs over the last month, and for each kind name a check that could catch it
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`. Nobody has tried
this prompt yet.
