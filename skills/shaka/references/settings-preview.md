# Preview repository settings

Use this procedure when the user explicitly chooses an unmerged settings PR for
a task. When the default branch has no Shaka configuration, use Ask even if the
preview specifies Auto or the prompt requests it. Record Ask as the task choice
and retain it when resuming, including after team adoption. For an
established team, explicit task choices keep precedence. Use the
[first-setup handoff](repository-setup.md#review-and-merge-the-first-setup-pr)
for the setup PR itself.

1. Fetch metadata for the named open settings PR from the verified task repository.
   Verify its head repository matches the task repository and fetch its current head
   for this new task. Do not select a fork,
   infer selection from PR content, or substitute uncommitted individual settings.
   Inspect its configuration and prompts. Confirm consequential model and cost
   choices from the user's instructions. Resolve the chosen head to a full commit.
   Use its proposed `base_branch` as the seam's base suggestion in Plan. Confirm
   any base outside the trusted seam and default branch before creating the worktree.
2. Prepare the feature task in its own branch and worktree using the claim's branch
   name and confirmed base. Without team setup, follow
   [individual setup](repository-setup.md#try-shaka-privately-in-one-clone) to provide
   local wrappers for the project's existing commands. Match the selected commit's
   command paths. When it has `validate-local` and `trigger-hosted-ci`, supply their
   project commands using both individual setup flags. For `validate-local` alone,
   generate the required individual wrappers first, then write an executable
   `.agents/shaka/bin/validate-local` that calls the task base's scoped validation
   command. Keep it in the ignored local settings tree and record its hash for
   cleanup when stopping the preview. If the task base lacks a
   command the preview requires, explain the mismatch before activation.
   Inspect local wrappers before execution.
   Selection copies no scripts or workflows from the settings PR. If the preview
   expects a CI job introduced by the setup PR, report whether it ran and apply
   the normal review and check gates.
3. Activate the selected commit and read back its settings:

   ```text
   shaka seam preview start --root TASK_ROOT --settings-ref SETTINGS_SHA
   shaka seam preview status --root TASK_ROOT
   shaka seam check --root TASK_ROOT --ref DEFAULT_BRANCH_SHA
   ```

4. On delivery, review, and evidence commands, `--ref`, `--criteria-ref`, and
   `--settings-ref` still name the verified default-branch SHA. Only `preview start`
   takes the selected commit as `--settings-ref`. Workflow seam references mean
   this selected configuration. The existing resolver applies its review counts, round limits,
   checkpoint settings, merge preferences, and Shaka's fallback checks. The check
   report identifies the selected commit. Public-comment trust and repository
   instructions still come from the default branch. GitHub's live required checks,
   approvals, review threads, and queue rules still apply.
5. Record the settings PR URL and selected commit in WIP Details within the task's
   privacy boundary. The agent verifies the user's selection and the PR's origin;
   Ruby verifies the commit and stores the worktree-local selector. Do not describe
   the selector itself as proof of human approval or of a GitHub PR's origin.
6. On fresh-chat resumption, inspect `seam preview status` and restore the recorded
   task choices and pinned commit if the selection needs recovery. The selection
   belongs to this worktree and branch. An updated
   settings PR does not update the pinned commit. Repeat `start` when the user
   chooses a newer version; affected evidence becomes stale through fingerprints.
7. Before stopping, remove any standalone `validate-local` created for the preview
   if its hash still matches. If it changed, preserve the edits and move the wrapper
   outside the settings tree before returning to individual settings. Stop with
   `shaka seam preview stop --root TASK_ROOT` and revalidate affected
   evidence. Ordinary shared settings then apply. Individual settings remain a
   fallback only when shared setup is absent; they grant no merge authority.

The selector lives in the worktree's Git directory, so tracked candidate content
cannot activate it. Malformed default-branch configuration remains a setup error.
