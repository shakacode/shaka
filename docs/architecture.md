# Why Shaka stays small

Shaka carries one task to its requested outcome: usually a reviewed pull
request, sometimes a plan or review only. One task stays accountable through
work, review, and any authorized merge or handoff. A control tower can own that
task, but cannot become a second delivery owner.

## Keep facts where people look for them

- The selected work item holds the reason for the work: priority, scope, and
  dependencies.
- GitHub holds delivery evidence: commits, checks, reviews, and the PR outcome.
- The agent task holds experiments and unpushed work. That context is temporary.

A fresh authorized reader should be able to reconstruct the owner, blocker,
revision, and next step from the work item and GitHub. An unfinished PR carries a
short [recovery note](working-with-shaka.md#resume-unfinished-work) for that
purpose. The note helps someone resume; it does not authorize a takeover.

Keep private context in its authorized home. A public PR needs enough safe
context to explain the delivery without copying private work items into it.

## Add machinery only when a task needs it

Before adding a skill, catalog, scan, or coordination feature, ask:

1. What problem did a real delivery reveal?
2. Can the solution stay bounded with one accountable owner?
3. If it disappeared, could people reconstruct the work from the tracker and
   GitHub?

A skill can teach a procedure. When authorized, it updates the existing record;
reading a tracker alone grants no write permission. A catalog can be rebuilt
from those records. A scheduled scan needs evidence that on-demand inspection
is insufficient. Passing these tests does not itself expand the product scope.

## Keep the safety boundaries

Trusted repository policy, verification of the current revision, independent
review, acceptable risk, merge authority, and live GitHub protection still
govern delivery. Keeping Shaka small removes duplicate state and coordination
steps, not these checks.

The predecessor offered useful ideas, but its runtime is neither a dependency
nor a source of authority. Bring back an idea only when a real Shaka task needs it.
