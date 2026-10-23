# Linux Codex commits reached protected verification

The isolated Linux mechanics trial passed. Codex committed and pushed a failing
fixture change, waited for its commit-bound FAIL review, pushed a repair, and
waited for the repair's PASS review before finishing.

This exercised the merged controller at
[727bcbe](https://github.com/shakacode/shaka/commit/727bcbe0bc08099fee6151a8f3b77914270b8bcf).
It does not establish complete activity capture, measured Ask success, or release
readiness.

## Retained public evidence

The [disposable fixture PR](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/pull/1)
is closed without merging and retained as evidence.

| Observed commit | Source | Protected result |
| --- | --- | --- |
| [63df8e6](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/commit/63df8e6347a3b32b356beed9b9405ee5eb228cb4) | Operator setup | [FAIL](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/pull/1#pullrequestreview-5625236414) |
| [57f126b](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/commit/57f126bef11e610a4701e3685f4995a8bff4786f) | Codex commit and push | [FAIL](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/pull/1#pullrequestreview-5625238576) |
| [36c6f79](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/commit/36c6f790fb057becfbceb7899f42dfef740c7cb9) | Codex repair and push | [PASS](https://github.com/shaka-eval-repos/shaka-linux-push-qualification-867/pull/1#pullrequestreview-5625242904) |

The native stream retained 13 started and 13 completed command items. The
protected driver independently fetched each SHA, checked the fixed fixture blob,
posted a labeled COMMENT and read it back. Its final readback preceded receipt
of Codex's final "linux-pushes-ok" message. That message is a mechanics marker,
not the Ask approval protocol, and received no delivery acceptance timestamp.

Codex CLI 0.163.0 ran in an isolated Linux container using the existing
subscription, configured for gpt-6.1-sol at low effort. The served model remains
UNKNOWN. Raw sessions, process evidence, private paths and environment fingerprints
remain in protected local evidence.

## Push authority and cleanup

The fixture rejected deploy keys. No key was installed; the unused local key was
removed. With maintainer approval, a temporary native Git relay forwarded pushes
from Codex to this one fixture repository. Its protected hook admitted one
non-deleting update to the declared branch and required GitHub's previous commit
to match. Codex received no broader GitHub token.

Linux reachability and real upstream forwarding passed before model execution.
Negative probes refused another branch, deletion and multiple updates without
forwarding an upstream write. One initial relay probe rejected a valid ref because
of prototype hook escaping; that was corrected before the successful preflight.

The protected verifier and GitHub credentials stayed outside the agent container.
The copied subscription authentication was removed before session export. The
container, temporary volume and relay were removed or stopped; the Linux VM was
stopped. Native Git forwarding is qualification infrastructure, not an installed
Shaka service or a general-purpose authenticated Git proxy.

## Budget and remaining gates

One model run cost **$0.4326485 API-equivalent**, charged to the shared evaluation
ledger. The monthly total became **$1.0666605**, with zero pending reservations.
The manual Linux scope used $0.711289 of its $1 bound. Approved pilot limits remain
$200/month, $5/night and $15/PR; judges, retries and manual delivery trials count
toward the monthly total.

The follow-up controller guard is tested offline: failed, unfinished and timed-out
native captures refuse an aggregate even after a verifier result succeeds.
Earlier receipts and logs remain private for diagnosis. The live trial above ran
before that guard was added; it exercised the successful capture path.

Command capture completeness remains false. This trial covers command-tool pushes
through a bounded relay, not every terminal/tool route or an independent process
inventory. Separate machine/driver identities, private measured Ask fixtures,
terminal acceptance, full D2 assembly, calibrated judges, statistics and the D9
release conditions remain unqualified or unbuilt. The result cannot promote a
release.
