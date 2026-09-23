# Work with Shaka

Give Shaka a concrete task, an issue number, or a task URL. It works in the repository you opened; if the task points elsewhere, provide that checkout when asked. Include the behavior you expect and any constraint the agent should preserve.

```text
$shaka Fix search when the query contains an apostrophe. Add a regression test and bring the PR back for me to merge.
```

Shaka recommends a model and effort, then uses the repository's instructions and scripts to implement and verify the change. For behavior changes, it tries to see the failure before fixing it. It publishes a PR with a walkthrough and addresses review findings. The PR identifies the tested commit, checks, and any missing evidence.

## Choose the stopping point

- **Ask:** Shaka finishes the PR and tells you when GitHub's merge control is ready for the reviewed commit. You merge it.
- **Auto:** Shaka merges when required checks and approvals pass, unless a risky decision needs you.
- **PR only or review only:** State that scope in the task. Shaka stops there.

If you already chose a merge preference for the repository or task, Shaka reuses it. A task may pause while you choose a model or answer a consequential question. Reply in the same task to continue.

## Read the result

Start with the PR summary for the outcome, decision, blockers, and check results. Use its code walkthrough to see why the implementation changed. A recovery note on an unfinished PR records where the task stopped so the same task or a new one can continue. Shaka removes that note after a confirmed outcome, except when you make the final Ask-mode merge click.

If a check fails or a reviewer finds a defect, Shaka repairs and verifies the new commit. The final response links the PR and says what remains. Token and model figures are estimates or partial records when the host cannot attribute every contribution; [usage reporting](../agents/usage-reporting.md) explains the labels.

For large tasks, ask Shaka to propose a useful PR split. Each PR should have its own validation and review. For current host limits, see [host support](host-support.md).
