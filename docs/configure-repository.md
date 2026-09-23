# Configure a repository

Ask Shaka to use the project's existing commands:

```text
$shaka Configure this repository for Shaka using our existing setup, tests,
and validation commands. Use our installed CI reviewers and keep merging at
Ask. Include fast local validation or staged CI if this project supports them.
Prepare the configuration as a PR and explain any decisions I need to make.
```

Use `/shaka` in Claude Code, Cursor, or OpenCode. The agent inspects your project
and prepares these files for review:

| File | What it tells Shaka |
| --- | --- |
| `.agents/agent-workflow.yml` | Which reviews to run and who merges |
| `.agents/bin/setup`, `test`, `validate` | How to prepare and check this project |
| `.agents/trusted-github-actors.yml` | Whose public GitHub comments it may read |
| `AGENTS.md` | Project instructions and constraints |

If checks have a useful faster first pass, `.agents/bin/validate-local` runs it.
An optional `.agents/bin/trigger-hosted-ci` starts staged CI after fixes. The
agent should explain which scripts fit the project in its setup PR.

To change a choice later, describe the result you want:

```text
$shaka Configure this repository to wait for all configured CI reviewers
before merging. Keep merge approval with me.
```

All settings and defaults are defined once in the [configuration reference](settings.md).
Shaka's own [configuration](../.agents/agent-workflow.yml) and
[scripts](../.agents/bin/) provide working examples. For an older installation,
see [upgrading](migration.md). Agents use the [setup procedure](agents/repository-setup.md).
