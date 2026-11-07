# Local review signal on React on Rails: does the pattern hold in a second repository?

A reader-facing summary is the
[article's second-repository section](../../docs/articles/review-signal-study.md#a-second-repository-react-on-rails).
The first study is the [Shaka report](review-signal.md).

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on 2026-11-06 (UTC).
The agent read review data published on
[shakacode/react_on_rails](https://github.com/shakacode/react_on_rails), read each sampled
fix against its finding, and drafted the text. The study started no paid model runs and
ran no React on Rails code.*

## Conclusions

1. **The fixes were real here too.** All 30 sampled fixed defects read as real problems,
   and 3 need an input unlikely in practice. These are readings: no React on Rails test
   ran.
2. **Each real defect cost 2.4 times as much as on Shaka.** Reviewer spend was $5.72 per
   fixed defect against $2.38. Codex reported nothing on 84% of its runs, and Claude
   reported 316 of the 318 nits.
3. **Extra reviewers still found bugs after two had signed off, but most of what they
   said was declined.** On 10 of the 38 PRs that drew outside comments on a cleared
   commit, those comments led to 17 fixes, one a user-facing redirect bug. The agent
   declined 49 of the 89 threads.
4. **Later rounds mostly chased earlier fixes.** At least 9 of the 14 sampled findings
   from cycle 2 or later sat in code an earlier fix had rewritten. One URL-redaction
   routine produced 4 of the 30 sampled defects.
5. **This data cannot compare review with run-based checks or with a human reviewer.**
   No test ran, and every maintainer comment in the data was written by an agent.

## Why this ran

- The [Shaka study](review-signal.md) found that all 40 sampled fixes from Shaka's local
  review loop were real. That repository reviews Shaka's own workflow code, which Shaka's
  reviewers may suit unusually well.
- React on Rails is a public Ruby gem and set of npm packages with outside users. Since
  2026-10-15 its PRs have gone through the same loop: Codex and Claude review each commit
  before the push.
- Its pushed PRs then get a second layer: four AI reviewers on GitHub (Claude in CI,
  CodeRabbit, the Codex connector, and Greptile), plus GitHub code scanning. That layer lets
  this study ask something the Shaka data could not: after both local reviewers sign off,
  do more reviewers still find problems worth fixing?

## What ran

- **Snapshot:** every issue comment on `shakacode/react_on_rails` updated since
  2026-08-01, downloaded 2026-11-06: 4,647 comments. 135 are main comments in the ledger
  format (marker `local-review-loop-`), first published 2026-10-15 and last updated
  2026-11-06.
- **Population:** those 135 ledger comments cover 90 PRs (83 opened by Justin Gordon, 7 by
  Abanoub Ghadban), 506 reviewer runs on 267 reviewed commits, and 563 findings on 79 PRs.
  128 comments carry an execution table. One table row in another layout was not parsed.
- **Findings:** deduplicated by PR, finding ID, class, and title, keeping the newest
  comment, as in the Shaka study.
- **Outside reviews:** the inline review comments and replies on the same 90 PRs.
- **Terms:** a *cycle* is one reviewed commit. A *run* is one reviewer on one commit.

| Class and disposition | Findings |
| --- | ---: |
| Defect, fixed | 43 |
| Risk, fixed | 83 |
| Nit, documented or dismissed | 318 |
| Risk or defect, dismissed | 95 |
| Risk or defect, accepted by the maintainer | 10 |
| Risk, documented | 10 |
| Risk, open | 4 |

### Sample

The Shaka study's rule, applied unchanged: class `defect`, disposition `fixed`, with a fix
commit; three strata by reporter (Codex only, Claude only, both); within each, sort by the
SHA-1 of `PR:ID:TITLE` and take the first 10. That gives 30 of the 43 fixed defects.
Fixed risks were not sampled.

Each finding was checked by reading:

1. The finding's title and recorded disposition in its ledger comment.
2. The fix commit's message, files, and diff.
3. For #29 and #30, the code at the reviewed commit and at the base, read through the
   GitHub API.

Running each fix's test on the reviewed commit, the Shaka study's strongest check, was
attempted. The agent's host refused to run code from another repository, so no finding
here was confirmed by a run.

## Results

- All 30 read as real problems that the fix addressed. Two were checked against the
  reviewed code itself (#29 and #30); the other 28 rest on the finding and fix diff.
- Three need a trigger unlikely in practice: a cache tag holding a lone UTF-16 surrogate
  (#1), a Git push URL that names a different repository from the fetch URL (#2), and a
  literal at sign right after encoded slashes, as in `%2F%2F@ab` (#30).
- 27 sat in code or text the PR added. 2 were drift, where unchanged base docs became
  wrong because of the PR: #14 and #18. One was base code: in #29 the faulty line was
  already on `main`, and only the PR's new Turbo Frame path reached it.
- 23 fixes changed code and added or changed a test, 2 changed only a test, and 5 changed
  only prose.
- Fixes chain here too. At least 9 of the 14 findings last recorded in cycle 2 or later
  sat in code an earlier fix had rewritten. The Shaka study counted findings first reported
  in cycle 2 or later, which this data cannot give for most of the sample, so the two
  figures are not comparable: #2, #8, #13, #15, #16, #22, #24, #26, and #30.
  #22's commit says the previous round's fix was wrong, and #24's says a commit hook's
  autofix undid the earlier fix.
- Two PRs hold 9 of the 30. Five sampled Codex-only defects come from
  [#5262](https://github.com/shakacode/react_on_rails/pull/5262), a new fleet-upgrade
  script. Four come from one URL-redaction routine in
  [#5218](https://github.com/shakacode/react_on_rails/pull/5218), where each fix exposed
  the next edge case. The Shaka study saw the same pattern on one path check.

### Fixed defects

| # | PR | Finding | Reporter | Cycle | Real | Origin | Fix |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | [#5122](https://github.com/shakacode/react_on_rails/pull/5122#issuecomment-6259035289) | F1: Malformed UTF-16 tags collide after Redis UTF-8 encoding | Codex | 1 of 3 | yes, unlikely trigger | new | code + test |
| 2 | [#5262](https://github.com/shakacode/react_on_rails/pull/5262#issuecomment-6486345494) | F6: Origin validation does not check the push destination | Codex | 4 of 7 | yes, unlikely trigger | new | code + test |
| 3 | [#5313](https://github.com/shakacode/react_on_rails/pull/5313#issuecomment-6654147032) | F1: Fallback-flavor test setup throws on Node 18, where `vm.constants` is missing | Codex | 1 of 5 | yes | new | test |
| 4 | [#5262](https://github.com/shakacode/react_on_rails/pull/5262#issuecomment-6486345494) | F3: PR creation fails when no JavaScript lockfile exists | Codex | 1 of 7 | yes | new | code + test |
| 5 | [#5262](https://github.com/shakacode/react_on_rails/pull/5262#issuecomment-6486345494) | F8: Reused PRs keep stale validation evidence in the PR body | Codex | 6 of 7 | yes | new | code + test |
| 6 | [#5262](https://github.com/shakacode/react_on_rails/pull/5262#issuecomment-6486345494) | F4: Only the first JS project's lockfile is regenerated and smoke-installed | Codex | 2 of 7 | yes | new | code + test |
| 7 | [#5262](https://github.com/shakacode/react_on_rails/pull/5262#issuecomment-6486345494) | F1: Pin application reads the operator's checkout instead of the worktree | Codex | 1 of 7 | yes | new | code + test |
| 8 | [#5235](https://github.com/shakacode/react_on_rails/pull/5235#issuecomment-6333892272) | A4: Encoded double slashes inside a URL path started an authority and redacted the whole URL | Codex | 3 of 7 | yes | new | code + test |
| 9 | [#5326](https://github.com/shakacode/react_on_rails/pull/5326#issuecomment-6680750971) | F9: Removing the last hosted-CI label with `+ci-stop-full` leaves a stale passing gate | Codex | 4 of 7 | yes | new | code + test |
| 10 | [#5247](https://github.com/shakacode/react_on_rails/pull/5247#issuecomment-6435380395) | D1: npm aliases hide vulnerable `react-server-dom-webpack` copies | Codex | 1 of 4 | yes | new | code + test |
| 11 | [#5327](https://github.com/shakacode/react_on_rails/pull/5327#issuecomment-6676898748) | F1: Date check aborts a recovery retry whose release tag already exists | Claude | 1 of 4 | yes | new | code + test |
| 12 | [#5326](https://github.com/shakacode/react_on_rails/pull/5326#issuecomment-6680750971) | F1: The workflow token can remove hosted-CI labels without an event, so a skip keeps a stale pass | Claude | 1 of 7 | yes | new | code + test |
| 13 | [#5255](https://github.com/shakacode/react_on_rails/pull/5255#issuecomment-6468713093) | F1: Round-1 fix incomplete: an output assertion still could not fail | Claude | 2 of 3 | yes | new | test |
| 14 | [#5228](https://github.com/shakacode/react_on_rails/pull/5228#issuecomment-6313155477) | F1: AGENTS.md still says the old doctor lives under `.agents/fixtures/` | Claude | 1 of 3 | yes | drift | prose |
| 15 | [#5218](https://github.com/shakacode/react_on_rails/pull/5218#issuecomment-6265865054) | F8: A space between two paths was read as an authority and deleted path text | Claude | 3 of 5 | yes | new | code + test |
| 16 | [#5218](https://github.com/shakacode/react_on_rails/pull/5218#issuecomment-6265865054) | F6: A line break between two paths was read as an authority and deleted path text | Claude | 2 of 5 | yes | new | code + test |
| 17 | [#5122](https://github.com/shakacode/react_on_rails/pull/5122#issuecomment-6259035289) | F7: Tiered invalidation is declared required but can be absent at runtime | Claude | 2 of 3 | yes | new | code + type test |
| 18 | [#5263](https://github.com/shakacode/react_on_rails/pull/5263#issuecomment-6486826424) | F5: AGENTS.md tracking-issue rules still rely on heartbeats and leases | Claude | 3 of 5 | yes | drift | prose |
| 19 | [#5218](https://github.com/shakacode/react_on_rails/pull/5218#issuecomment-6265865054) | F1: An encoded escape before a path's at sign deleted the host and path of a literal URL | Claude | 1 of 5 | yes | new | code + test |
| 20 | [#5321](https://github.com/shakacode/react_on_rails/pull/5321#issuecomment-6656656302) | F1: Changelog entry tagged [Pro] also fixes the open-source packages | Claude | 1 of 3 | yes | new | prose |
| 21 | [#5235](https://github.com/shakacode/react_on_rails/pull/5235#issuecomment-6333892272) | A1: Any `%2F` plus any at sign after any `//` redacted legitimate URLs | both | 1 of 7 | yes | new | code + test |
| 22 | [#5317](https://github.com/shakacode/react_on_rails/pull/5317#issuecomment-6655499050) | G1: Unparseable `engines.node` ranges were ignored, but npm rejects them | both | 2 of 4 | yes | new | code + test |
| 23 | [#5196](https://github.com/shakacode/react_on_rails/pull/5196#issuecomment-6223976379) | F1: Pinned CI validator rejects `local_review_count` | both | 1 of 4 | yes | new | CI config + test |
| 24 | [#5133](https://github.com/shakacode/react_on_rails/pull/5133#issuecomment-6256875305) | F10: An undefined or other falsy isolation option still disables store isolation | both | 4 of 5 | yes | new | code + test |
| 25 | [#5329](https://github.com/shakacode/react_on_rails/pull/5329#issuecomment-6677453686) | F1: New URLs re-read as plain text drop trailing punctuation | both | 1 of 4 | yes | new | code + test |
| 26 | [#5247](https://github.com/shakacode/react_on_rails/pull/5247#issuecomment-6435380395) | D7: npm v1 alias copies still hidden | both | 2 of 4 | yes | new | code + test |
| 27 | [#5317](https://github.com/shakacode/react_on_rails/pull/5317#issuecomment-6675215353) | K1: Changelog entry lacks the Action required for upgraders tag | both | 1 of 3 | yes | new | prose |
| 28 | [#5270](https://github.com/shakacode/react_on_rails/pull/5270#issuecomment-6490208954) | F2: CHANGELOG omits changed private helper signatures | both | 1 of 5 | yes | new | prose |
| 29 | [#5227](https://github.com/shakacode/react_on_rails/pull/5227#issuecomment-6284634026) | F1: A renderer waiting on a store is reused by same-id frame content and renders old props | both | 1 of 2 | yes | base, reached by the PR's new path | code + test |
| 30 | [#5218](https://github.com/shakacode/react_on_rails/pull/5218#issuecomment-6265865054) | F10: The backward search for a decoded at sign looped forever on an at sign at offset 0 or 1 | both | 4 of 5 | yes, unlikely trigger | new | code + test |

Cycle is the reviewed commit, within its ledger, where the finding was last recorded. Each
PR link goes to the ledger comment the finding came from.

### Two findings checked against the code

- **#29, consequential.** At reviewed commit `710a593`, `isRenderingDomNode` treats a
  renderer whose `domNode` is still undefined as matching any node. A renderer waiting on a
  store dependency has no node yet, so when a Turbo Frame inserts new content with the
  same DOM id, the old renderer is reused and mounts the old props into the new node. The
  same line is on the base, `fce73db`. The PR added the frame path that reaches it. Fix
  `8204e87` records the node that held the id when the renderer was created.
- **#30, unlikely trigger.** At reviewed commit `f7666c0`, `token_bounds` searches
  backward with `index -= 1 while (index = token.rindex("@", index - 1)) && literal[...]`.
  When the at sign sits at offset 0, the next start is negative, which `rindex` counts from
  the end, so the loop never ends. Fix `ad73697` stops at offset 0. The trigger is a token
  such as `%2F%2F@ab` in text the sanitizer reads.

## The second layer: reviews after the local loop signed off

For each ledger that ended "No open findings", the last reviewed commit is the one both
local reviewers passed. GitHub records the commit each inline review comment was made on,
so the comments on exactly that commit are findings on code the local loop cleared.

71 of the 89 threads, and 22 of the 26 that led to a fix, were posted after the ledger
comment's last update, so they followed the local sign-off. The other 18 were posted
while that ledger comment was still changing. The workflow pushes only after local
review, but the timestamps alone cannot order those 18.

- 119 of the 128 ledger comments with an execution table ended with no open findings, on
  84 PRs. The 7 comments without a table are left out of cycle, cost, and sign-off counts.
- On 38 of those PRs, outside reviewers left 89 inline threads on the cleared commit.
- Each thread was read with the agent's reply and labeled by hand:

| Outcome | Threads |
| --- | ---: |
| Fixed on the PR | 21 (17 distinct problems) |
| Fixed in another PR | 5 |
| Declined with a reason | 49 |
| Requested checks run, no code change | 2 |
| No reply | 12 |

| Reviewer | Fixed on the PR | Fixed elsewhere | Declined | Checks run | No reply |
| --- | ---: | ---: | ---: | ---: | ---: |
| Claude in CI | 6 | 0 | 18 | 0 | 5 |
| Codex connector | 4 | 2 | 9 | 0 | 3 |
| Greptile | 4 | 1 | 5 | 0 | 0 |
| CodeRabbit | 3 distinct (7 threads) | 2 | 16 | 2 | 2 |
| GitHub code scanning and code quality | 0 | 0 | 1 | 0 | 2 |

- 10 PRs got at least one fix from this layer.
  [#5262](https://github.com/shakacode/react_on_rails/pull/5262) drew 6 of the 17 problems.
- The fixes include user-facing bugs. On
  [#5139](https://github.com/shakacode/react_on_rails/pull/5139#discussion_r4289498346),
  the Codex connector found that TanStack Router versions the declared peer range allowed
  had removed the API the code read, so redirects fell back to status 200. The fix narrowed
  the peer range to versions that still have it. On [#5193](https://github.com/shakacode/react_on_rails/pull/5193), two
  findings arrived after merge and were fixed in
  [#5194](https://github.com/shakacode/react_on_rails/pull/5194).
- Others are small: a wrong PR number in a changelog entry, a duplicated helper, a
  clarified comment.
- The agent declined 49 of the 89 threads (55%); 48 of the 86 from the four AI reviewers. Most replies cite behavior that predates
  the PR, a disproof with a command or a source read, or a cost the agent judged too high.
- 12 threads got no reply. They include two P1 findings on the backport
  [#5283](https://github.com/shakacode/react_on_rails/pull/5283), whose source PR #5252
  disproved the same concern, and a security note on
  [#5275](https://github.com/shakacode/react_on_rails/pull/5275). This study did not check
  the unanswered threads.

## Cycles, empty runs, and cost

| Measure | React on Rails | Shaka |
| --- | ---: | ---: |
| Ledgers with an execution table | 128 of 135 | 500 |
| Cycles per ledger, median / 90th percentile / max | 1 / 5 / 7 | 2 / 5 / 12 |
| Runs that reported nothing | 258 of 506 (51%) | 1,242 of 2,574 (48%) |
| Codex runs that reported nothing | 210 of 249 (84%) | 1,009 of 1,310 (77%) |
| Claude runs that reported nothing | 48 of 257 (19%) | 231 of 1,262 (18%) |
| Cycles with no finding from any reviewer | 58 of 267 (22%) | 242 of 1,282 (19%) |
| Fixed defects first reported in cycle 1 | 14 of 28 known (50%) | 159 of 274 known (58%) |
| Fixed defects: Codex only / Claude only / both | 19 / 13 / 11 | 154 / 113 / 78 |
| Fixed risks: Codex only / Claude only / both | 3 / 75 / 5 | not split |
| Nits, share of findings | 318 of 563 (56%) | 1,221 of 2,486 (49%) |
| Defects and risks dismissed | 95 (17%) | 362 (15%) |
| Findings marked "returned after its fix" | 9 | 41 |
| Reviewer spend per fixed defect | $5.72 | $2.38 |
| Reviewer spend per fixed defect or risk | $2.05 | $1.00 |
| Mean cost per run, Codex / Claude | $0.18 / $0.86 | $0.11 / $0.53 |
| Share of spend after cycle 1 | 59% | 67% |

- Spend per fixed defect uses the 99 ledgers with a cost on every run: $223.06 over 39
  fixed defects and 70 fixed risks. 65 runs have no cost estimate.
- Claude reported 316 of the 318 nits. It reported 80 of the 83 fixed risks, 75 of them alone. Codex reported more
  of the fixed defects alone than Claude did, but returned nothing on 84% of its runs.
- Outside reviewers' costs are not in these numbers. Their subscriptions are not priced
  per review.

## Comparison with the Shaka study

| Question | Shaka | React on Rails |
| --- | --- | --- |
| Are fixed defects real? | 30 of 30 sampled, 16 confirmed by a run; 10 of 10 risks | 30 of 30 sampled, all by reading; 2 checked against the code |
| Unlikely triggers among sampled defects | 4 of 30 | 3 of 30 |
| Already in the base | 0 of 40; 1 drift | 1 of 30, reached only through the PR's new path; 2 drift |
| Does each reviewer catch defects the other missed? | Yes: 154 Codex only, 113 Claude only | Yes: 19 Codex only, 13 Claude only |
| Do more reviewers after a clean loop find more? | Not measured | 17 problems fixed on 10 of 38 PRs; 55% of their threads declined |

Later-cycle findings are left out of this table: the Shaka study counted the cycle that
first reported each finding, and this one could read that cycle for only 8 of its 14
later-cycle findings.

## What this does and does not show

- Every check here is a reading. The 28 that rest on the finding and fix diff trust that
  the fix commit describes the problem truthfully. The run checks that made the Shaka
  study stronger could not run on this host.
- One agent, Claude Opus 5.5, judged every finding and every outside thread. It shares a
  model family with one local reviewer and with Claude in CI.
- The sample holds only findings an agent chose to fix. The 318 nits, 95 dismissed defects
  and risks, and 83 fixed risks were not checked.
- Outside threads were matched to the cleared commit by the commit GitHub records for each
  inline comment. 18 of the 89 cannot be ordered after the local sign-off by timestamp. Summary comments from the same bots were not counted, so the outside
  layer's totals are a floor.
- Whether the declined outside threads were right to decline was not judged, except where
  a reply shows a disproof.
- Both maintainers' accounts in this data post agent-written replies and walkthroughs. No
  independent human code review appears, so this data cannot compare AI review with human
  review.
- One organization, one review configuration, three weeks. The same maintainer set up both
  repositories.

## Rerun it

- Download the repository's issue comments and keep main comments whose marker starts with
  `local-review-loop-`. Parse `Finding details` and `Execution metadata` as the
  [Shaka report](review-signal.md#rerun-it) describes; this repository also has an older
  execution-table layout with no cost column.
- Draw the sample with the rule above. The tables list each sampled finding with its source
  comment, so each reading can be repeated.
- For the second layer, list each PR's inline review comments, keep roots from outside
  reviewers whose `original_commit_id` is the last reviewed commit of a ledger that ended
  with no open findings, and read the agent's reply in each thread.
- To add run checks, check out the reviewed commit, copy in the fix's test files, and run
  them there and at the fix.
