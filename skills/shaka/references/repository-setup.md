# Configure a repository for Shaka

Use this procedure when asked to set up Shaka in a repository. The
[configuration reference](../../../docs/settings.md) defines every setting
and standard script; keep those definitions there.

1. Verify the repository identity, visibility, default branch, and `AGENTS.md`.
2. Inspect existing setup, test, validation, and CI commands. Reuse them in small
   `.agents/bin/` wrappers; include any existing fast validation or staged CI
   capability when useful. Shaka's own [scripts](https://github.com/shakacode/shaka/tree/main/.agents/bin) are examples.
3. Establish review jobs from their actual workflows and merge authority from
   the user's instructions. Keep Ask when no broader authority exists. Check that
   GitHub exposes required checks enforced for the account that will merge.
4. Prepare the files with the trusted installed helper. For an existing
   configuration, use the [migration procedure](migration.md).
5. Inspect the generated diff, run its checks, and commit it. Follow
   [the first setup PR](#review-and-merge-the-first-setup-pr) path to review it
   before publishing, then hand it to the maintainer before relying on its new policy.

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
conflicting files. GitHub must expose required checks enforced for the account
that will merge.


## Review and merge the first setup PR

When the default branch has no `.agents/agent-workflow.yml`, every `--ref` command
stops with `Cannot read .agents/agent-workflow.yml at SHA`. That includes
`seam check`, `reviewer`, and `merge`. The refusal is correct: the setup PR must not
grant itself review or merge policy. Do not work around it with the candidate's
own YAML. Handle that one PR this way:

1. Validate with `shaka seam check --root . --local` and the new wrapper scripts.
   The local check proves syntax only.
2. Choose the local reviewer by hand with the
   [usual selection rules](review.md#choose-a-local-reviewer), treating the
   reviewers `shaka review run` supports as the list, in this order:
   `anthropic/claude`, `openai/codex`, `xai/grok`. The same-provider and
   fresh-session fallbacks still apply. `shaka review run` needs no seam.
3. Fix its findings, then push and open the setup PR. Record in the PR that no
   trusted seam existed, so the reviewer came from this fixed order rather than
   from `shaka reviewer`.
4. Do not run `shaka merge`, and do not merge with `gh pr merge`. Once checks and
   review pass, name the head SHA and hand the PR to the maintainer, who merges it
   on GitHub under the repository's existing protection.

After that merge, resolve the new default-branch commit and use it as `--ref` for
every later task.


## What `seam init` writes

Supply `--root`, `--setup-command`, `--test-command`, `--validate-command`, and
`--review-policy`. Unless review policy is `none`, supply `--ci-review-job` for
an actual job; repeat it for additional jobs. Confirm that GitHub enforces at
least one observable required check before initialization.

The initializer writes the three required wrappers, `.agents/shaka.md`, and YAML
with `version`, `review`, `merge`, and the default `branches.name`. It defaults to
Ask. Add `--merge-preference auto` only with established authority, `--base-branch`
for another base. Add optional reviewer entries, `repo_prefix`, and WIP settings
by editing the YAML afterward. Point to requirements from `AGENTS.md`.

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
