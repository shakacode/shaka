# Workflow and enforcement

Shaka gives your agent an ordered process. Your repository supplies the commands
and constraints; the agent does the work and reports the evidence.

| Step | Result |
| --- | --- |
| Intake | Confirm the task, repository, ownership, and merge preference |
| Plan | Assess value, scope, risk, model, and effort |
| Implement | Reproduce bugs or test new behavior, then make the change |
| Verify | Run local checks, review independently, and fix findings |
| Explain | Publish the PR, walkthrough, evidence, and usage |
| Review | Handle GitHub review findings and required checks |
| Finish | Merge when authorized, or hand the reviewed PR back for your merge |

The [workflow definition](../skills/shaka/config/workflow.yml) contains the
instructions. `shaka workflow` validates and prints them. Supporting procedures
live in the [skill references](../skills/shaka/references/README.md), loaded when
needed rather than copied into every task.

## What is enforced

| Responsibility | Enforcement |
| --- | --- |
| Valid settings, command paths, and values | Ruby configuration checks |
| Which public comment bodies an agent reads | Ruby allowlist and provenance checks |
| Reviewed commit and required GitHub merge conditions | Ruby merge helper and GitHub protection |
| Whether testing is adequate, screenshots show the right state, or a review is genuinely independent | Agent judgment and review |
| Whether publication contains private information | Agent inspection; no general-purpose privacy scanner |

`shaka enforcement` shows which workflow rules have code enforcement and which
rely on the agent. Its [source map](../skills/shaka/config/enforcement.yml) is an
audit aid, not proof that every step happened. Adding a rule to prose does not
make it enforced by Ruby.

## Customize the instructions

Put repository commands and merge choices in [settings](settings.md). Use
`AGENTS.md` for project constraints, review criteria, and writing preferences.

For changes to Shaka itself, work in a fork and edit the workflow and its
references. Update the enforcement map when changing a rule, run the checks, and
submit a PR. Install the reviewed version deliberately; a project branch cannot
replace the trusted skill used to review itself.
