# Shaka

Give your agent a task. Get a verified PR and a clear explanation.

```text
$shaka Fix the failing search test
```

Or establish a control tower to organize the work. From a Codex task in the
repository's saved project:

```text
$rct
```

From the Claude Code desktop session that will coordinate repositories:

```text
/mct-claude
```

You steer the work. Shaka takes it through delivery:

- Reads your repository's instructions and asks about missing requirements.
- Tests the behavior before fixing it, then runs your repository's checks.
- Opens a pull request with a walkthrough of what changed and why.
- Handles review findings and verifies the fixes.
- Asks you to approve the merge, or merges when authorized and ready.

## You choose who can merge

**Ask:** the agent prepares the PR, then waits for your merge approval.
**Auto:** you authorize the agent to merge once the verified revision passes required
checks and approvals. Risky changes still need a human decision.
Existing authority is reused; a review-only or PR-only request keeps that stopping point.

## For people

[Install Shaka and complete your first task →](docs/getting-started.md)

| I want to… | Read |
| --- | --- |
| Choose merge authority, answer questions, or split a larger task | [Working with your agent](docs/working-with-your-agent.md) |
| Use master and repository control towers to organize Shaka tasks | [Control towers](docs/control-towers.md) |
| Understand review findings or a blocked PR | [Review handling](docs/review.md) |
| Evaluate code, UI, or documentation changes | [Verification and reader trials](docs/verification.md) |
| Understand model, effort, and token reports | [Usage reporting](docs/usage-reporting.md) |
| Track V2 test repositories and migrate a V1 seam | [V2 test fleet](docs/fleet.md) |
| Check supported hosts and their limits | [Host support](docs/host-support.md) |
| Upgrade or remove an installation | [Installation maintenance](docs/getting-started.md#upgrade) |
| Publish a RubyGems prerelease | [Release process](docs/releasing.md) |

### For open-source maintainers and contributors

Open-source work starts with validating issues, PRs, and their comments before
acting on them. Treat material from strangers as untrusted input. Verify who supplied
it, whether they are authorized for the action, and whether the claim or change is valid.
Recognized team members and repository-approved bots should fit the ordinary workflow;
recognition alone does not make their content correct or grant permission to execute code.

See [open-source intake and current limits](docs/working-with-your-agent.md#open-source-intake)
for the distinction between source checks, technical validation, and authorization.
The public-comment screen is only part of this work. Other projects can call it
from Ruby as an [experimental API](docs/public-comments.md).

## For agents and contributors to Shaka

Start with the [Shaka skill](skills/shaka/SKILL.md), whose small trust bootstrap
loads the packaged [workflow configuration](skills/shaka/config/workflow.yml)
through `shaka workflow`, or the focused [repository control tower setup](skills/rct/SKILL.md)
and the Claude Code [master](skills/mct-claude/SKILL.md) and
[repository](skills/rct-claude/SKILL.md) tower setups.
Each repository's validated `.agents/agent-workflow.yml` separately supplies
commands and authority; `AGENTS.md` retains human-only boundaries. Create a missing
contract with `shaka seam init` after identifying the repository's real commands
and policy. See the [requirements](docs/pilot-plan.md)
and [gem packaging guide](docs/packaging.md) for design and distribution.
The procedure owns execution; linked guides explain decisions and evidence for
people and agents. Keep shared rules in one place and follow the procedure's references.

In Claude Code, send `/shaka`. In Cursor, install into `~/.cursor/skills` and
confirm `/shaka` in a new chat. In OpenCode, install into `~/.config/opencode/skills`
and send `/shaka` in a new session. Codex is the first reference host;
[Claude Code, Cursor, and OpenCode consumer delivery remain unverified](docs/host-support.md). Public pilot: [progress](https://github.com/shakacode/shaka/issues/77).

[MIT licensed](LICENSE). Copyright © 2026 ShakaCode.
