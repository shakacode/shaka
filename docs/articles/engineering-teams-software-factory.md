# Your engineering team probably doesn’t need a software factory

Steve Yegge’s agents overwhelmed his players with features, his accountant with email, and his merge queue with tickets. About a dozen people were working with the factory for his online game. After giving two talks about the experience, he advised teams to pace AI output to what people can absorb. He also said he had scrapped five previous factories when rewriting them became cheaper than fixing them. [Steve Yegge’s post on X](https://x.com/Steve_Yegge/status/2121671447810888185)

The more work you hand to agents, the more decisions someone has to make. Which changes are worth doing? Who reviews them? Who decides when they’re ready to ship? A factory that handles those questions across engineering and operations will naturally grow around the company that runs it.

There’s a smaller problem most engineering teams can solve first. When I give an agent a task, I want a pull request I can make a decision on without reopening the chat and reconstructing what happened.

## The work between “I fixed it” and “ready to merge”

Take a small bug: search breaks when the query contains an apostrophe. An agent can often produce a plausible patch quickly. The useful handoff shows how the agent reproduced the bug through the search interface, whether the same query works after the change, and what else it checked. If a reviewer found that the first fix changed how ordinary queries behave, I want to see that finding and how it was resolved.

Multiply plausible patches across a team and you get a queue full of diffs that people still have to investigate. Give reviewers the reproduction, test results, and review findings, and they can spend more of their time judging the change. Is this the behavior we want? Will it surprise callers? Are we comfortable shipping it now?

That’s where Shaka fits. It’s an open source skill that takes a task through the team’s existing GitHub workflow. It asks the coding agent to verify the change, get an independent review for substantial work, address findings, and explain the result on the pull request (PR). The handoff shows what passed, what remains unverified, and what decision is left. [See a merged Shaka PR](https://github.com/shakacode/shaka/pull/667).

By default, a person decides whether to merge. Teams can also authorize automatic merging for eligible changes under their repository’s rules. Required checks and approvals still apply, and larger or riskier changes can come back to a maintainer. That lets a team delegate the follow-through before it decides where to delegate the merge. [Choose a merge policy](../working-with-shaka.md#choose-a-merge-policy).

## Start with the queue you already have

Yegge also expects people to bring their own teams of agents to work. If that happens, colleagues will need to evaluate work produced by agents they never interacted with. A PR already gives teams a way to do that. It can carry the task, the proposed change, and the evidence in a form another engineer can inspect.

I’d try this on one repository with a few ordinary bug fixes, keeping the merge decision with a person. Then I’d ask the reviewers what they still had to chase down. Did they have to reproduce the bug themselves? Could they tell which checks covered the current commit? Did the PR make clear where someone needed to make a call? That feedback tells you what to improve before you give agents more work. [Try Shaka on a small task](../getting-started.md).

If your review queue is already full, opening more PRs gives your team more work. Making the next PR easier to judge is a good place to start.
