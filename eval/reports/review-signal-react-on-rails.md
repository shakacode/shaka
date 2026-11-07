# Local review signal on React on Rails: does the pattern hold in a second repository?

A reader-facing summary is the
[article's second-repository section](../../docs/articles/review-signal-study.md#a-second-repository-react-on-rails).
The first study is the [Shaka report](review-signal.md).

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on 2026-11-06 (UTC).
The agent read review data published on
[shakacode/react_on_rails](https://github.com/shakacode/react_on_rails), read each sampled
fix against its finding, ran each fix's test on its reviewed commit and at the fix in an
isolated checkout, and drafted the text. The study started no paid model runs.*

## Conclusions

1. **The fixes were real here too, and most are proven by a run.** All 30 sampled fixed
   defects were real problems. For 24, a test, or a mutation of the code, failed on the
   reviewed commit and passed at the fix. The other 6 were checked by
   reading: 5 are prose findings, and #9's tests fail on the reviewed commit only because
   its fix changed the mechanism. 3 of the 30 need an input unlikely in practice.
2. **Each fixed defect cost 2.4 times as much as on Shaka, and each fixed defect or risk
   about twice as much.** Reviewer spend was $5.72
   per fixed defect against $2.38, and $2.05 per fixed defect or risk against $1.00.
   Both reviewers' runs cost about 1.6 times as much here, and more fixes are labeled
   risks, so the data cannot say which difference drove the gap. Codex reported nothing on 84% of its runs, and Claude
   reported 316 of the 318 nits.
3. **Extra reviewers still found real problems on commits both local reviewers had passed,
   but the agent declined most of what they said.** Outside comments on such a commit
   reached 31 PRs. On 7 of them they led to 11 problems fixed on the PR and 3 fixed
   elsewhere, one a bug that stopped Turbo Frame components from mounting. 9 of the 12
   threads behind the on-PR fixes are timestamped after the local sign-off. The agent
   declined 40 of the 66 threads.
4. **Later rounds mostly chased earlier fixes.** At least 9 of the 14 sampled findings
   last recorded in cycle 2 or later sat in code an earlier fix had rewritten. URL-redaction code
   that both #5218 and #5235 changed produced 6 of the 30 sampled defects.
5. **This data cannot show what a reviewer required to prove findings by a run would
   find, or compare AI review with a human reviewer.** The reviewers here ran nothing, and
   every maintainer comment in the data was written by an agent.

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

Each finding was checked the same way as in the Shaka study:

1. Read the finding's title and recorded disposition in its ledger comment, and the fix
   commit's message, files, and diff.
2. **Run:** in an isolated checkout of React on Rails, check out the reviewed commit,
   copy in only the fix's test files, and run them; then run the same files at the fix.
   A finding is confirmed when the fix's test fails on the reviewed commit, the failing
   examples are the ones that test the finding's claim, and all pass at the fix.
3. When the fix changed only a test, run the reviewed commit's own test instead, or
   mutate the code to show whether the test can fail.

Ruby and JavaScript dependencies were installed once from `main`, not from each
commit's lockfile. Tests ran on Ruby 3.4.6 and Node 24.8.0, and #3 on Node 18.20.3.

## Results

- All 30 were real problems that the fix addressed. 24 were confirmed by a run, listed
  under [Run evidence](#run-evidence). The other 6 were checked by reading: 5 prose
  findings (#14, #18, #20, #27, #28), and #9, whose fix replaced how the gate reruns, so
  its tests fail on the reviewed commit for a reason other than the finding.
- Three need a trigger unlikely in practice: a cache tag holding a lone UTF-16 surrogate
  (#1), a Git push URL that names a different repository from the fetch URL (#2), and a
  literal at sign right after encoded slashes, as in `%2F%2F@ab` (#30).
- 27 sat in code or text the PR added. 2 were drift, where unchanged base docs became
  wrong because of the PR: #14 and #18. One was base code: in #29 the faulty line was
  already on `main`, and only the PR's new Turbo Frame path reached it.
- 23 fixes changed code and added or changed a test, 2 changed only a test, and 5 changed
  only prose.
- Fixes chain here too. At least 9 of the 14 findings last recorded in cycle 2 or later
  sat in code an earlier fix had rewritten: #2, #8, #13, #15, #16, #22, #24, #26, and #30.
  The Shaka study counted findings first reported in cycle 2 or later. Here the first
  cycle is unknown for 6 of these 14, so the two figures are not directly comparable.
  #22's commit says the previous round's fix was wrong, and #24's says a commit hook's
  autofix undid the earlier fix.
- Two PRs hold 9 of the 30. Five sampled Codex-only defects come from
  [#5262](https://github.com/shakacode/react_on_rails/pull/5262), a new fleet-upgrade
  script. Four come from one URL-redaction routine in
  [#5218](https://github.com/shakacode/react_on_rails/pull/5218), where each fix exposed
  the next edge case. Two more, #8 and #21, come from
  [#5235](https://github.com/shakacode/react_on_rails/pull/5235), which changed the same
  redaction code. The Shaka study saw the same pattern on one path check.

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

### Run evidence

| # | Reviewed → fix | What ran | Result on the reviewed commit, then the fix |
| ---: | --- | --- | --- |
| 1 | `ee07998` → `25eff40` | `tagValidation.test.ts` (Jest) | 4 malformed UTF-16 cases fail; 9 of 9 pass |
| 2 | `dbdb273` → `619d88e` | `test_push_url_on_another_repo_is_refused` | Fails; passes |
| 3 | `5a7c824` → `90a6bb8` | Reviewed commit's own `vm.test.ts` on Node 18.20.3 | 3 fail at `jest.replaceProperty`; 60 of 60 pass |
| 4 | `d302422` → `f41bc82` | `test_repo_without_js_lockfile_still_opens_pr` | Fails; passes |
| 5 | `3fea28f` → `fa711c4` | `test_rerun_on_a_reused_pr_comments_its_new_evidence` | Fails; passes |
| 6 | `f41bc82` → `bb76334` | `test_regenerates_every_js_project_with_its_own_lockfile` | Fails; passes |
| 7 | `d302422` → `f41bc82` | `test_pins_files_the_default_branch_added_after_the_operator_checkout` | Fails; passes |
| 8 | `9e389e4` → `8858d7a` | `utils_spec.rb` | 4 fail, including "leaves encoded double slashes inside a path unchanged"; 0 fail |
| 9 | `30e3aa3` → `500c2a1` | CI command tests (`node --test`) | 14 fail, all because the fix reruns the gate run instead of dispatching one; read |
| 10 | `cd8e976` → `8b2f788` | Doctor and lockfile specs | 4 fail, including "warns about a vulnerable npm alias copy"; 0 fail |
| 11 | `0208746` → `03fb6d0` | `release_rake_helpers_spec.rb` | "warns and continues on a retry whose tag already exists" fails; 0 fail |
| 12 | `f5e2718` → `c815b9c` | `ci-required-label-filter.test.cjs` | 3 fail, including "reruns the gate when a hosted-CI label changed after the pass started"; 0 fail |
| 13 | `ec7d15a` → `13d5323` | `ppr_warm_rake_spec.rb` with the abort message mutated | Reviewed spec still passes 15 of 15; fixed spec fails 1 |
| 15 | `2ab0241` → `f7666c0` | `utils_spec.rb` | 3 fail, including "does not treat a space between two paths as an authority"; 0 fail |
| 16 | `82a2d5b` → `2ab0241` | `utils_spec.rb` | 4 fail, including "does not treat a line break between two paths as an authority"; 0 fail |
| 17 | `25eff40` → `16515ae` | `tsc` on the fix's type tests | Unused `@ts-expect-error`; clean |
| 19 | `4cf0022` → `82a2d5b` | `utils_spec.rb` | "leaves a literal stack-trace URL intact when its own path has an escape" fails; 0 fail |
| 21 | `1260983` → `9a64039` | `utils_spec.rb` | 4 fail, including "leaves an encoded password before a literal at sign to the literal patterns"; 0 fail |
| 22 | `fa19d3b` → `8e9b617` | `check-node-renderer-fresh-engines.test.mjs` | "counts an engines.node npm cannot parse as a mismatch" fails; 10 of 10 pass |
| 23 | `9b21747` → `69c185c` | `shaka_seam_check_test.rb` with each side's pinned Shaka | "unknown review key: local_review_count"; passes |
| 24 | `04d93c1` → `ea04c37` | `configBuilder.test.ts` | 5 fail (undefined, null, `""`, `0`, `"false"`); 93 of 93 pass |
| 25 | `a569ce1` → `40c8a8d` | `markdown_link_lint_script_spec.rb` with lychee | 1 fails; 0 fail |
| 26 | `8b2f788` → `04c1dbd` | Doctor and lockfile specs | 4 fail, including "finds npm v1 alias copies beside a patched ordinary copy"; 0 fail |
| 29 | `710a593` → `8204e87` | `ClientSideRenderer.test.ts` | "renders the new props when same-id content mounts before a waiting component is cleaned up" fails; 54 of 54 pass |
| 30 | `f7666c0` → `ad73697` | `utils_spec.rb` | 3 fail, including "finishes when a literal at sign opens the token after an encoded authority start"; 0 fail |

Prose findings #14, #18, #20, #27, and #28 were read. #27's fix also added a test, which
passes on both commits because the finding concerns CHANGELOG text.

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

A commit counts as cleared when its ledger ended "No open findings" and both Codex and
Claude have a run recorded on that last reviewed commit. GitHub records the commit each
inline review comment was made on, so the comments on exactly that commit are findings on
code both local reviewers passed.

- 119 of the 128 ledger comments with an execution table ended with no open findings, on
  84 PRs. On 72 of those PRs, both reviewers ran on a clean final commit; the other 12
  have clean final commits whose ledger records a run from only one reviewer. The 7 comments
  without a table are left out of cycle, cost, and sign-off counts.
- On 31 of the 72 PRs, outside reviewers left 66 inline threads on the cleared commit.
  The four AI reviewers alone commented on 30 of them; GitHub code scanning was the only
  outside reviewer on the other.
- 50 of the 66 threads, and 11 of the 15 that led to a fix, were posted after the ledger
  comment's last update, so they followed the local sign-off. The workflow pushes only
  after local review, but the timestamps alone cannot order the other 16.
- Each thread was read with the agent's reply and labeled by hand:

| Outcome | Threads |
| --- | ---: |
| Fixed on the PR | 12 (11 distinct problems) |
| Fixed in another PR | 3 |
| Declined with a reason | 40 |
| Requested checks run, no code change | 2 |
| No reply | 9 |

| Reviewer | Fixed on the PR | Fixed elsewhere | Declined | Checks run | No reply |
| --- | ---: | ---: | ---: | ---: | ---: |
| Claude in CI | 5 | 0 | 15 | 0 | 4 |
| Codex connector | 1 | 1 | 8 | 0 | 2 |
| Greptile | 2 | 1 | 4 | 0 | 0 |
| CodeRabbit | 3 distinct (4 threads) | 1 | 12 | 2 | 2 |
| GitHub code scanning | 0 | 0 | 1 | 0 | 1 |

- 7 of the 31 PRs got at least one fix from this layer.
- The most consequential is a user-facing bug. On
  [#5227](https://github.com/shakacode/react_on_rails/pull/5227), Greptile found that one
  unregistered store on a page stopped every incoming Turbo Frame component from
  mounting. The fix went into the PR it was built on,
  [#5220](https://github.com/shakacode/react_on_rails/pull/5220). On
  [#5330](https://github.com/shakacode/react_on_rails/pull/5330), Greptile and CodeRabbit
  found that a release sign-in check outlived its wrapper on TERM or HUP.
- Others are small: a wrong PR number in a changelog entry, a duplicated helper, a
  clarified comment.
- The agent declined 40 of the 66 threads (61%), 39 of the 64 from the four AI reviewers.
  Most replies cite behavior that predates the PR, a disproof with a command or a source
  read, or a cost the agent judged too high.
- 9 threads got no reply. They include two P1 findings on the backport
  [#5283](https://github.com/shakacode/react_on_rails/pull/5283), whose source PR #5252
  disproved the same concern, and a security note on
  [#5275](https://github.com/shakacode/react_on_rails/pull/5275). This study did not check
  the unanswered threads.

### Commits with only one local reviewer recorded in the ledger

Outside reviewers left 23 more threads on clean final commits whose ledger records a run
from only one local reviewer. The ledger alone cannot show that the other reviewer never
ran there. They span 8 PRs, 7 of them with no thread on a two-reviewer commit.
Those threads led to 6 more problems fixed on the PR and 2 fixed elsewhere:

- [#5262](https://github.com/shakacode/react_on_rails/pull/5262), a new fleet-upgrade
  script whose ledger records only Codex on the final commit, drew most of them.
- On [#5139](https://github.com/shakacode/react_on_rails/pull/5139#discussion_r4289498346),
  whose ledger records only Claude on the final commit, the Codex connector found that TanStack Router versions
  the declared peer range allowed had removed the API the code read, so redirects fell
  back to status 200. The fix narrowed the peer range.
- On [#5193](https://github.com/shakacode/react_on_rails/pull/5193), two findings came
  before merge, and their fixes landed after it in
  [#5194](https://github.com/shakacode/react_on_rails/pull/5194).

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
| Defects and risks dismissed | 95 of 245 (39%) | 362 of 1,265 (29%) |
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
| Are fixed defects real? | 30 of 30 sampled, 16 confirmed by a run; 10 of 10 risks | 30 of 30 sampled, 24 confirmed by a run |
| Unlikely triggers among sampled defects | 4 of 30 | 3 of 30 |
| Already in the base | 0 of 40; 1 drift | 1 of 30, reached only through the PR's new path; 2 drift |
| Does each reviewer catch defects the other missed? | Yes: 154 Codex only, 113 Claude only | Yes: 19 Codex only, 13 Claude only |
| Do more reviewers after a clean loop find more? | Not measured | 11 problems fixed on 7 of 31 PRs; 61% of their threads declined |

Later-cycle findings are left out of this table: the Shaka study counted the cycle that
first reported each finding, and this one could read that cycle for only 8 of its 14
later-cycle findings.

## What this does and does not show

- 24 verdicts rest on a run. The 6 readings trust the finding and the fix diff.
- Dependencies came from `main`, not each commit's lockfile, so a run could differ on a
  commit whose dependencies changed. No run failed for a dependency reason.
- One agent, Claude Opus 5.5, judged every finding and every outside thread. It shares a
  model family with one local reviewer and with Claude in CI.
- The sample holds only findings an agent chose to fix. The 318 nits, 95 dismissed defects
  and risks, and 83 fixed risks were not checked.
- Outside threads were matched to the cleared commit by the commit GitHub records for each
  inline comment. 16 of the 66 cannot be ordered after the local sign-off by timestamp. Summary comments from the same bots were not counted, so the outside
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
  comment, so each check can be repeated.
- For the second layer, list each PR's inline review comments, keep roots from outside
  reviewers whose `original_commit_id` is the last reviewed commit of a ledger that ended
  with no open findings and has runs from both reviewers, and read the agent's reply in each thread. To order a thread
  after the local sign-off, compare its creation time with the ledger comment's
  `updated_at`.
- For a run check, check out the reviewed commit, copy in the fix's test files, and run
  them there and at the fix. [Run evidence](#run-evidence) gives the commits and the
  failing examples for each.
