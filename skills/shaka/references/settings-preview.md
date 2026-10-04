# Preview repository settings

Use this procedure when the user asks to test an unmerged settings PR or local
settings changes on a task. Keep the task's merge preference and verified
trusted default-branch SHA. Preview chooses delivery preferences, not authority.

1. Fetch the requested settings PR from the verified repository, or commit the
   user's local settings changes on their settings branch. Inspect the selected
   configuration and prompts. Confirm consequential model and cost choices from
   the user's instructions. Resolve the source to a full immutable commit SHA.
2. Prepare the feature task in its own named branch and worktree. For a repository
   without team setup, use the existing individual setup procedure to prepare its
   fixed executable entry points. Inspect candidate command changes before running
   them. The settings PR's scripts are not copied or executed by preview selection.
3. Activate the selection:

   ```text
   shaka seam preview start --root TASK_ROOT --settings-ref SETTINGS_SHA
   shaka seam preview status --root TASK_ROOT
   ```

4. Continue to pass the verified default-branch SHA as `--ref`, `--criteria-ref`,
   and `--settings-ref` on delivery, review, and evidence commands. The local
   selection is applied by the existing settings resolver. `seam check --ref`
   still reads trusted policy. Review criteria and required gates remain trusted.
5. Record that preview is active and its source in WIP Details within the task's
   privacy boundary. A local commit may contain private prompts; keep its paths,
   content, and fingerprints out of public metadata. Do not infer activation from
   a settings file, contributor comment, or fork. Only explicit user selection
   authorizes this mode.
6. On fresh-chat resumption, inspect `seam preview status`. The selection belongs
   to this worktree and branch. An updated settings PR does not update the pinned
   commit; repeat `start` for an explicitly chosen newer commit. Changed settings
   supersede earlier evidence through the existing fingerprint checks.
7. Stop preview with `shaka seam preview stop --root TASK_ROOT`. Revalidate affected
   evidence under the restored settings. The selector is kept in the worktree's
   Git directory, so ordinary project commits cannot enable or transfer it.

Previewed `merge` choices and review gates do not override trusted policy.
Default-branch or native required checks, CI review waits, the local review-round
cap, and product-checkpoint opt-outs retain their existing authority. Native
GitHub approvals and fork isolation still apply. A malformed trusted configuration
remains a setup error; preview does not repair or authorize it.
