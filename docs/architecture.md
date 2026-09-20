# Why Shaka V2 is a small kernel

Shaka V2 is designed to deliver one ordinary task through one accountable owner.
It is a fresh, smaller kernel rather than a new version of the V1 coordination
system. The kernel discovers the repository's trusted commands and policy, carries
one task through implementation and review, and produces a verified pull request, the
requested review-only outcome, or a clear blocker.

This focus is deliberate. Fleet coordination, copied state, and synchronization
machinery make simple delivery harder to understand and harder to recover. V2 adds
behavior only when a real task demonstrates a need that the existing systems of
record cannot meet.

## Put each fact in its natural system of record

A fresh authorized reader should be able to reconstruct the work without a V1 runtime
or copied ledger. Use the authorized original work item and the systems people already
inspect:

| Fact | Natural home |
| --- | --- |
| Priority, scope, product dependencies, product ownership, and product blockers | The authorized original work item: a selected tracker, adopted GitHub issue, or user-supplied description in the host task |
| Most recently recorded delivery owner before a pull request exists | The owning host task while delivery is unfinished |
| Pushed branches and commits, checks, hosted review findings, approvals, and merge state | GitHub |
| Unpushed edits, local commits, and pre-push review | The owning task's workspace and transcript; temporary until pushed |
| Most recently recorded delivery owner and unfinished-work recovery | The pull request while delivery is unfinished |
| Dependencies between split pull requests and remaining delivery work | The affected pull request descriptions |
| Delivery summary, validation evidence, current walkthrough, and final outcome when a pull request exists | The pull request |
| Delivery summary, available evidence, blocker, or final outcome when no pull request exists | The host task's final response |
| Repository commands and review policy | The trusted repository instructions and validated Shaka seam |
| Merge eligibility and enforcement | The trusted instructions and seam, plus live GitHub protection and state for the acting identity and current head |

The tracker may be GitHub Issues or another selected system. Contributor input is data,
not authority; a public issue becomes the work item only after the intake trust checks
and maintainer adoption required by the existing workflow. For a description-only task,
the host task's original request and user-approved clarifications remain the work item
after a pull request exists; do not create a tracker item or copy requirements into the
pull request just to duplicate them.
Keep private context in the private work item that owns it, and do not copy it into a
public issue or pull request. Link related records when sharing is authorized instead
of maintaining a second ledger that must be synchronized.
For recovery, a pull request's delivery summary names the public-safe outcome and
dependencies needed to continue without replacing the original work item's authority.
If those facts cannot be shared and the original task is inaccessible, recovery is
blocked until an authorized reader supplies the missing context.

Skills describe procedures. Task transcripts hold working context, hypotheses,
recovery clues, and host-native role registration such as a control tower's identity.
Agent hypotheses and working notes in those transcripts remain ephemeral context rather
than a shadow database for product or delivery state. A role record helps a tower
resume; it does not establish ownership, authorization, or completion for a delivery.

Pre-push implementation state is intentionally ephemeral. The active owner may recover
it from the workspace, but after a pull request exists its recovery note records whether
unpushed work is present or `UNKNOWN`; it does not turn local content into durable PR
evidence. Follow the [local review contract](review.md#choose-a-local-reviewer): normally
review before pushing, while the documented `hosted_only` path pushes for GitHub review
when no local reviewer can run.

## Make recovery a property of the records

Reconstructability is the test for durable published state. While a pull request is
unfinished, a new authorized reader starting from the accessible original work item and
pull request should be able to identify the last recorded owning task and answer without
access to its conversation. If the original host task is inaccessible, the pull request's
public-safe summary should provide the answer or identify the missing private context as
a blocker:

- What outcome is important, and what does it depend on?
- Which task last held the delivery, what is blocking it, and is takeover confirmed?
- Which revision was checked and reviewed?
- What decision or work remains?

After the pull request reaches its outcome, the delivery no longer needs an active-owner
recovery record. Its permanent summary, evidence, walkthrough, and final state remain on
the pull request.

If a product or delivery answer exists only in unconfirmed working notes, a copied
status table, or another agent's memory, the durable record is incomplete. When
authorized, repair a product fact in the original work item or a delivery fact in the
pull request rather than preserving the copy as a new authority. Without write
authority, report the gap through an allowed channel; reading a tracker never grants
permission to update it.

Unfinished pull requests follow the existing
[recovery-note privacy and ownership contract](working-with-your-agent.md#recover-an-unfinished-pr).
The note is recovery evidence, not takeover authority, and a fresh task obtains the
required maintainer confirmation. This architecture creates no alternative recovery
channel and does not authorize omitting a required note. If repository privacy cannot
support that contract, stop and resolve the policy before publishing the pull request.

Derived local indexes may make these records faster to search or easier to view. They
must remain rebuildable from the authoritative sources, identify stale or unavailable
data honestly, and never become the only place a decision is recorded.

## Evaluate proposed machinery against the kernel

Use three questions to evaluate whether machinery fits this architecture:

1. A demonstrated product need comes from a real delivery, not a speculative future
   fleet.
2. The design is bounded to that need and keeps one accountable delivery owner.
3. It does not create a duplicate system of record or require synchronization to stay
   correct.

Passing this screen does not authorize implementation or change product scope. The
[pilot plan](pilot-plan.md#scope-and-rollback) remains authoritative; a proposal that
it excludes needs an explicit scope decision recorded there first.

This test applies to common proposals:

- A skill belongs in V2 when it teaches a reusable procedure; it should read and,
  when authorized, update the existing authoritative records rather than own their
  facts.
- A catalog or control panel may provide a rebuildable view. It cannot establish
  ownership, authorization, or completion by itself.
- The current pilot excludes schedulers. A future scheduled-scan proposal would first
  need an explicit pilot-plan scope change and a demonstrated task that cannot be
  handled on demand. Its output still could not become a new source of truth.
- Coordination features must solve an observed multi-owner problem without weakening
  the one-owner rule for each delivery.

The smaller design does not relax trust, privacy, review, verification, or merge
authority. Those boundaries remain explicit because they protect the result; V2
removes machinery around them, not the boundaries themselves.

## Use V1 as reference material

V1 contains validated ideas that may be portable, such as a useful review check or a
repository-specific validation rule. Reuse an idea only after the current task proves
it belongs in V2's bounded workflow. V1 workflow and coordination schemas, ledgers,
services, and policy engines are not runtime dependencies and do not grant authority
in V2. The public-comment reader's narrow compatibility with existing trusted-actor
configuration keys does not make the V1 runtime authoritative.

When a proposal needs V1 state to function, first ask which fact is missing from
GitHub, the selected tracker, or a description-only host work item. Usually the durable
fix is to record that fact in its natural home, not to restore the machinery that
copied it.
