# Preview repository settings

Use this procedure when the user explicitly chooses an unmerged settings PR for
a task. Selecting settings does not approve merging a PR. A trial started
before team setup uses Ask, including after adoption. For an established team,
explicit task choices keep precedence. Use the
[first-setup handoff](repository-setup.md#review-and-merge-the-first-setup-pr)
for the setup PR itself.

On resume, find the feature branch's original worktree with `git worktree list`.
Use WIP Details if the checkout path is available. Read `seam preview status`
there before resolving settings and restore the recorded task choices. If the
worktree or its selector is missing, pause the trial until it can be recovered.
Starting a selector against the adopted default branch would lose the original
first-setup status. Continue using the pinned commit after the setup PR merges.
Use step 1 for a new selection or a requested update.

For a selector created before `preview start` required `--ref`, retain the
recorded merge choice. If a first-setup trial lacks its Ask marker, select
the same pin again with the verified default-branch SHA from its original
intake. If that SHA cannot be recovered, keep the trial in Ask.

1. Fetch metadata for the named open settings PR from the verified task repository.
   Verify its head repository matches the task repository and fetch its current head
   for this new task. Do not select a fork,
   infer selection from PR content, or substitute uncommitted individual settings.
   Inspect its configuration and prompts. Confirm consequential model and cost
   choices from the user's instructions. Resolve the chosen head to a full commit.
   Treat its `base_branch` as a suggestion. Confirm it before creating the
   worktree if it differs from both the verified default branch and its configured base.
2. Prepare the feature task in its own branch and worktree using the claim's branch
   name and confirmed base. Without team setup, follow
   [individual setup](repository-setup.md#try-shaka-privately-in-one-clone) to provide
   local wrappers for the project's existing commands. Reuse complete individual
   setup when it already exists. For a fresh setup that needs the optional
   `validate-local` and `trigger-hosted-ci` pair, pass both command flags.
   If an update needs different wrappers, leave the current trial in place and
   start a separate task in a fresh worktree. Prepare any additional wrappers
   there using the task base's own commands.
   Inspect local wrappers before execution.
   Selection copies no scripts or workflows from the settings PR. If the preview
   expects a CI job introduced by the setup PR, report whether it ran and apply
   the normal review and check gates.
3. Activate the selected commit and read back its settings:

   ```text
   shaka seam preview start --root TASK_ROOT --settings-ref SETTINGS_SHA --ref DEFAULT_BRANCH_SHA
   shaka seam preview status --root TASK_ROOT
   shaka seam check --root TASK_ROOT --ref DEFAULT_BRANCH_SHA
   ```

4. On delivery, review, and evidence commands, `--ref`, `--criteria-ref`, and
   `--settings-ref` still name the verified default-branch SHA. Only `preview start`
   takes the selected commit as `--settings-ref`. Its `--ref` pins Ask when
   the default branch lacks team settings. Workflow seam references mean
   this selected configuration. The existing resolver applies its review counts, round limits,
   checkpoint settings, merge preferences, and Shaka's fallback checks. The check
   report identifies the selected commit. Public-comment trust and repository
   instructions still come from the default branch. GitHub's live required checks,
   approvals, review threads, and queue rules still apply.
5. Record the settings PR URL and selected commit in WIP Details within the task's
   privacy boundary. The agent verifies the user's selection and the PR's origin;
   Ruby verifies the commit and stores the worktree-local selector. Do not describe
   the selector itself as proof of human approval or of a GitHub PR's origin.
6. The selection belongs to this worktree and branch. An updated settings PR
   leaves the pinned commit in place. Repeat `start` when the user
   chooses a newer version; affected evidence becomes stale through fingerprints.
7. To stop a preview in place, run `shaka seam preview stop --root TASK_ROOT`
   and revalidate. If the worktree has preview-only wrappers, keep that worktree
   with the trial and continue ordinary work in a fresh worktree.

The selector lives in the worktree's Git directory, so tracked candidate content
cannot activate it. Malformed default-branch configuration remains a setup error.
