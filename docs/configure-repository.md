# Configure a repository

## Before you start

Shaka relies on GitHub to block merges until CI passes. Your default branch needs
branch protection or a ruleset that requires at least one CI check. Check it from
the repository:

```bash
gh api "repos/{owner}/{repo}/rules/branches/$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)" \
  --jq '[.[] | select(.type == "required_status_checks")] | length'
```

A result of `1` or more means you are ready. Branch protection rules (rather than
rulesets) do not appear here; check **Settings → Branches** instead. If you see
`0`, add a ruleset that requires your CI check.

If the command fails with `Upgrade to GitHub Pro or make this repository public`,
the repository is private and its owner is on the GitHub Free plan. GitHub offers no
required checks there. Upgrade the organization to GitHub Team (or the account to
GitHub Pro), or make the repository public, before you configure Shaka. Otherwise
the agent stops before writing any files. See
[issue #235](https://github.com/shakacode/shaka/issues/235).

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
