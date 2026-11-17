# Git subprocess isolation check

[#1212](https://github.com/shakacode/shaka/pull/1212) found 13 review findings in kind
`git_subprocess_environment`: 7 defects on 5 PRs. It named one candidate check and asked
for this evaluation first. The candidate is a boundary test that requires every Git call in
`skills/shaka/lib` to go through one runner. That runner would clear `GIT_*` variables,
global config, filters and hooks.

## Result

- **Recommendation: defer.** Do not build the single-runner test.
- **The literal rule catches no defect.** A test that looks for `'git'` as a spawned
  program would have caught none of the 7 defects. The 3 library defects it should find
  sit on two code paths. One started Git through `sh -c`, the other through a
  `git_executable` variable.
- **A broader rule catches 3 of 7 defects.** It must also treat repair's `sh -c` steps
  and `git_executable` callers as Git spawns. Extending the scope to `eval/bin` adds 2
  defects and 1 fixed risk, for 6 of 13 findings.
- **The test would also demand isolation the maintainer rejected.** #710 F1 and F2 were
  dismissed under the [trust model](../../docs/workflow.md#trust-model). The rule flags
  the same code.
- **One policy cannot serve every caller.** Clearing global config changes what Shaka
  reads from the maintainer's own checkout. Fetches from the maintainer's remotes need the maintainer's network config.
  Isolation flags do not stop every filter.
- **Routing is large.** 40 files in the library start Git, directly or through a shared
  wrapper. Above 29 changed files, a merge needs the maintainer's confirmation. 22 of the
  40 direct spawn points, and 4 of the 6 wrapper paths, use the inherited environment.

## Spawn-site inventory

The inventory was taken at `fbd03c9` (main on 2026-11-16). Main at `f2441b6`, the
review base, has the same `skills/shaka/lib`.

- **Unit:** a spawn point is a call that creates a process. A shared wrapper that runs
  many programs counts once, as a wrapper path. Files that hand Git to a wrapper are
  listed by name. Call sites behind wrappers are not counted: injected runners pass Git
  on through further readers, such as `configuration/sources.rb` and
  `TrustedPathResolver`.
- **Primitives:** 59 process-creation calls in `skills/shaka/lib`:

  ```sh
  grep -rnE "Open3\.\w+\(|\bsystem\(|\bexec\(" --include='*.rb' skills/shaka/lib
  ```

- **Classification:** each of the 59 was read by hand.
  - 15 never start Git. They run `gh`, `glab`, `diff`, `sysctl` (`evidence/machine_facts.rb`),
    `taskkill` (`doctor/bounded_command.rb:168`), `opencode`, `codex`, the Shaka helper,
    or the validation command (`evidence/tree_watch.rb`).
  - 40 start Git directly, from 29 files.
  - 4 are generic wrappers that also start Git for some callers:
    `local_review/process.rb:19`, `claim.rb:91`, `canary/run.rb:15` and
    `doctor/bounded_command.rb:71`. `BoundedCommand` serves three of the six wrapper
    paths below, each with its own environment.
- **Files:** 29 with direct spawns, plus 11 that start Git only through a wrapper: 40.
  No backtick or `%x` spawns exist.

### Direct spawn points by environment policy

| Policy | Spawn points | Where |
| --- | --- | --- |
| Inherits the caller's environment | 22 | `branch_name.rb` (2), `claim.rb`, `configuration/fingerprint.rb` (2), `configuration/fingerprint/trusted_prompts.rb`, `configuration/layout.rb`, `configuration/sources.rb` (4), `git_origin.rb`, `local_review/rebased_commits.rb` (2), `prompt_show.rb`, `publication/rendering_preview.rb`, `trusted_config_source.rb` (2), `trusted_path_resolver.rb`, `usage/rate_card.rb`, `work.rb`, `trial/prepare.rb:115` (refuses inherited overrides first) |
| Clears a list of repository-local `GIT_*` variables | 10 | `WorkflowVersion::GIT_ENVIRONMENT` (15 names): `workflow_version.rb`, `configuration/feature_guard.rb`, `evidence/review.rb`, `evidence/result.rb` (2), `evidence/candidate_tree.rb`, `evidence/base_freshness.rb` (2). `PrivateGitPaths::GIT_ENVIRONMENT` (16 names): `configuration/private_git_paths.rb`. `Seam::Initializer` (5 names): `seam/initializer.rb` |
| Clears every `GIT_*` variable | 6 | `install/checkout_git.rb` (keeps SSH, askpass and config variables for clone, fetch and ls-remote), `install/repair.rb` (`sh -c`; keeps SSH and askpass), `install/source.rb`, `install/git_ignore.rb` (2), `install/status_unsupported.rb` |
| Also hides system and global config | 2 | `trial/prepare.rb:105` (the 15-name list, plus hooks and submodule recursion off), `merge_tree_proof.rb` (also `HOME` and attributes) |

### Wrapper paths that carry Git

| Wrapper path | Environment | Files that pass Git |
| --- | --- | --- |
| `LocalReviewProcess.capture` | Inherited; `git` resolved on a PATH that excludes the candidate | `local_review/runner.rb`, `local_review/commit_export.rb`, `local_review/criteria.rb`, `local_review/prompt_file.rb`, `local_review/settings_source.rb`, `local_review/custom_instructions.rb`, `prompt_show/views.rb` |
| `Claim`'s runner | Inherited | `claim.rb` |
| `Canary::Run::Runner` | Inherited | `canary/run.rb` |
| `Doctor::RUNNER` (`BoundedCommand`) | Inherited | `doctor/git_runtime.rb`, `doctor/settings_source.rb` |
| `BoundedCommand` from `evidence/base_freshness.rb` | `WorkflowVersion` list | `evidence/base_freshness.rb` (fetch) |
| `UpdateCheck::Launch` (`BoundedCommand`) | Clears every `GIT_*` variable | `update_check.rb` |

Nine hand-written environment variants exist: inherited, three variable lists, three
clear-all variants (keeping nothing, network settings, or SSH and askpass), and two
kinds of config isolation. Two lists name the same 15 variables; `PrivateGitPaths` adds
`GIT_CEILING_DIRECTORIES`.

### Git tooling outside the library

- `test/test_helper.rb` points the whole test suite at a generated global Git config.
  All three #553 findings concern it.
- `eval/bin/first-task-seed` copies the repository-local list and hides global config.
  All four #1131 findings concern it.
- `bin/report-instruction-growth`, `bin/lefthook/*`, `.agents/shaka/bin/*` and
  `skills/shaka/scripts/shaka.rb` also run Git. They are operator or development tooling.

## Per-finding map

Two questions decide each row:

- **Seen:** does a routing rule see the spawn at the commit before the fix?
  "Literal" means a rule that looks for `'git'` as the spawned program. "Broad" also
  treats `sh -c` steps and `git_executable` callers as Git spawns.
- **Removed:** would the runner's fixed policy have prevented the problem?

| Finding | Class, disposition | Code | Seen | Removed | Verdict |
| --- | --- | --- | --- | --- | --- |
| [#553 F1](https://github.com/shakacode/shaka/pull/553#issuecomment-6210898354) included config paths unquoted | defect, fixed | `test/test_helper.rb` | No: test harness | No: a quoting bug | Not caught |
| [#553 F3](https://github.com/shakacode/shaka/pull/553#issuecomment-6212318918) generated `GIT_CONFIG_GLOBAL` could mask a guard | risk, dismissed | `test/test_helper.rb` | No: test harness | n/a | Out of scope |
| [#553 F8](https://github.com/shakacode/shaka/pull/553#issuecomment-6206729899) `GIT_CONFIG_PARAMETERS` overwrote inherited values | risk, fixed | `test/test_helper.rb` | No: test harness | No: the harness sets config on purpose | Not caught |
| [#710 F1](https://github.com/shakacode/shaka/pull/710#issuecomment-6310252723) status could run filters | risk, dismissed (trust model) | `install/status_git.rb` via `CheckoutGit` | Literal and broad | Yes | Flagged, no defect |
| [#710 F2](https://github.com/shakacode/shaka/pull/710#issuecomment-6313778109) same as F1 | risk, dismissed (trust model) | same | Literal and broad | Yes | Flagged, no defect |
| [#710 F15](https://github.com/shakacode/shaka/pull/710#issuecomment-6260579060) `core.filemode=false` hides a lost execute bit | defect, fixed | `install/status_modes.rb` | n/a | No: repository config, which the runner keeps | Not caught |
| [#833 F12](https://github.com/shakacode/shaka/pull/833#issuecomment-6332391879) repair inherits `GIT_DIR` | defect, fixed | `install/repair.rb` | Broad only: `sh -c` | Yes | Caught by the broad rule |
| [#833 F16](https://github.com/shakacode/shaka/pull/833#issuecomment-6332391879) repair keeps global and system config | defect, fixed | `install/repair.rb` | Broad only: `sh -c` | Yes | Caught by the broad rule |
| [#962 F1](https://github.com/shakacode/shaka/pull/962#issuecomment-6492115380) export ran checkout filters | defect, fixed | `local_review/commit_export.rb` | Broad only: `git_executable` | Yes, for committed attributes (probe below) | Caught by the broad rule |
| [#1131 F6](https://github.com/shakacode/shaka/pull/1131#issuecomment-6781437834) inherited variables redirect the seed object store | defect, fixed | `eval/bin/first-task-seed` | Only with `eval/bin` in scope | Yes | Caught with wider scope |
| [#1131 F8](https://github.com/shakacode/shaka/pull/1131#issuecomment-6784887018) global filters change seed bytes | defect, fixed | `eval/bin/first-task-seed` | Only with `eval/bin` in scope | Yes | Caught with wider scope |
| [#1131 F15](https://github.com/shakacode/shaka/pull/1131#issuecomment-6781437834) inherited SHA-256 default | risk, fixed | `eval/bin/first-task-seed` | Only with `eval/bin` in scope | Yes | Caught with wider scope |
| [#1131 F16](https://github.com/shakacode/shaka/pull/1131#issuecomment-6781437834) global `core.worktree` could relocate the checkout | risk, dismissed (disproved by a run) | `eval/bin/first-task-seed` | n/a | n/a | Moot |

Totals:

| Rule | Defects caught (of 7) | Findings caught (of 13) | Dismissed findings flagged |
| --- | --- | --- | --- |
| Literal, library only | 0 | 0 | 2 (#710 F1, F2) |
| Broad, library only | 3 | 3 | 2 (#710 F1, F2) |
| Broad, library and `eval/bin` | 5 | 6 | 2 (#710 F1, F2) |

#1212 estimated 4 to 6 catchable findings. The upper end holds only with `eval/bin` in
scope and the broad rule.

## Why one runner does not fit

- **Origin identification changes.** `GitOrigin.from` runs `git remote get-url origin`.
  Git expands the maintainer's `url.<base>.insteadOf` there. In a scratch repository with
  `origin` set to `gh:shakacode/shaka`:
  - with a global config mapping `gh:` to `https://github.com/`, Git printed
    `https://github.com/shakacode/shaka`;
  - with `GIT_CONFIG_GLOBAL=/dev/null`, it printed `gh:shakacode/shaka`.
    `GitOrigin.from` then returned host `gh` in place of `github.com`. The identity
    `shakacode/shaka` and the name stayed the same.
- **Fetches from the maintainer's remotes need the maintainer's config.**
  `CheckoutGit::AUTHENTICATION_ENV` keeps SSH, askpass and config variables for clone,
  fetch and ls-remote. The #1131 F8 fix kept network configuration for fetch.
  `trial/prepare.rb` fetches with global config hidden. It reads one public `https`
  URL, which needs no credentials.
- **Flags stop only filters that committed attributes select.** A scratch repository on Git 2.54 had a
  smudge filter defined in `.git/config`.
  - With `.gitattributes` selecting it, `git --attr-source=<empty tree> -c
    core.attributesFile=/dev/null checkout-index` wrote raw bytes and ran no filter.
  - With `.git/info/attributes` selecting it, the same command ran the filter.
  - #962 removed the risk by reading raw blobs with `cat-file --batch`.
- **The trust model allows inherited config.** The [trust model](../../docs/workflow.md#trust-model)
  fixes behavior only when code parses it, when it keeps outside input from acting as
  instructions, or when it keeps an install out of a broken state. Reads of the
  maintainer's own checkout with the maintainer's own config meet none of these. #710
  F1 and F2 were dismissed on this ground.

## Cost to route callers

- **Files:** 40 start Git. Above 29 changed files, a merge needs the maintainer's
  confirmation. Routing would take one confirmed oversized PR or at least 2 PRs.
- **Runner modes:** at least three. Local reads keep the maintainer's config, network
  commands keep authentication, and operations on scratch or foreign repositories isolate
  fully.
- **Behavior changes:** the 22 inheriting spawn points and the files behind 4 inheriting
  wrapper paths would change what they read. Each needs a test of the new behavior.
- **Allowlist upkeep:** `test/configuration_boundary_test.rb` is the closest precedent. Its
  file-access check keeps an 89-name allowlist, and its Git-read check keeps 3 more. A
  routing test needs a similar list for the generic wrappers and the `gh` callers.
- **Review cost precedent:** #1212 counted 38 review findings on the 7 PRs that built and
  extended the seam upgrade reference scanner.

## Smallest useful alternative

The defects that recurred share one shape. Shaka ran Git on a repository it created or
did not own, or handed the output to a restricted reviewer. Six places do this today:
`merge_tree_proof.rb`, `trial/prepare.rb`, `evidence/candidate_tree.rb`,
`local_review/commit_export.rb`, `install/repair.rb` with `install/checkout_git.rb`, and
`eval/bin/first-task-seed`. Each now guards against its own risk, and the guards differ.

- `merge_tree_proof.rb`, `trial/prepare.rb` and the seed hide global and system config.
- `evidence/candidate_tree.rb` clears the variable list and gives Git its own index and
  object directory.
- `local_review/commit_export.rb` reads raw blobs, so no filter runs.
- `install/repair.rb` and `install/checkout_git.rb` clear `GIT_*` variables, including
  `GIT_CONFIG_GLOBAL` for repair steps. Git still reads `~/.gitconfig` and the system
  config there.

- **Option:** share one variable list across `WorkflowVersion`, `PrivateGitPaths` and the
  seed. The lists already differ by one variable. This is cheap and needs no new test.
  No defect has come from the difference.
- **Revisit:** reconsider the boundary test when Git environment defects reach 2 more PRs
  outside those six places in a later month.

## Limits

- One agent classified the 59 primitives and the 13 findings. No person rechecked them.
- "Seen" is a judgment about a rule that does not exist. A different rule would see
  different spawns.
- The window is one month, the same one #1212 used.
- The probes ran on macOS with Git 2.54 only.

## How to rerun

- Count primitives with the `grep` above, then classify each by reading it.
- Read each finding in its ledger comment, linked in the table, and the fix commit it names.
- Run the filter and `insteadOf` probes in a scratch repository with
  `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`.
