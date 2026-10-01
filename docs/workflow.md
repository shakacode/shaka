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
| Posted review evidence covering the merged commit, or a stated waiver | Ruby merge helper, when the agent merges and review is required |
| Sentence, paragraph, and total length of PR descriptions and walkthroughs | Ruby publication helpers, using [`prose_limits`](settings.md#prose_limits) |
| Adequate tests, useful screenshots, and how thorough the review was | Agent judgment and review |
| Keeping private information out of publications | Agent inspection; no automated privacy scan |

The merge helper confirms that review posted on the PR covers the commit it
merges; it cannot tell whether the review was careful or its findings were fixed.
A merge you make yourself on GitHub skips this check, and so does
`review.required: none`. See [`review.required`](settings.md#reviewrequired) for
what counts as review evidence.

`shaka enforcement` lists rules enforced by code and those that rely on the agent.
Its [source map](../skills/shaka/config/enforcement.yml) describes enforcement;
it does not prove a task followed every step.

## Workflow secret and variable names

A workflow that names a secret your repository lacks fails only after it merges.
When a PR adds or changes a file in `.github/workflows/`, `shaka pr` and
`shaka handoff` report each `secrets.NAME` and `vars.NAME` the repository
cannot see. Under `merge.preference: auto`, a missing name stops the merge. Under
`ask`, the handoff names it and the merge stays your decision.

For example, a PR adds `${{ secrets.DEPLOY_KEY }}` to a deploy job, and no
repository, organization, or environment secret has that name. The handoff reports
`missing workflow names secrets.DEPLOY_KEY`, so you can add the secret before merging.

Ruby reads names and never values. It looks for a name in the repository, in the
organization secrets and variables shared with it, and in the environment a job
names. A name is `unverified`, and does not stop a merge, when
GitHub answers 403 or 404 for a list or a workflow file. The token may lack
permission, so the check cannot tell a missing name from a hidden one.

The check matches text. It does not evaluate workflows, so it has these limits:

- It finds only the dot form. `secrets['DEPLOY_KEY']` and names built by an
  expression are not found, and a workflow that uses only those reports `clear`.
- A name in a YAML comment counts as a reference.
- An environment set by an expression, such as `${{ inputs.target }}`, is looked up
  under that literal text. GitHub returns 404, and the job's names are `unverified`.
- A workflow that is not valid YAML is still scanned, and its names are `unverified`.
- `secrets.GITHUB_TOKEN` is skipped.
- A reusable workflow (`on: workflow_call`) gets its names from whichever workflow
  calls it, so a name this repository lacks is `unverified`, not `missing`. When `workflow_call` is
  the only trigger, a secret declared under `on.workflow_call.secrets` is skipped.
- A job's environment covers every name in that job. GitHub reads some keys, such as
  `runs-on`, before the environment applies, so a name used there can report `clear`
  and still be absent at run time.
- Workflows the PR leaves unchanged or deletes are not checked. Composite actions
  and reusable workflows in other repositories are not checked.

Shaka prints names in command output and does not post them to the PR. The watcher
(`shaka pr watch`) skips this check, because it waits only on checks and comments.

## Customize the instructions

Put commands and merge choices in [settings](settings.md). Use `AGENTS.md` for
project constraints, review criteria, and writing preferences.

To change Shaka, edit the workflow and references in a fork. Update the enforcement
map for changed rules, run the checks, and submit a PR. Install the reviewed version
explicitly; a project branch cannot replace the skill used to review itself.
