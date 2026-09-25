# Configure a repository

## Before you start

Shaka waits for your CI checks before it calls a PR ready, and before it merges one
in Auto mode. It uses the checks GitHub requires on your default branch through a
ruleset or branch protection. When GitHub requires none, as on any private
repository on the GitHub Free plan, list them in
[`merge.required_checks`](settings.md#mergerequired_checks) instead.

Setup works this out for you. To see where you stand first:

```text
$shaka Which CI checks does GitHub require on this repository's default branch?
If none, which check names appear on recent PRs?
```

A repository with no required checks can still use Shaka in Ask mode: the agent runs
local validation and review, and you merge on GitHub. Auto merge needs at least one
required check.

## Set up

Connect your existing tools to Shaka:

```text
$shaka Configure this repository for Shaka. Reuse its existing setup,
test, and validation commands. Explain the review and merge choices.
Use merge policy ask.
```

The agent inspects your project, confirms missing choices, and prepares these files:

| File | Purpose |
| --- | --- |
| `.agents/agent-workflow.yml` | Review, merge, branch, and WIP settings |
| `.agents/bin/setup` | Install project dependencies |
| `.agents/bin/test` | Run tests; accept focused test arguments |
| `.agents/bin/validate` | Run the complete pre-PR checks |
| `.agents/bin/validate-local` (optional) | Run a faster local check before review |
| `.agents/bin/trigger-hosted-ci` (optional) | Start deferred CI after local fixes; requires `validate-local` |
| `.agents/trusted-github-actors.yml` | Whose public GitHub comments the agent may read |
| `AGENTS.md` | Project instructions and constraints |

The scripts usually wrap existing commands. In Shaka's repository, `.agents/bin/setup`
installs development dependencies; `bin/install` installs the skill.

You merge the first setup PR yourself on GitHub. Until it merges, the default branch
has no trusted settings, so Shaka cannot choose a reviewer from them or merge
on your behalf. The agent reviews the PR, then gives it back with the commit to merge.

To change a choice later:

```text
$shaka Configure this repository to wait for all configured CI reviewers.
Keep merge policy ask.
```

See [settings](settings.md) for values and defaults. Shaka's own
[configuration](https://github.com/shakacode/shaka/blob/main/.agents/agent-workflow.yml) and [scripts](https://github.com/shakacode/shaka/tree/main/.agents/bin)
provide working examples.
