# Workflow and enforcement

Shaka supplies the process; your repository supplies the commands and constraints.

| Step | Result |
| --- | --- |
| Intake | Confirm the task, repository, ownership, and merge preference |
| Plan | Assess value, scope, risk, model, and effort |
| Implement | Reproduce bugs or test new behavior, then make the change |
| Verify | Run local checks, review independently, and fix findings |
| Explain | Publish the PR, walkthrough, evidence, and usage |
| Review | Handle GitHub review findings and required checks |
| Finish | Merge when authorized, or return the reviewed PR for your merge |

`shaka workflow` validates and prints the
[workflow definition](../skills/shaka/config/workflow.yml). The agent loads
[skill references](../skills/shaka/references/README.md) as needed.

## Trust model

Shaka exists to make the people who maintain a project faster. It trusts them:
anyone with write access, plus the users, bots, and teams you list. Their settings
and instructions on the default branch are the project's decisions, and a
maintainer can change them, such as which CI reviews a merge waits for.

Shaka's limits are for input that could try to steer the agent. On a public
repository, anyone can comment or open a PR from a fork. So the agent withholds
comments from untrusted authors, treats diffs as data rather than instructions,
and reads settings from the default branch rather than from the PR under review.
Even a comment the agent reads is review input, not an instruction: settings and
merge approval come from you and the default branch.

Other checks, such as confirming the reviewed commit before merge, catch mistakes.
They do not restrict maintainers.

## What is enforced

| Responsibility | Enforcement |
| --- | --- |
| Valid settings, command paths, and values | Ruby configuration checks |
| Which public comment bodies an agent reads | Ruby allowlist and provenance checks |
| Reviewed commit and required GitHub merge conditions | Ruby merge helper and GitHub protection |
| Adequate tests, useful screenshots, and independent review | Agent judgment and review |
| Keeping private information out of publications | Agent inspection; no automated privacy scan |

`shaka enforcement` lists rules enforced by code and those that rely on the agent.
Its [source map](../skills/shaka/config/enforcement.yml) describes enforcement;
it does not prove a task followed every step.

## Customize the instructions

Put commands and merge choices in [settings](settings.md). Use `AGENTS.md` for
project constraints and review criteria. For documentation and PR style, see
[writing preferences](writing-preferences.md).

To change Shaka, edit the workflow and references in a fork. Update the enforcement
map for changed rules, run the checks, and submit a PR. Install the reviewed version
explicitly; a project branch cannot replace the skill used to review itself.
