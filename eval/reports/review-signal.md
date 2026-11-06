# Local review signal: are the fixed findings real?

A reader-facing summary is the [article](../../docs/articles/review-signal-study.md).

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on 2026-11-05 and
2026-11-06 (UTC). The agent read published review data, ran each fix's own tests
against the reviewed commit, and drafted the text. The study started no paid model runs.*

## Why this ran

- On 2026-11-03, Lauren Tan, who works on pstack, called adversarial reviews "mostly a
  waste of tokens" and said pstack would use its
  [interrogate skill](https://github.com/cursor/plugins/blob/ab1f702ce8/pstack/skills/interrogate/SKILL.md)
  less ([post](https://x.com/poteto/status/2117437607940681849)).
- A follow-up [post](https://x.com/poteto/status/2117445316043825393) says repeated rounds
  "overcook" a PR. Its reasons: reviewers lack the goal, and the author agent accepts all
  feedback.
- Addy Osmani's [post](https://x.com/addyosmani/status/2114604912520921136) on the Claude
  Code team's review reports that about 59% of what repeated review flagged was code there
  "since its first pass". The team now asks the author to rethink the approach after
  three cycles, re-reviews only the diff after the first cycles, and avoids re-reporting
  issues already observed.
- [PR #985](https://github.com/shakacode/shaka/pull/985) ran 41 local reviewer runs over
  two ledgers.
- The [review process study](../../docs/articles/review-process-study.md) counted
  findings by their recorded disposition. Nobody checked that a `fixed` finding was real.

## What ran

- **Snapshot:** every issue comment on `shakacode/shaka` containing "Local Adversarial
  Review" or `shaka:reply:local-review`, downloaded 2026-11-05 at about 23:45 UTC: 1,087
  comments.
- **Population:** the 500 main comments in the ledger format (marker
  `local-review-loop-`), first published 2026-10-15 and last updated 2026-11-05. They cover
  339 PRs, 1,282 reviewed commits, and 2,574 reviewer runs.
- Older per-commit formats are left out. They lack the reporter on 40 fixed defects and
  the cost on many runs.
- **Findings:** each `Finding details` line, deduplicated by PR, finding ID, class, and
  title, keeping the newest comment: 2,486 findings on 283 PRs.
- **Terms:** a *cycle* is one reviewed commit. A *run* is one reviewer on one commit; the
  publication numbers each run as a round.

| Class and disposition | Findings |
| --- | ---: |
| Defect, fixed | 345 |
| Risk, fixed | 462 |
| Nit, documented or dismissed | 1,221 |
| Risk or defect, dismissed | 362 |
| Risk or defect, accepted by the maintainer | 68 |
| Other (open, decision needed, documented risk) | 28 |

### Sample

The rule was written to the task's state folder before any sampled report was read.

- **Defects:** class `defect`, disposition `fixed`, with a fix commit. Three strata by
  reporter: Codex only, Claude only, both. Within each, sort by the SHA-1 of
  `PR:ID:TITLE` and take the first 10.
- **Risks:** class `risk`, disposition `fixed`, with a fix commit, same sort, first 10.
- Each finding was checked the same way:
  1. Read the reviewer's own report for the commit where the finding was last recorded.
  2. Take the base as `git merge-base` of that commit and `origin/main`.
  3. **Real:** check the claimed input or state at that commit. When the fix added a
     test, check out the fix's test files on the reviewed commit, run
     `bundle exec ruby -Itest TEST_FILE`, then run the same file at the fix. Otherwise
     run a probe, or argue from the code or text.
  4. **Origin:** *new* when the cited lines or claim were added by the PR. *Drift* when
     unchanged base text became wrong because of the PR's change. *Base* when the
     problem existed before the PR.
  5. **Fix:** confirm the fix commit touches the cited place, and note what kind of
     change it made.

## Results

- All 40 were real. Four of the 30 defects need a trigger unlikely in practice: a
  seven-character SHA collision (#9), directory names shaped like Markdown links (#21,
  #28), and a URL with user info and no host (#29).
- 39 were new to the PR and one was drift (#15). None was already in the base.
- 20 were confirmed by a run. The fix's own test, or a probe, failed at the reviewed
  commit and passed at the fix. The other 20 were checked by reading. Most of those are
  prose findings, where a run proves nothing.
- 24 fixes changed code, and 16 changed prose. 23 of the 24 code fixes added or
  changed a test. For 18 of them, the run check above used that test.
- No reviewer proved a finding with a run. Codex runs with test execution prohibited, and
  Claude has read-only file lookup.

### Fixed defects

| # | PR | Finding | Reporter | Cycle | Real | Origin | Checked by | Fix |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [#916](https://github.com/shakacode/shaka/pull/916) | F1: configure.md called a setting that equals its default removable, though some are required | Codex | 1 of 2 | yes | new | code read | prose |
| 2 | [#539](https://github.com/shakacode/shaka/pull/539) | F13: Cleanup retired another ledger's per-commit report of the same commit | Codex | 4 of 7 | yes | new | run | code + test |
| 3 | [#634](https://github.com/shakacode/shaka/pull/634) | F1: A reply with an unnamed author let a superseded note thread resolve | Codex | 1 of 5 | yes | new | run | code + test |
| 4 | [#710](https://github.com/shakacode/shaka/pull/710) | F15: A non-executable helper under core.filemode=false leaves status healthy while verification … | Codex | 5 of 6 | yes | new | run | code + test |
| 5 | [#539](https://github.com/shakacode/shaka/pull/539) | F14: Retiring a per-commit comment that shares only one of its reports hides the other … | Codex | 5 of 7 | yes | new | code read | code + test |
| 6 | [#860](https://github.com/shakacode/shaka/pull/860) | F1: Visible estimate became stale after Cursor stop-hook usage refresh | Codex | 1 of 2 | yes | new | run | code + test |
| 7 | [#807](https://github.com/shakacode/shaka/pull/807) | F1: A parseable call-log line for this PR's commit missing a field yields a nil step and … | Codex | 1 of 6 | yes | new | run | code + test |
| 8 | [#698](https://github.com/shakacode/shaka/pull/698) | F1: Moving a destination aside could overwrite an earlier .before-shaka backup | Codex | 1 of 2 | yes | new | run | code + test |
| 9 | [#954](https://github.com/shakacode/shaka/pull/954) | F1: Seven-character head prefix can treat an outdated checkpoint as current | Codex | 1 of 2 | yes, unlikely trigger | new | code read | code + test |
| 10 | [#577](https://github.com/shakacode/shaka/pull/577) | F11: A reply past the first 100 thread comments looked like no reply, so handoff owed a … | Codex | 1 of 2 | yes | new | run | code + test |
| 11 | [#585](https://github.com/shakacode/shaka/pull/585) | F6: Saved result depends on the original absolute ledger path | Claude | 3 of 5 | yes | new | run | code + test |
| 12 | [#891](https://github.com/shakacode/shaka/pull/891) | F1: Fixed 3-entry cap names no trust-model reason for a fixed behavior | Claude | 1 of 3 | yes | new | code read | prose (design) |
| 13 | [#1024](https://github.com/shakacode/shaka/pull/1024) | F2: A renamed file counts twice among the other files | Claude | 1 of 5 | yes | new | code read | code + test |
| 14 | [#960](https://github.com/shakacode/shaka/pull/960) | R8: ADR says sub-schemas validate the personal file, but ReviewSchema demands review.required | Claude | 8 of 10 | yes | new | code read | prose |
| 15 | [#751](https://github.com/shakacode/shaka/pull/751) | F1: usage-reporting.md still describes only the 1.x export path and parentID turns | Claude | 1 of 6 | yes | new (drift) | code read | prose |
| 16 | [#810](https://github.com/shakacode/shaka/pull/810) | F4: Guide says the line folds when everything passed, but a review with findings also folds | Claude | 2 of 4 | yes | new | code read | prose + code + test |
| 17 | [#1031](https://github.com/shakacode/shaka/pull/1031) | F2: auto-merged label stated as universal; queue and refused-label cases go unlabeled | Claude | 1 of 4 | yes | new | code read | prose |
| 18 | [#592](https://github.com/shakacode/shaka/pull/592) | F1: Guide says a Next line is optional for every recommendation, but only Merge may omit it | Claude | 1 of 2 | yes | new | code read | prose |
| 19 | [#802](https://github.com/shakacode/shaka/pull/802) | F2: The workflow's delivery-agent definition matches every /shaka session, so an ordinary … | Claude | 1 of 4 | yes | new | code read | prose |
| 20 | [#563](https://github.com/shakacode/shaka/pull/563) | F1: Guide said concerns share the verdict paragraph; the renderer lists them separately | Claude | 1 of 2 | yes | new | code read | prose |
| 21 | [#850](https://github.com/shakacode/shaka/pull/850) | F8: Link-shaped directory names after an opening parenthesis, such as x([1](2), still evade … | Codex and Claude | 6 of 8 | yes, unlikely trigger | new | run | code + test |
| 22 | [#961](https://github.com/shakacode/shaka/pull/961) | F9: A bracket inside a comment ends a wrapped call early and hides its working-directory … | Claude and Codex | 3 of 9 | yes | new | run | code + test |
| 23 | [#807](https://github.com/shakacode/shaka/pull/807) | F7: The dropped-steps count grows on every update because steps dropped earlier are still … | Codex and Claude | 3 of 6 | yes | new | run | code + test |
| 24 | [#785](https://github.com/shakacode/shaka/pull/785) | F1: The 'A person changed it' label counted 4 PRs that only got comments | Codex and Claude | 1 of 4 | yes | new | code read | prose |
| 25 | [#1045](https://github.com/shakacode/shaka/pull/1045) | F1: Published accounting link loses definitions omitted from the report | Codex and Claude | 1 of 7 | yes | new | code read | prose |
| 26 | [#673](https://github.com/shakacode/shaka/pull/673) | F2: Fenced code blocks in Markdown lost code-file alias detection (for example dir = root + … | Codex and Claude | 2 of 9 | yes | new | run | code + test |
| 27 | [#1024](https://github.com/shakacode/shaka/pull/1024) | F1: Rendering preview crashes against an installed floor lookup without groups | Codex and Claude | 1 of 5 | yes | new | run | code + test |
| 28 | [#850](https://github.com/shakacode/shaka/pull/850) | F7: Splitting every ]( hides a traversal on a line with an unrelated link | Claude and Codex | 3 of 8 | yes, unlikely trigger | new | run | code + test |
| 29 | [#947](https://github.com/shakacode/shaka/pull/947) | F5: Userinfo before the host, as in https://a@:443/task, still hides an empty host | Codex and Claude | 2 of 3 | yes, unlikely trigger | new | run | code + test |
| 30 | [#902](https://github.com/shakacode/shaka/pull/902) | G10: A republish can move a known Prompt to CI time later | Claude and Codex | 4 of 6 | yes | new | run | code + test |

### Fixed risks

| # | PR | Finding | Reporter | Cycle | Real | Origin | Checked by | Fix |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| 31 | [#960](https://github.com/shakacode/shaka/pull/960) | F4: Schema messages do not name the personal file | Claude | 1 of 10 | yes | new | code read | prose |
| 32 | [#800](https://github.com/shakacode/shaka/pull/800) | F7: Automatic follow-up read as open-ended; dropped what to do after expiry | Claude | 2 of 5 | yes | new | code read | prose |
| 33 | [#923](https://github.com/shakacode/shaka/pull/923) | F3: Docs and a comment promised the linked review comment always gives the reason | Claude | 1 of 2 | yes | new | code read | prose |
| 34 | [#708](https://github.com/shakacode/shaka/pull/708) | M3: A failed check counted as a fresh one and suppressed the daily reminder | Claude | 1 of 3 | yes | new | run | code + test |
| 35 | [#853](https://github.com/shakacode/shaka/pull/853) | F4: New label lookups must accept redacted settings sources. | Claude | 4 of 6 | yes | new | run | code + test |
| 36 | [#757](https://github.com/shakacode/shaka/pull/757) | J2: A floor word with capitals never matched | Claude | 1 of 4 | yes | new | run | code + test |
| 37 | [#570](https://github.com/shakacode/shaka/pull/570) | F1: AGENTS.md stated an unenforced rule as fact about shipped Ruby | Claude | 1 of 2 | yes | new | code read | prose |
| 38 | [#811](https://github.com/shakacode/shaka/pull/811) | R1: unbundle_env! drops every BUNDLE_* setting, so a nested bundle exec loses an isolated … | Claude | 2 of 3 | yes | new | run | code |
| 39 | [#964](https://github.com/shakacode/shaka/pull/964) | F22: Branch key misses review-only tasks and records abandoned before Finish never end | Claude | 4 of 9 | yes | new | code read | prose (design) |
| 40 | [#542](https://github.com/shakacode/shaka/pull/542) | F1: Preview pass wording could apply without a resolved preview | Claude | 1 of 2 | yes | new | code read | prose |

Cycle is the reviewed commit, within its ledger, where the finding was last recorded.

### Evidence per finding

Each row names the published comment the finding came from, the reviewed commit and fix,
and the check. Rebased PRs show the rebased commits. Run checks used the reviewed commit's
tree with only the fix's test files swapped in.

| # | Source comment | Reviewed → fix | How it was checked |
| ---: | --- | --- | --- |
| 1 | [#916 comment](https://github.com/shakacode/shaka/pull/916#issuecomment-6439803749) | `2fe29f2` → `7f1d9ef` | Read: MergeSchema requires merge.preference at base 3900796 and head; configure.md:20 removability sentence added by PR |
| 2 | [#539 comment](https://github.com/shakacode/shaka/pull/539#issuecomment-6184014252) | `2da76c1` → `74ec848` | Run `test/local_review_publish_cleanup_test.rb`: the fix's test_another_ledgers_per_commit_report_of_the_same_commit_stays_visible fails at reviewed head 2da76c1 (rebased 4127622), passes at fix 74ec848 |
| 3 | [#634 comment](https://github.com/shakacode/shaka/pull/634#issuecomment-6241909962) | `1aa6e79` → `ad99a04` | Run `test/walkthrough_history_test.rb`: the fix's test_a_note_answered_by_an_unnamed_author_stays_open at reviewed head 1aa6e79 issues a resolveReviewThread mutation (unexpected request); passes at fix |
| 4 | [#710 comment](https://github.com/shakacode/shaka/pull/710#issuecomment-6260579060) | `c8cda9d` → `8a82ffe` | Run `test/install_status_files_test.rb`: the fix's test_a_helper_that_lost_its_execute_bit_is_named fails at reviewed head c8cda9d (no B10 finding), passes at fix |
| 5 | [#539 comment](https://github.com/shakacode/shaka/pull/539#issuecomment-6184014252) | `74ec848` → `150e917` | Read: per_commit? at 74ec848 uses any? over this ledger's reports, so a combined two-reviewer per-commit comment with one shared report is retired; the fix's changed test fails at 74ec848 only because the policy changed |
| 6 | [#860 comment](https://github.com/shakacode/shaka/pull/860#issuecomment-6353344450) | `a32f80b` → `d63312b` | Run `test/cursor_usage_estimate_refresh_test.rb`: the fix's stop-hook refresh test fails at reviewed head a32f80b (visible estimate stays UNKNOWN), passes at fix; base 908e299 had no visible estimate |
| 7 | [#807 comment](https://github.com/shakacode/shaka/pull/807#issuecomment-6314019812) | `889d0f4` → `2dbff47` | Run `test/timeline_steps_test.rb`: the fix's test_unreadable_lines... with review(duration_ms: nil) fails at reviewed head 889d0f4 (nil steps returned), passes at fix; timeline_steps.rb new in PR |
| 8 | [#698 comment](https://github.com/shakacode/shaka/pull/698#issuecomment-6257930181) | `27356e5` → `ea456b5` | Run `test/official_link_refusal_test.rb`: the fix's test_moving_aside_never_replaces_an_earlier_backup fails at reviewed head 27356e5, passes at fix; link_refusal.rb new in PR |
| 9 | [#954 comment](https://github.com/shakacode/shaka/pull/954#issuecomment-6489963059) | `048b110` → `db8e38f` | Read: stale.rb (new in PR) compared a 7-hex prefix; claim correct, but it needs two commits in one PR sharing 7 hex characters |
| 10 | [#577 comment](https://github.com/shakacode/shaka/pull/577#issuecomment-6229495111) | `a85f153` → `71f0db5` | Run `test/handoff_threads_test.rb`: the fix's test_a_thread_whose_reply_may_be_past_the_first_page_is_noted_not_owed fails at reviewed head a85f153, passes at fix; review_threads.rb new in PR |
| 11 | [#585 comment](https://github.com/shakacode/shaka/pull/585#issuecomment-6229914322) | `f71b609` → `0b08ac1` | Run `test/local_review_usage_edges_test.rb`: the fix's test_runner_result_attaches_both_ledger_heads_after_source_cleanup fails at rebased head f71b609 (1 record, expected 2), passes at fix; implementer also reproduced with a native-runner probe |
| 12 | [#891 comment](https://github.com/shakacode/shaka/pull/891#issuecomment-6412051785) | `e60b515` → `e537c90` | Read: AGENTS.md trust model allows a fixed behavior only for three named reasons; the proposed ADR text added in the PR named none |
| 13 | [#1024 comment](https://github.com/shakacode/shaka/pull/1024#issuecomment-6569337020) | `7f54b25` → `6365c3b` | Read: at 7f54b25 feature_guard paths lists both rename names and review_effort_floor others = paths.uniq.size minus floor files; base had no others count. Fix's test cannot run at head (render signature changed) |
| 14 | [#960 comment](https://github.com/shakacode/shaka/pull/960#issuecomment-6508800297) | `b022da3` → `82420bc` | Read: ReviewSchema#validate at b022da3 always calls enum!(review.required), which the ADR (new in PR) forbids in the personal file |
| 15 | [#751 comment](https://github.com/shakacode/shaka/pull/751#issuecomment-6280067040) | `cd53987` → `ea0194b` | Read: at cd53987 opencode_usage.rb falls back to opencode api get .../export (added in PR) while usage-reporting.md lines from base still describe only opencode export and parentID |
| 16 | [#810 comment](https://github.com/shakacode/shaka/pull/810#issuecomment-6314326001) | `450b4fa` → `7da26fc` | Read: routine? at 450b4fa folds when validation passed and any review is listed, regardless of findings; 'when everything passed' added by PR (absent at base) |
| 17 | [#1031 comment](https://github.com/shakacode/shaka/pull/1031#issuecomment-6596483832) | `3855741` → `2fe019e` | Read: base docs/pr-verification.md:50-51 named two unlabeled cases (merge queue, refused label); the PR's rewrite replaced them with a universal statement; the workflow still reports queue-deferred labels |
| 18 | [#592 comment](https://github.com/shakacode/shaka/pull/592#issuecomment-6230622190) | `46c8fc0` → `7a1a7a1` | Read: disposition.rb text_fields! at 46c8fc0 requires next_action except for Merge; doc sentence added by PR said Next is optional for all |
| 19 | [#802 comment](https://github.com/shakacode/shaka/pull/802#issuecomment-6328728664) | `503d175` → `e362d0a` | Read: workflow.yml:256-257 (added in PR) defined a delivery agent as any agent running the whole workflow for one task, which every /shaka session does; AGENTS.md's version has the tower qualifier |
| 20 | [#563 comment](https://github.com/shakacode/shaka/pull/563#issuecomment-6223706903) | `df76716` → `3f5d7d6` | Read: publication.rb#verdict at df76716 renders concerns as a separate list after the verdict paragraph; the 'one paragraph' sentence was added by the PR |
| 21 | [#850 comment](https://github.com/shakacode/shaka/pull/850#issuecomment-6338245797) | `1147113` → `27c53a3` | Run `test/seam_upgrade_unmoved_tool_test.rb`: the fix's seam_upgrade_unmoved_tool_test fails at rebased head 1147113, passes at fix 27c53a3 |
| 22 | [#961 comment](https://github.com/shakacode/shaka/pull/961#issuecomment-6491745232) | `fc38388` → `89aed78` | Run `test/seam_upgrade_false_positive_test.rb`: the fix's seam_upgrade_false_positive_test fails at fc38388 (2 failures), passes at fix 89aed78 |
| 23 | [#807 comment](https://github.com/shakacode/shaka/pull/807#issuecomment-6314019812) | `692a101` → `14953f7` | Run `test/timeline_steps_test.rb`: the fix's timeline_steps_test (with fixture) fails at 692a101 (dropped count grows), passes at fix 14953f7 |
| 24 | [#785 comment](https://github.com/shakacode/shaka/pull/785#issuecomment-6305319723) | `2bacd69` → `c4d6014` | Read: at 2bacd69 the new article's line 54 says 4 of 51 commented PRs did not change, while line 68 and later tables label all 65 'A person changed it' |
| 25 | [#1045 comment](https://github.com/shakacode/shaka/pull/1045#issuecomment-6617540501) | `f7840be` → `cdc4417` | Read: UsageDetails::GUIDE (base) links every usage table to usage-and-cost.md for column definitions; the PR's rewrite removed them. Codex called it a nit, Claude a defect |
| 26 | [#673 comment](https://github.com/shakacode/shaka/pull/673#issuecomment-6258364616) | `f2bd227` → `6f6a5df` | Run `test/seam_upgrade_test.rb`: the fix's test_assigned_directory_values_without_command_names_block (guide.md case) fails at f2bd227, passes at fix 6f6a5df |
| 27 | [#1024 comment](https://github.com/shakacode/shaka/pull/1024#issuecomment-6569337020) | `7f54b25` → `6365c3b` | Probe: at 7f54b25, HumanReview.render(3, base-shaped floor without groups) raises NoMethodError: undefined method 'map' for nil |
| 28 | [#850 comment](https://github.com/shakacode/shaka/pull/850#issuecomment-6338245797) | `aabedde` → `db94c65` | Run `test/seam_upgrade_unmoved_tool_test.rb`: the fix's seam_upgrade_unmoved_tool_test fails at rebased head aabedde, passes at fix db94c65 |
| 29 | [#947 comment](https://github.com/shakacode/shaka/pull/947#issuecomment-6487735655) | `d0377c9` → `b3ca133` | Run `test/task_source_line_test.rb`: the fix's task_source_line_test fails at d0377c9 (https://a@:443/task accepted), passes at fix b3ca133 |
| 30 | [#902 comment](https://github.com/shakacode/shaka/pull/902#issuecomment-6479167788) | `5aec7cb` → `aaeef20` | Run `test/throughput_stats_test.rb`: the fix's throughput_stats_test fails at 5aec7cb (rebased 9938348; Prompt to CI 43m instead of 38m), passes at fix aaeef20 |
| 31 | [#960 comment](https://github.com/shakacode/shaka/pull/960#issuecomment-6508800297) | `e582087` → `ba8f7d2` | Read: schema messages such as 'merge.preference must be ask or auto' name no file, so the new ADR's 'the schema's own message' would not name the personal file the issue requires |
| 32 | [#800 comment](https://github.com/shakacode/shaka/pull/800#issuecomment-6312884793) | `509febb` → `2441cdb` | Read: the PR's shortened docs/working-with-shaka.md dropped the base text telling users what to do after a follow-up expiry; follow-up monitors still expire |
| 33 | [#923 comment](https://github.com/shakacode/shaka/pull/923#issuecomment-6479110018) | `dcd798f` → `050856c` | Read: setup_gaps links content['review'] whenever supplied; nothing guarantees that comment states a reason for a local_review_count shortfall; sentence added by PR |
| 34 | [#708 comment](https://github.com/shakacode/shaka/pull/708#issuecomment-6260128941) | `6f3a827` → `d2c08c8` | Run `test/startup_notice_test.rb`: the fix's test_a_failed_check_is_not_saved_so_the_reminder_continues fails at 6f3a827, passes at fix d2c08c8 |
| 35 | [#853 comment](https://github.com/shakacode/shaka/pull/853#issuecomment-6351073713) | `a9eae56` → `2c7cce7` | Run `test/publication_settings_summary_test.rb`: the fix's regression raises KeyError: key not found: "REDACTED" at a9eae56, passes at fix 2c7cce7; the fetch calls were added by the PR |
| 36 | [#757 comment](https://github.com/shakacode/shaka/pull/757#issuecomment-6310097710) | `59b75ca` → `0ee46e2` | Run `test/review_effort_floor_setting_test.rb`: the fix's review_effort_floor_setting_test fails at 59b75ca (capitalized word never matches; level 4 expected), passes at fix 0ee46e2 |
| 37 | [#570 comment](https://github.com/shakacode/shaka/pull/570#issuecomment-6225042445) | `4fb4c6c` → `1c78d14` | Read: AGENTS.md:140-141 (added by PR) stated 'Ruby reads them and repeats no literal' as fact; no test enforces it, as the fixed text now says |
| 38 | [#811 comment](https://github.com/shakacode/shaka/pull/811#issuecomment-6314379974) | `5aa9cae` → `98ab543` | Probe: with BUNDLE_PATH set, Bundler.unbundle_env! (added to test_helper by PR) leaves ENV['BUNDLE_PATH'] nil, so a test's nested bundle exec loses an env-configured bundle path |
| 39 | [#964 comment](https://github.com/shakacode/shaka/pull/964#issuecomment-6494126585) | `0e2fce2` → `9104b6c` | Read: the proposed ADR keyed pins by claim branch and released only at Finish; review-only tasks have no claim branch and abandoned tasks never reach Finish |
| 40 | [#542 comment](https://github.com/shakacode/shaka/pull/542#issuecomment-6185759490) | `dcc75cf` → `0d77ef8` | Read: the PR's workflow.yml wording made the resolved-preview pass read as unconditional while ui-verification.md kept the conditional; fix removed the duplicate sentence |

### What was not fixed

A sample of 15 dismissed defects and risks, drawn by the same hash rule, read from their
recorded reasons only:

- 13 were claims the implementing agent disproved with code, a test, or a run, or showed
  to be intended behavior.
- 1 described behavior that predates the PR ([#844](https://github.com/shakacode/shaka/pull/844) F11).
- 1 concerned the goal file given to reviewers, not a repository file.

A keyword scan of all 362 dismissed defects and risks finds 9 whose reason mentions
predating the PR or falling outside its scope.

## Cycles and empty runs

| Measure | Median | 90th percentile | Max |
| --- | ---: | ---: | ---: |
| Cycles per ledger | 2 | 5 | 12 |
| Runs per ledger | 4 | 10 | 24 |
| Cycles per PR | 3 | 7 | 36 ([#800](https://github.com/shakacode/shaka/pull/800)) |
| Runs per PR | 6 | 14 | 74 ([#800](https://github.com/shakacode/shaka/pull/800)) |

- 479 of 500 ledgers ended with "No open findings". The other 21 ended with findings
  that needed attention.
- **Empty runs:** 1,242 of 2,574 runs (48%) reported nothing.
  - Codex: 1,009 of 1,310 (77%).
  - Claude: 231 of 1,262 (18%).
  - DeepSeek: 2 of 2, trial runs written into shared ledgers.
- **Empty cycles:** 242 of 1,282 cycles (19%) had no finding from any reviewer.
- **Cycles with no fix:** 708 cycles (55%) produced no fixed finding. Most are the
  closing check after the last fix: 394 ledgers end with exactly one such cycle.
- **Where fixed defects come from:** each reviewer's report maps its items to finding
  IDs, which gives the cycle that first reported each finding. Of 274 fixed defects with
  a known first cycle, 159 (58%) were first reported in cycle 1, 42 in cycle 2, 27 in
  cycle 3, and 46 later. Fixed risks follow the same shape: 231 of 395 (58%). The other
  71 fixed defects and 67 fixed risks have no readable mapping.

### What later cycles find

Of the sampled findings, 17 were first reported in cycle 2 or later: 13 defects and 4
risks. Each report's collation line gives a finding's first round. For rebased PRs, whose
reports name pre-rebase commits, the round number gives the cycle.

- 11 sat in code written during the review loop, absent at the ledger's first reviewed
  commit. Most came from fixes for earlier findings.
- 6 sat in code or text the first cycle had already seen: defects #11, #14, #16, and
  #30, and risks #32 and #39.

Osmani reports about 59% for the share of repeat-review findings in code there since the
first pass. The sample's figure is 6 of 17 (35%). The sample is stratified by reporter,
so the figure does not estimate a population rate. Three of the four defects are
Claude-only findings.

## Cost

- The publications estimate a cost for 2,310 of the 2,574 runs, $728.47 in total.
- 443 ledgers have a cost on every run. They total $726.08 and hold 305 fixed defects and
  424 fixed risks.
  - **$2.38 of reviewer spend per fixed defect.**
  - **$1.00 per fixed defect or risk.**
  - Counting only defects with a likely trigger gives about $2.68. That weights each
    stratum's share by its size: 9 of 10 Codex-only, 10 of 10 Claude-only, and 7 of 10
    found by both.
- Per run: Codex $0.11 and Claude $0.53, across those 443 ledgers.
- Cycle 1 took $243.52 (33%) of costed spend. Later cycles took $485 (67%).
- Claude's per-run cost varies with its model. On #985, Opus 5.5 runs cost $0.37 to
  $0.69, and Fable 5.1 runs cost $3.19 to $4.42.
- The implementing agent's tokens and time for triage, fixes, and revalidation are not
  in these numbers. The earlier study measured local validation at a median of 5.5
  minutes and a review run at 43 seconds.

## Did a suggestion make the change worse?

- No sampled fix left the merged change worse than before review.
- Two fixes introduced the next defect:
  - #22: a fix added bracket counting to group statements. The next cycle showed a
    bracket inside a comment broke it, and the final fix removed the grouping.
  - #23: an earlier fix added a note counting dropped timing steps. The count grew on
    every republish until #23's fix.
- Three fixes were incomplete:
  - #5: the F13 fix (#2) still retired a comment when only one of its reports matched.
    Closing it took a review cycle past the ledger's cap.
  - #30: the first fix read commit statuses but still let a later time replace an
    earlier one.
  - #21 and #28: on #850, seven findings (F1, F5, F7, F8, F10, F11, F12) concerned how
    one path check reads Markdown links. F8 returned after its first fix. Both sampled
    ones need a directory name shaped like a link, which nobody is likely to create.
- One fix is a judgment call. In #12, the author removed a proposed cap instead of
  justifying it or making it a setting.
- Across the population, 41 findings were marked "returned after its fix". 23 of them
  are fixed defects, 6.7% of all 345.

## Comparison with the sources

| Claim | Shaka's data |
| --- | --- |
| Repeat review mostly finds old code (Osmani, ~59% there since the first pass) | 6 of 17 later-cycle findings (35%). 11 of 17 were in code written during the loop. |
| Findings are often code from before the change | 0 of 40 fixed findings; 1 of 15 sampled dismissals |
| Reviewers lack the goal (Tan) | The workflow tells the agent to pass the task's goal file to every run. Whether reviewers used it was not measured. |
| The author accepts all feedback (Tan) | 362 defects and risks (15% of findings) were dismissed with a reason. At least 152 nit dispositions say the nit was kept as written, and at least 189 say it was applied. |
| Reviewers get lost in nitpicks (Tan) | 1,221 nits, 49% of findings. Claude reported 1,211 of them, 56% of its findings. |
| Only findings proven by a run should survive (pstack interrogate) | No reviewer ran anything. 18 sampled fixes carried a test that fails at the reviewed commit and passes at the fix. |

## Recommendation

**Keep the two-reviewer loop as it is.**

- **The fixes are real.** Every sampled `fixed` defect and risk was a real problem, and
  each was introduced by its PR. A fixed-only sample cannot show how common base findings
  are, because an agent would dismiss those. Dismissals show few: 1 of 15 sampled, and 9
  of 362 by keyword. A label for findings already in the base would have little to mark.
- **Each reviewer finds defects the other misses.** Of 345 fixed defects, Codex alone
  reported 154, Claude alone 113, and both 78. Dropping either reviewer, or reviewing
  less, would lose about a third or more of the fixed defects.
- **In the sample, later cycles mostly caught the loop's own new code.** A diff-only
  re-review would
  likely still find those 11 of 17. It could miss findings like the 4 of 13 later-cycle
  sampled defects in code the first cycle saw. The sample is too small to say how many
  fixed defects that is. The saving would be some part of the later-cycle spend, $485
  over three weeks.
- **This data cannot test run-based verification.** The sample holds only findings a
  reviewer named and an agent fixed, so it cannot show what an adversary required to
  prove findings with a run would find or miss. It does show that the repository's tests
  did not cover these inputs until a reviewer named them.
- **The review is cheap per real defect:** $2.38 of reviewer spend.

What would change this:

- The implementing agent's cost per extra cycle is unmeasured. A large cost there would
  make a diff-only re-review after cycle 1 worth a trial.
- The largest share of findings that change nothing is Claude's nits. The
  [review process study](../../docs/articles/review-process-study.md#1-the-local-claude-reviewer-is-noisy-but-it-carries-most-of-the-fixes)
  already proposed capping them, a change outside the three options compared here.

## What this does and does not show

- The sample measures how often an agent's decision to fix was right. The reviewers'
  overall precision is not measured: 1,221 nits and 362 dismissed defects and
  risks were not verified.
- One agent judged every finding. Claude Opus 5.5 shares a model family with one of the
  reviewers. The 20 run checks do not depend on that judgment; the 20 readings do.
- A run shows the reviewed code behaved as the finding said. A run cannot show how often
  users would reach that input.
- Origin labels compare the cited lines and claims with the base. Prose drift was judged
  by reading.
- A finding's cycle is where it was last recorded, which can be later than where it was
  first reported.
- The sample of 17 later-cycle findings is small, so 35% has a wide margin.
- Costs are the publications' own estimates. 264 runs have none, and Claude's model mix
  changed during the window.
- One repository, one maintainer, three weeks. Review prompts and criteria changed during
  the window.

## Rerun it

- Download the issue comments of the repository and keep those whose body contains "Local
  Adversarial Review" or `shaka:reply:local-review`.
- Keep main comments whose marker starts with `local-review-loop-`. Parse each
  `Finding details` line as ID, class, title, disposition, fix commit, reporters, and
  last-recorded commit. Parse each `Execution metadata` row as run, commit, reviewer,
  finding count, and cost.
- Each reviewer's report sits in a `Round N · COMMIT · REVIEWER` disclosure. Its
  **Collated as** line maps report item numbers to finding IDs.
- Draw the sample with the rule above. The two tables list every sampled finding, so the
  same snapshot gives the same 40.
- Check each with the procedure under Sample. For a run check, run the fix's test files on
  the reviewed commit and then on the fix.
