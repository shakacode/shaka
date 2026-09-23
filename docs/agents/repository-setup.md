# Configure a repository for Shaka

Use this procedure when asked to set up Shaka in a repository. The
[configuration reference](../reference/settings.md) defines every setting
and standard script; keep those definitions there.

1. Verify the repository identity, visibility, default branch, and `AGENTS.md`.
2. Inspect existing setup, test, validation, and CI commands. Reuse them in small
   `.agents/bin/` wrappers; include any existing fast validation or staged CI
   capability when useful. Shaka's own [scripts](../../.agents/bin/) are examples.
3. Establish review jobs from their actual workflows and merge authority from
   the user's instructions. Keep Ask when no broader authority exists. Check that
   GitHub exposes required checks enforced for the account that will merge.
4. Prepare the files with the trusted installed helper. For an existing
   configuration, use the [migration procedure](migration.md).
5. Inspect the generated diff, run its checks, and publish a setup PR. Merge the
   setup through the repository's existing rules before relying on its new policy.

For a repository whose commands and review job match this example, the initializer
is:

```bash
"$HOME/agent-tools/shaka/skills/shaka/scripts/shaka" seam init \
  --root /path/to/repository \
  --setup-command "bin/setup" \
  --test-command "bundle exec rake test" \
  --validate-command "bin/validate" \
  --review-policy meaningful_changes \
  --ci-review-job claude-review
```

Replace every example command with the repository's actual command. If no CI
review job exists, use `--review-policy none` and omit `--ci-review-job`. Meaningful
implementation still gets local review. The initializer refuses to overwrite
conflicting files. Review and merge the setup PR before relying on its policy.
GitHub must expose required checks enforced for the account that will merge.


## What `seam init` writes

Supply `--root`, `--setup-command`, `--test-command`, `--validate-command`, and
`--review-policy`. Unless review policy is `none`, supply `--ci-review-job` for
an actual job; repeat it for additional jobs. Confirm that GitHub enforces at
least one observable required check before initialization.

The initializer writes the three required wrappers, `.agents/shaka.md`, and YAML
with `version`, `review`, `merge`, and the default `branches.name`. It defaults to
Ask. Add `--merge-preference auto` only with established authority, `--base-branch`
for another base, or `--plan` for an existing plan. Add optional reviewer entries,
`repo_prefix`, and recovery settings by editing the YAML afterward.

Command arguments are parsed as argument lists. Put pipelines and other compound
shell behavior in repository scripts rather than in command flags.


## Validate the configuration

While editing, check the current checkout:

```bash
shaka seam check --root . --local
```

For a task's trusted policy, resolve the repository's default branch to an
immutable commit and use that SHA:

```text
shaka seam check --root . --ref FULL_DEFAULT_BRANCH_SHA
```

A PR's proposed policy cannot grant that PR new authority. `--ref` reads policy
and optional script availability from the trusted commit, then validates the
scripts in the candidate checkout. Inspect changes to those scripts before
executing them. `--local` grants no policy or merge authority; omitting both
flags performs the same candidate check with a warning. Combining them is an error.

The JSON output includes derived `commands` and `validation` fields. They describe
the result; do not copy them into the YAML. Even trusted output reports
`grants_merge_authority: false`: the agent still establishes authority and checks
live GitHub state.
