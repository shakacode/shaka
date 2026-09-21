# Shaka

Give your agent a task. Get a verified PR and a clear explanation.

Shaka is the early `0.0.x` successor to [`shakacode/agent-workflows`](https://github.com/shakacode/agent-workflows).
It is not “Shaka V2.” Seam YAML `version: 1` is the typed-contract version;
the published gem identifier `0.1.0.pre.1` only reserves the RubyGems name.
Install from this repository, not from the predecessor pack.

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
- Asks you to merge on GitHub when the PR is ready, or merges when authorized.

## You choose who can merge

**Ask:** when the PR is ready and nothing else remains, you merge it on GitHub and can archive the chat.
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
| Track test repositories and migrate a predecessor seam | [Test fleet](docs/fleet.md) |
| Follow predecessor retirement | [Retirement](docs/retirement.md) |
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
`shaka enforcement` reports what backs each rule that workflow states with
never, must, do not, or only when: a command that refuses it, a command that only
reports it, a GitHub setting, or nothing but the agent.
Each repository exposes predictable engineering commands through `.agents/bin/` and keeps
typed authority in `.agents/agent-workflow.yml`; `AGENTS.md` retains human-only boundaries.
Create a missing contract with `shaka seam init` after identifying the repository's real
commands and policy. See the [requirements](docs/pilot-plan.md)
and [gem packaging guide](docs/packaging.md) for design, distribution, and the
version-pinned CI seam check.
The procedure owns execution; linked guides explain decisions and evidence for
people and agents. Keep shared rules in one place and follow the procedure's references.

In Claude Code, send `/shaka`. In Cursor, install into `~/.cursor/skills` and
confirm `/shaka` in a new chat. In OpenCode, install into `~/.config/opencode/skills`
and send `/shaka` in a new session. Codex is the first reference host;
[Claude Code has one verified consumer delivery; Cursor and OpenCode remain unverified](docs/host-support.md). Public pilot: [progress](https://github.com/shakacode/shaka/issues/77).

Public GitHub.com repositories can run CodeQL without a paid Advanced Security
license. This project's [CodeQL workflow](.github/workflows/codeql.yml) analyzes
Ruby on pull requests and pushes to `main`. Org or repo settings must still allow
GitHub Actions and code scanning, or the job cannot upload alerts. A private fork
needs GitHub Advanced Security (or equivalent) enabled before the same workflow
can publish results.

[MIT licensed](LICENSE). Copyright © 2026 ShakaCode.
