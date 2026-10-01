# PR250: one-hour replay of the PR326 task

Both agents delivered the multiple-local-reviewer feature and passed the tested
behaviors. The harness qualified with limitations. PR250's incremental value is
**inconclusive**: the writing comparison below has mixed results, and no maintainer
correction time was measured. This is one fixed-order public pair, not hidden
test data or a repeatable performance claim.

## What was compared

[PR326](https://github.com/shakacode/shaka/pull/326) had already solved the task.
Two fresh repositories started from the same earlier source and independently
implemented it. Neither agent received the reference solution. The original
PR326 and [PR250](https://github.com/shakacode/shaka/pull/250) were unchanged.

| Input | Baseline A | Candidate B |
| --- | --- | --- |
| External Shaka helper | `682527f1cbf5dee5bede78be9717e665073eb20b` | PR250 at `9e25abeb67afcc351425663a4115e9eaf48cbdf1` |
| Target source | `682527f1cbf5dee5bede78be9717e665073eb20b` | Same |
| Model / effort | gpt-6.1-sol / medium | Same |
| Prompt and writing guide | Same fixed task and explicit guide pointer | Same |
| Execution | Two turns in one session; one hour including CI and handoff | Same |
| Budget | $10 API-equivalent soft stop; $0 incremental metered API authorization | Same |

Both seed commits were `af38917a95d8fbb397d20460a25c9bcd1ae956be`, tree
`62f1815a9dbe7dc5fd6f5db82bb6e775c2f00b2c`, checked including ignored files.
Initial head `c8710788daa3b6570b4ca160a21720e004fcccf7` failed the intended ordered
reviewer assertion locally and on GitHub. Full pins, image/CLI versions, isolation,
native usage, timing and cleanup are in the
[execution report](https://github.com/shakacode/shaka/pull/250#issuecomment-5911241095).

## Delivery and correctness

| Evidence | Baseline A | Candidate B |
| --- | --- | --- |
| Retained output | [PR](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-a-r2/pull/1), head `88f0539f7e7b99d7768683cdbce3dab12bae1cad` | [PR](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-b-r2/pull/1), head `8ce71399bb3d04be8a67bd98263fb185078565ec` |
| Elapsed | 41m03s | 46m22s |
| Declared-rate API equivalent | $2.9734872 | $3.4479094 |
| Local tests / assertions | 2,102 / 11,991 | 2,105 / 11,865 |
| Hosted validation | Pass at final head | Pass at final head |
| COMMENT walkthrough / Ask marker | Both match final head | Both match final head |
| Independent selection probe | 6 tests / 21 assertions, pass | Same |
| Concurrent batch and receipt probe | 1 test / 42 assertions, pass | Same |
| Restored-seed suite | 2,078 tests / 11,665 assertions, pass | 2,078 tests / 11,662 assertions, pass |

All full suites had zero failures/errors and one existing skip. Restored tests
preserved two inspected expectation updates: the new storage file's I/O
classification and the initializer's default count of one. Generated tests also
passed local/hosted validation. Protected paths and the seeded assertion remained
unchanged. Both PRs stayed open and unmerged; temporary access, credentials and
runtimes were removed. Repositories remain as history.

The first grader rejected B's unsupported `--reviewer` option. B documents round
selection in its public JSON input; the task did not prescribe a flag. The probe
was corrected to use JSON addressing for both unchanged outputs. Both passed,
including receipts identifying the round recorded. This was a grader correction,
not an agent retry. The earlier 30-minute pair's real receipt defect remains in
its separate [historical result](https://github.com/shakacode/shaka/pull/250#issuecomment-5906768008).

## Writing comparison

These are the operator's unblinded observations after execution, using the
shared writing guide. They are not a preregistered score or maintainer acceptance.
Read the [A walkthrough](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-a-r2/pull/1#pullrequestreview-5365398064)
and [B walkthrough](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-b-r2/pull/1#pullrequestreview-5365999579)
alongside their PR descriptions.

| Criterion | Observed difference | Correction or judgment |
| --- | --- | --- |
| Reader understands the outcome first | A opens with several reviewers retaining reports; B opens with what maintainers can request | Both work. B's human subject is a modest clarity advantage, not proof of loader benefit |
| Walkthrough explains choices in order | A groups the change in three sections; B separates selection, concurrent results, fixes, publication and limits | B is easier to scan; A explains explicit round targeting more directly |
| Limits and evidence remain visible | B puts compatibility and the owner's responsibility to wait near the top; A puts these details in collapsed sections | Prefer B's visible limits. Both link code and disclose absent live review |
| Usage is useful and candid | A includes a partial native usage snapshot; B reports unknown usage and retains two unknown implementation records | B needs better evidence collection; A's partial snapshot is not the final session total. Use the execution report's final totals |
| Status and next action are accurate | Both preserve seed text saying evaluation has not started; B's WIP next action suggests merging the eval PR | Correct the seed text before the next run and require the handoff to say retain/unmerged. Do not rewrite the saved outputs to improve their score |

The candidate improves some presentation choices but loses information and gives
an unsuitable next action. No corrections have been accepted or timed by a
maintainer. Both arms already received the same explicit style pointer, so this
pair asks whether automatic loading adds value over that cheaper alternative.
It does not test style discovery without a pointer. Larger diffs, token counts
and elapsed time do not settle the writing question.

## What changes before another experiment

| Work | Owner | Completion evidence |
| --- | --- | --- |
| Explain replay, harness validity, delivery and value separately | Eval maintainer | Contributor guide and this report |
| Reap orphaned processes before model work | Runner owner | Container starts with `--init`; `check-process-reaping` passes in the final image |
| Prepare destination-specific trust settings before seed pinning | Run operator | Same prepared trust file in both seed trees; controlled comment admitted before the run and after Write removal |
| Avoid stale seed status and preserve public-interface flexibility | Run operator / grader author | Timeless seed description; no assumed CLI spelling when documented JSON behavior satisfies the task |
| Decide whether the writing differences matter | Maintainer | Accept or reject the concrete corrections above; record actual review effort if measured |
| State the next hypothesis before another model pair | Eval maintainer | One decision, fixed criteria, revisions and budgets; explain what new evidence another run can provide |

The process check has an offline before/after reproduction: it fails without
Docker init and passes with it. The portable trust recipe needs authenticated
qualification on the next prepared fixture; it has not been retrofitted into
these retained experiments. Both agents needed temporary reapers during these
runs, and the current operator comment reader rejected the inherited team owner.
Native publisher/readback evidence and independent review metadata supported
the delivery conclusions; they do not qualify the current comment reader.

B also encountered transient proxy reconnection errors and a blocked Actions log
host. Those confound timing and should be covered by final-image preflight when
log retrieval is required. No network policy or authentication changed mid-run.

The shipped container helper is a qualification probe, not the full paired replay
driver. Keep the next step small: adopt the reaping check and prepared trust
settings in the local driver, qualify them without model work, then decide whether
another PR250 trial is worth running. Do not start another PR326 replay merely
because these runs are finished.
