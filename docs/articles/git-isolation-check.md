# Would one Git runner have caught Shaka's Git environment bugs?

*An AI agent wrote this article: Claude Code running Claude Opus 5.5, on 2026-11-16. The
agent counted every place Shaka's library starts Git and read the 13 review findings
behind the question. No person has rechecked the classification. The
[report](https://github.com/shakacode/shaka/blob/main/eval/reports/git-subprocess-isolation.md)
holds the inventory, the per-finding table and the probes.*

## Conclusions

1. **Do not build the check yet.** The proposed test requires every Git call to go
   through one runner that hides the caller's Git setup. Over one month it would have
   caught 3 of the 7 Git environment defects in library code. Covering evaluation
   tooling too raises that to 5.
2. **A simple version catches none.** A test that looks for `git` as the spawned program
   misses both library defects. One ran Git inside `sh -c`. The other passed the Git
   path in a variable.
3. **The test would fight the trust model.** Two dismissed findings asked for isolation
   that the maintainer's own checkout does not need. The test would flag the same code.
4. **One runner changes what Shaka reads.** Hiding global Git config turned a
   maintainer's `gh:shakacode/shaka` origin into a URL Shaka cannot read. Fetches need
   that config too.
5. **Routing is large.** 40 library files start Git, under nine different environment
   rules. More than half the spawn points use the caller's environment unchanged.

## Why this ran

[Which review findings repeat](https://github.com/shakacode/shaka/pull/1212) sorted a
month of Shaka review findings into kinds. Git calls that inherit the caller's Git setup
were its best candidate for a mechanical check: 13 findings, 7 defects on 5 PRs. Its
reviewers asked for a count of Git call sites and a finding-by-finding map before anyone
built the test.

## What ran

- **Inventory:** every process the library starts, found with one `grep` and read by
  hand. 40 calls in 29 files start Git directly. 11 more files start Git through
  shared wrappers.
- **Map:** each finding's review comment and fix commit, judged on two questions. Would
  the rule see the Git call before the fix? Would the runner's policy have prevented
  the problem?
- **Probes:** two scratch repositories on Git 2.54. One tested whether isolation flags
  stop a checkout filter. The other tested how hiding global config changes the origin
  URL.

## Findings

| Rule | Defects caught (of 7) | Findings caught (of 13) |
| --- | --- | --- |
| `git` as the spawned program, library only | 0 | 0 |
| Also `sh -c` steps and Git path variables, library only | 3 | 3 |
| Same, plus evaluation tooling in `eval/bin` | 5 | 6 |

- **Out of reach:** three findings concern the test suite's own Git config, which sets
  Git options on purpose. One concerns a repository setting the runner keeps.
- **Filters:** isolation flags stopped a filter that a committed `.gitattributes`
  selected. They did not stop one selected in `.git/info/attributes`. The real fix read
  raw file contents, so no filter could run.
- **Recurring shape:** every caught defect ran Git on a repository Shaka created or did
  not own, or fed a restricted reviewer. Six places do this. Each now guards against its own risk.

## Limits

- One agent did the counting and classification.
- The window is one month.
- The probes ran on macOS only.

## What would change the answer

Two more PRs with Git environment defects outside those six places would justify
another look.
