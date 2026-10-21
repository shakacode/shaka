# Capture native delivery state

`DeliverySnapshot` reads the GitHub portion of a protected Ask evidence packet.
It captures PR state, declared check runs and changed-file line bounds at an
immutable head. It does not choose which checks gate a fixture or qualify a
delivery executor.

```ruby
require_relative 'lib/shaka/evaluation/delivery_snapshot'

plan = { 'repository' => fixture_repository, 'number' => fixture_pr,
         'head' => expected_head, 'check_apps' => { required_name => expected_app_id } }
reader = Shaka::Evaluation::DeliverySnapshot.new(plan, github: absolute_gh_path)
snapshot = reader.read
```

The protected controller supplies names and GitHub App IDs from its declared
fixture policy. This API does not discover branch protection or authorize a
fallback. It uses the native latest check runs for each App at the full head and
retains their IDs, suite IDs, status, conclusion and host-monotonic observation
time. Legacy commit statuses are not normalized. Missing or pending checks remain
observations; they never become success.
Duplicate declared names within an App, wrong identities and incomplete responses
raise `IOError` rather than selecting a passing run.

The reader brackets collection with PR reads and rejects head, base or file-set
movement. Its final `pull` preserves closure and merge state for the
[Ask grader](ask-grading.md). `changed_files` maps nonbinary final paths to line
counts; `blobs` retains their native object IDs and binary flags. Deleted and
binary files supply no line bounds. Missing or truncated text cannot qualify.
Blob expressions use the full head and literal paths as GraphQL variables.
This is a bounded sequence of observations, not an atomic GitHub snapshot.

Each complete read has a maximum 30-second deadline. The shared GitHub transport
limits each response to 1 MiB, discards stderr, terminates its subprocess group
and reaps the child. The reader refuses more than 100 changed files or 100 latest
check runs per declared App; it does not silently accept pagination. Same-repository
fixture PRs are supported; fork heads are refused.

Retain snapshots privately, outside agent mounts. All observation times belong
to the controller's current process lifetime. Collect checks before terminal
receipt and use a fresh final PR observation after acceptance; do not reuse an
earlier PR snapshot as proof of final state. Review receipts still come from
[DeliveryReadback](delivery-readback.md). Native terminal/tool capture, hidden
verification, capture completeness, isolation, tier 3 D2 and release decisions
remain separate. This API supplies no completeness flag and runs no model or
paid trial.

GitHub documents the [check-run filters and identities](https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference),
[PR file connection](https://docs.github.com/en/graphql/reference/pulls) and
[immutable blob fields](https://docs.github.com/en/graphql/reference/git#blob).
