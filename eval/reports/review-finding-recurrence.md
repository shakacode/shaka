# Recurring review findings: which ones could a check catch?

A reader-facing summary is the [article](../../docs/articles/review-finding-recurrence.md).

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on 2026-11-15 and
2026-11-16 (UTC). The agent downloaded published review comments, sorted findings into
kinds, read the title of every finding it counted, and drafted the text. The study started no paid
model runs. No person has rechecked the classification.*

## Why this ran

- The [evidence-first review article](../../docs/articles/evidence-first-review.md) left
  one question open. Lauren Tan's talk, and pstack's
  [encode-lessons-in-structure skill](https://github.com/cursor/plugins/blob/bf0c7cd80a/pstack/skills/principle-encode-lessons-in-structure/SKILL.md),
  say each repeated correction should become a lint rule, test, or script. The skill
  adds that a lesson needing judgment should get a more prominent instruction with an
  example of the failure mode. The article marked that advice Evaluate first, because nobody knew how often Shaka's review
  findings repeat.
- `shaka enforcement` reports that 89 of 100 audited workflow rules are enforced by
  nothing but the agent. More prose is the default way this repository answers a
  finding.
- The maintainer asked for counts: which kinds of finding come back across PRs, and
  whether code could catch each one.

## Results

- **Data:** 1,716 defects and risks that the agent fixed or dismissed, on 323 PRs, from
  672 local review ledger comments updated from 2026-10-15 to the snapshot on
  2026-11-16 at about 08:10 UTC. A finding counts once per recorded line, not once per
  distinct problem.
- **Recurring share:** 406 recorded findings (24%) fall into 18 kinds that each appear on 3 or
  more PRs. They touch 183 of the 323 PRs.
- **Below the threshold:** 6 more findings form a kind seen on only 2 PRs.
- **Unclassified:** the remaining 1,304 findings have no kind. A hand check of 150 of them
  found 30 (20%) that fit a kind defined before the check. Misses push the true share up;
  repeats and loosely fitting members push it down, so 24% is the observed share, not a bound.
  The sample was drawn before later recall passes, so its rate does not give a share for
  the final pool; the report makes no projection.
- **Mostly one-off in the sample:** 104 of the 150 checked findings fit no kind. They
  concern one change, such as one function's wrong default or one guide's missing step.
- **Biggest kinds compare prose with code.** The largest kind, docs or instructions
  that describe behavior the code lacks, was raised on 53 PRs and fixed on 47. A name-checking test would catch
  about 1 in 10 of them. The rest need someone to read both.
- **A few kinds have a mechanical check worth trying:**
  - Git subprocess environment: 5 PRs, 13 findings, 7 defects. A test that every Git
    call uses one isolating runner would catch the 4 to 6 findings where isolation was
    missing, if it also covers the seed tooling under `eval/`. The rest concern what the
    isolation does.
  - Defaults and prompts kept in Ruby: during the window, AGENTS.md said no test
    enforced this rule. The 5 fixed findings split into 3 settings defaults kept as Ruby
    fallbacks and 2 prompt texts. After the study, [#1224](https://github.com/shakacode/shaka/pull/1224)
    shipped a heredoc-prose test for the prompt part; the fallback part has no check.
  - Untested changed lines: up to 26 of the 51 test findings name an untested path.
    Line coverage misses a path whose lines a unit test already runs.
- **Reviewers still raised risks in areas a check covered.** With the anchor check and
  the `enforcement.yml` loader in place, reviewers raised 4 risks that an edit might
  break an anchor or quote the checks read. The agent dismissed all 4. The deciding
  evidence was a search or heading slug showing nothing depended on the edit; 3 also cite
  the check as context. Counted here are only risks inside what the checks read;
  #844 F6 also cites the check, but its risk reaches pages outside `docs/` and `skills/`. 14 more dismissed risks warned that an unnamed caller might break. The window holds
  only two days before the anchor check and none before the loader, so it cannot show whether the checks cut defects.
- **Checks cost review too.** The seam upgrade reference scanner was a deterministic
  check of 1,832 lines. The 7 PRs that built and extended it drew 38 findings before
  [#997](https://github.com/shakacode/shaka/pull/997) removed it with the old layout.
- **Recommendation: evaluate first.** Trial a report-only coverage check. For the prose
  kinds, try the skill's judgment branch: the workflow already tells agents to search
  for text that still describes old behavior, yet stale or wrong docs were fixed on 47
  PRs. Evaluate a more prominent instruction with one failure example from this data.
  Two follow-ups have since run:
  [#1222](https://github.com/shakacode/shaka/pull/1222) mapped the Git findings and
  recommends deferring the runner test, and
  [#1224](https://github.com/shakacode/shaka/pull/1224) shipped the heredoc-prose test.

## What ran

- **Snapshot:** every issue comment on `shakacode/shaka` updated since
  2026-10-15T00:00Z, downloaded 2026-11-16 at about 08:10 UTC: 3,476 comments. PR
  review comments were downloaded the same way: 2,019.
- **Local review ledgers:** comments with marker `shaka:reply:local-review-loop-`. 773
  match; 672 hold a `Finding details` section; the other 101 had no findings.
- **Findings:** 3,642 `Finding details` lines, all parsed. Merging the same PR, ID,
  class, and title across a PR's ledgers leaves 3,533.

| Class and disposition | Findings |
| --- | ---: |
| Nit, documented | 1,652 |
| Risk, fixed | 669 |
| Defect, fixed | 524 |
| Risk or defect, dismissed | 523 |
| Risk or defect, accepted by the maintainer | 97 |
| Nit, dismissed | 30 |
| Risk or defect, open or waiting on a maintainer decision | 20 |
| Risk, documented | 18 |

- **In scope:** defects and risks, fixed or dismissed: 1,716 findings on 323 PRs. Nits
  are left out because nothing has to change for them.
- **Hosted claude-review:** 889 reports. 21 of the 148 reports up to 2026-10-18 list
  findings, about 35 in all. Only 1 of the 741 later reports does. They carry no
  disposition, so they were read by hand and used only to corroborate kinds.
- **Enforcement audit:** `shaka enforcement` from the installed helper at
  `6a6f876`: 8 rules refused by a command, 2 reported, 1 refused by GitHub, 89 agent-only.

## How findings were sorted

The method was written to the task's notes folder before counting.

1. **Kinds sized to one check.** The seed list came from rules that `AGENTS.md` and
   `.agents/shaka/instructions/review.md` give to review, such as defaults in
   `defaults.yml` and changelog placement. Kinds were added from a development sample
   of 250 titles, sorted by the SHA-1 of `PR:ID`.
2. **Regex for recall, reading for the count.** A broad title pattern per kind found
   candidates. The agent read each candidate and kept it or rejected it. A finding
   belongs to one kind.
3. **Miss estimate.** After the first pass, 150 unmatched findings were drawn by the
   SHA-1 of `other:PR:ID` and read by hand. 30 of them belonged to a counted kind.
   16 more belonged to kinds this check added: seam upgrade scanner gaps, older-helper skew,
   unnamed callers, and a shell command classifier. Those kinds got their own recall
   pass. All 46 sampled hits were added.
4. **PRs are the main count.** One problem can appear in two ledgers of one PR, and
   139 PRs have more than one ledger.
5. **Catch estimates.** For each kind the agent named one concrete check. The agent
   then judged from the title how many members that check would flag without a person
   reading prose.

[`review-finding-recurrence.json`](review-finding-recurrence.json) lists all 412
classified findings with kind, PR, ledger comment ID, finding ID, class, disposition,
title, and the dismissal reason where there is one.

## Recurring kinds

Kinds appear in order of PRs raised on. "With a fix" counts PRs where the agent fixed
at least one finding of the kind; 17 of the 18 kinds have a fix on 3 or more PRs. "Catch" is the agent's estimate of members the named
check would flag mechanically. Cost covers writing the check and keeping it correct.

| Kind | PRs raised / with a fix | Findings | Fixed / dismissed | Defects | Candidate check, and where | Catch | Cost | Verdict |
| --- | ---: | ---: | --- | ---: | --- | --- | --- | --- |
| Docs or instructions describe behavior the code lacks | 53 / 47 | 71 | 64 / 7 | 50 | Test in `bin/validate`: every setting key, `shaka` subcommand and `--flag` named in `docs/` and `skills/shaka/` exists in `defaults.yml` or the CLI parser | About 7 | Medium: code-span parsing over the docs, an allowlist for examples | Evaluate first |
| A changed path has no test, or the test passes without the fix | 39 / 25 | 51 | 31 / 20 | 2 | Report-only changed-line coverage with Ruby's `Coverage` in `bin/run-tests`; mutation testing for the rest | Up to 26 name an untested path, 12 a test that passes without the fix, 8 the host, 5 other; coverage misses paths unit tests already run | Medium for coverage across 8 workers; high for mutation | Evaluate first |
| Unexpected input escapes as a raw Ruby error | 38 / 23 | 45 | 26 / 19 | 9 | Boundary test: `JSON.parse`, YAML loads and external reads in `skills/shaka/lib` go through readers that raise `Shaka::Error` | Up to 32 malformed-input cases; not the 13 ordering cases | High: many readers, each needs a malformed sample | Evaluate first |
| Prose says code enforces a rule only the agent follows | 19 / 14 | 25 | 18 / 7 | 5 | Extend the enforcement audit to `docs/`: a sentence saying Ruby verifies or refuses must cite an `enforcement.yml` entry | Flags candidates; cannot judge them | High: `enforcement.yml` is about 900 lines with 26 commits from 2026-10-15 to 2026-11-15 | Defer |
| An older installed helper meets newer settings or formats | 15 / 9 | 19 | 10 / 9 | 4 | Test that runs the last release's helper against the branch's settings and published formats | Most of the 10 fixed | Medium to high: a pinned old release in CI | Evaluate first |
| A study's claim does not match its data | 14 / 11 | 43 | 34 / 9 | 17 | Figures computed by a committed script and compared with the text | About 8 arithmetic or denominator errors | Per study | Defer |
| Symlinks, case-insensitive disks, odd path characters, or Windows | 14 / 13 | 18 | 15 / 3 | 8 | Run tests on Windows and a case-insensitive disk on every PR; shared symlink fixtures | Most of the 15 fixed | CI minutes; the Windows suite already fails on known gaps, so it cannot flag a new one (#829) | Evaluate first |
| An unnamed caller or reader might break | 13 / 0 | 14 | 0 / 14 | 0 | None. Reviewer instruction: name the caller from a search, or drop the risk | n/a | Low | Evaluate: trial the prompt change, because no dismissal was rechecked |
| Content from the PR branch or a fork treated as trusted | 11 / 7 | 16 | 10 / 6 | 4 | Extend `test/configuration_boundary_test.rb` to refuse checkout-path reads in review, prompt and checkpoint code | About 4 file reads | Medium: that test already changed in 22 commits since 2026-10-15 | Evaluate first |
| A rule restated in a second instruction file | 11 / 10 | 14 | 13 / 1 | 5 | Near-duplicate sentence report in `bin/report-instruction-growth` | Close copies only | Low, report-only | Evaluate first |
| A default or packaged prompt kept as a Ruby literal | 10 / 5 | 10 | 5 / 5 | 10 | Test that settings keys in `defaults.yml` have no Ruby fallback value, plus a test refusing English string literals over about 25 words in `skills/shaka/lib` | The 3 fixed fallbacks and 2 fixed prompt texts. The long-string test would also flag the dismissed #842 guidance string. The other 4 dismissals were constants, an env switch, and a path the agent kept in Ruby | Low | A heredoc-prose test shipped in [#1224](https://github.com/shakacode/shaka/pull/1224); whether it would have caught #837 and #901 was not checked; fallback part not built |
| `enforcement.yml` out of step with the workflow | 8 / 3 | 10 | 5 / 5 | 3 | Loader already checks quotes; add that entry names cited in docs exist | 1 | Low | Defer |
| Seam upgrade reference scanner misses or misfires | 7 / 7 | 38 | 33 / 5 | 23 | None: the scanner was itself the check, removed in #997 | n/a | Was 1,832 lines | Evidence of the review cost of building a check |
| Docs link to a missing anchor | 6 / 3 | 7 | 3 / 4 | 1 | Exists: `bin/check-docs-navigation` since #616 | 2 of the 3 fixed were outside its reach; #1102 is unverified | Already paid | No new check |
| Git subprocess picks up the caller's Git environment or config | 5 / 5 | 13 | 9 / 4 | 7 | Boundary test: every Git spawn in `skills/shaka/lib` and the seed tooling under `eval/` uses one runner that clears `GIT_*`, global config, filters and hooks | 4 to 6 of 13, where isolation was missing; #1131's 4 findings are in `eval/` seed tooling, so a `skills/shaka/lib`-only test reaches about 3; #710 dismissed 2 under the trust model, since filters came from the maintainer's own config | Medium: at `6a6f876`, 35 files under `skills/shaka/lib` had a quoted `git` string and 14 mentioned a `GIT_*` name; spawn sites were not counted | Deferred after [#1222](https://github.com/shakacode/shaka/pull/1222) mapped the findings |
| GitHub list read stops at the first page | 4 / 3 | 4 | 3 / 1 | 3 | Lint list calls to `gh api` for `--paginate` or a limit check | Most | Low to medium; single-page reads need an allowlist | Defer |
| Changelog rule broken | 4 / 4 | 4 | 4 / 0 | 4 | CI step: a non-release PR that changes `CHANGELOG.md` fails | 1 of 4. The rule changed during the window: #1060 and #1062 were asked to add an entry; #1102 edited `CHANGELOG.md` against the later release-only rule; #1089 concerned entry length in the template | Low | Defer: one finding under the current rule |
| Output shows credentials or local paths | 3 / 3 | 4 | 4 / 0 | 0 | Test that printed URLs and paths pass through the redactor | Most | Low to medium | Defer |

A shell command classifier in [#1135](https://github.com/shakacode/shaka/pull/1135) and
[#1196](https://github.com/shakacode/shaka/pull/1196) drew 6 more defects. Two PRs fall
below the threshold.

### Examples

- **Docs describe behavior the code lacks.** "Guide promised a preview waiver that
  handoff cannot accept" ([#860](https://github.com/shakacode/shaka/pull/860)).
  "delivery.md still requires the former walkthrough field contract"
  ([#1186](https://github.com/shakacode/shaka/pull/1186)).
- **Untested path.** "No test reaches the merge command's auto_merge wiring"
  ([#1081](https://github.com/shakacode/shaka/pull/1081)). "Symlink test still passes
  if the symlink guard is removed" ([#1113](https://github.com/shakacode/shaka/pull/1113)).
- **Raw Ruby error.** "A non-object head raised TypeError instead of a Shaka error"
  ([#1122](https://github.com/shakacode/shaka/pull/1122)).
- **Agent-only rule called enforced.** "Called the rewrite rule enforced;
  enforcement.yml records it as agent-enforced"
  ([#1177](https://github.com/shakacode/shaka/pull/1177)).
- **Git environment.** "Export ran checkout filters, so smudge drivers could execute or
  write decrypted or fetched content Claude then reads"
  ([#962](https://github.com/shakacode/shaka/pull/962)). "Inherited Git variables could
  redirect the seed object store" ([#1131](https://github.com/shakacode/shaka/pull/1131)).
- **Prompt in Ruby.** "Packaged agent prompt is embedded in Ruby"
  ([#901](https://github.com/shakacode/shaka/pull/901)).

## What happened where a check already existed

- **Anchors.** `bin/check-docs-navigation` has checked links and anchors in `docs/` and
  `skills/` since [#616](https://github.com/shakacode/shaka/pull/616) on 2026-10-17.
  Later, one risk said a new docs link might target a missing anchor
  ([#825](https://github.com/shakacode/shaka/pull/825)). The agent dismissed it by citing
  the heading slug. Three more dismissed anchor risks fall partly outside the check.
  Two on [#844](https://github.com/shakacode/shaka/pull/844) concerned removed anchors
  that pages outside `docs/` and `skills/` might link to; the agent dismissed them with
  a wider grep. One on [#667](https://github.com/shakacode/shaka/pull/667) concerned a
  file the check does not read. Two of the 3 fixed anchor findings fall outside the check:
  anchors that outside pages link to (#1036), and a heading anchor a setting needed
  (#1089). The third, a missing anchor in an article on #1102, is the case the check
  reports; whether it broke only against a newer `main` was not verified.
- **Enforcement quotes.** The `enforcement.yml` loader fails when a quote leaves the
  workflow. It landed in [#145](https://github.com/shakacode/shaka/pull/145) on
  2026-09-20, before the window. Reviewers raised 3 risks that an edit might break a
  quote ([#801](https://github.com/shakacode/shaka/pull/801),
  [#888](https://github.com/shakacode/shaka/pull/888),
  [#939](https://github.com/shakacode/shaka/pull/939)). The agent dismissed all 3, each
  citing the loader or the validation that loads it. Two more dismissed risks, on
  [#958](https://github.com/shakacode/shaka/pull/958) and
  [#1089](https://github.com/shakacode/shaka/pull/1089), asked for entries the loader
  does not require. The 5 fixed findings concern what entry notes and lists say, which
  the loader does not read.
- **Unnamed callers.** 14 risks on 13 PRs said a change might break a caller or reader
  without naming one. All 14 were dismissed, mostly after a search found none.
- **Reading:** reviewers still raise risks in areas a check covers, and the agent
  spends a triage turn on each. The window holds only two days before the anchor check and
  none before the loader, so this data cannot show whether the checks reduced defects. The review packet does not name
  the checks that passed. Naming them is untested.

## The 89 agent-only rules

- Reviewers read the diff and the PR description. They see a workflow rule only where
  breaking it leaves a trace in the PR. Examples are an empty PR description (4 hosted
  findings in October) or a missing changelog entry.
- None of the 412 classified findings reports an agent breaking a delivery rule during
  its task, such as merging without consent. The 1,304 unclassified findings and the
  nits were not searched for such reports. This data cannot say how often the 89 rules
  are broken.
- Two kinds concern how the docs describe enforcement: prose calling an agent-only rule
  enforced (fixed on 14 PRs, raised on 19), and `enforcement.yml` drift (fixed on 3 PRs,
  raised on 8).

## Limits

- **One classifier.** Claude Opus 5.5 assigned every kind. No second reader checked it.
  Titles were the main input; dismissal reasons were read for some kinds.
- **Raised-on counts are looser than fixed-on counts.** Some dismissed members fit their
  kind loosely, such as #802 F1 and F5 in the prose-enforcement kind. The conclusions use
  fixed-on counts where they say an error occurred.
- **Kinds were chosen after reading.** The agent defined the kinds from a 250-title
  sample, then added kinds the recall check suggested. The 24% measures these chosen
  kinds, not a list fixed in advance, and one kind is a single feature's cluster.
- **Some repeats.** Merging needs the same PR, ID, class, and title. A finding
  renumbered in a later ledger of the same PR counts twice; review found at least 6
  such repeats. PR counts are unaffected.
- **Recall.** The 150-finding check found 20% of unclassified findings in a counted
  kind. Counts can be too low from misses or too high from repeats and loose members.
- **Dismissals are the agent's own judgment.** No dismissed finding was rerun or
  rechecked, unlike the [review signal study](review-signal.md). The prompt change for
  unnamed callers could hide a real risk; trial it before adopting it.
- **Catch estimates are judgments from titles.** No candidate check was built or replayed.
- **Hosted review adds little.** Hosted claude-review reported findings on 22 reports,
  21 of them before 2026-10-19. CodeRabbit's 408 inline comments and other bots were
  out of scope.
- **Scope:** one repository, one maintainer, one month. Review prompts changed during
  the window. Several kinds follow one project, such as the seam upgrade scanner.
- **Cost estimates** are the agent's reading of similar checks in this repository, not
  measured effort.

## Rerun it

- Download the repository's issue comments updated in the window. Keep main comments
  whose marker starts with `shaka:reply:local-review-loop-` and that contain
  `### Finding details`.
- Parse each line of the form ``- `F<n>` <class>: <title> — <disposition> · Reported
  by: …``. Merge the same PR, ID, class, and title, keeping the newest comment.
- Keep defects and risks with disposition fixed or dismissed.
- The JSON file is the record of this study. It gives the kind of every counted finding
  and, for dismissed ones, the agent's reason cut to 400 characters.
- The per-kind title patterns, the scripts, and the comment snapshot are not published.
  A rerun sorts findings by hand into the kinds above and should expect different counts.
- Ledger comments can change after the snapshot was taken.
