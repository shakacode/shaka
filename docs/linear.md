# Start a Shaka task from Linear

Open a Linear issue in Codex CLI with its prompt, repository, and suggested
branch already supplied:

```text
Set up Linear's custom script to open issues with Shaka in Codex CLI.
Preserve my existing Linear configuration.
```

You need macOS, Linear desktop, Codex CLI working in a new Terminal window, and a
[source installation of Shaka](manual-installation.md). The optional adapter
uses Terminal; other operating systems and terminal apps need another integration.

## Configure Linear

Enable **Custom script** under Linear's **Settings → Code & reviews → Configure
coding tools**. Run it once to create the configuration, then ask your agent to
finish setup using your installed Shaka adapter.

If editing it yourself, set `openIssue.path` in `~/.linear/coding-tools.json` to the
absolute path of `examples/linear-codex` in your installed Shaka checkout. Pass
`LINEAR_PROMPT`, `LINEAR_WORK_DIR`, `LINEAR_ISSUE_IDENTIFIER`, and
`LINEAR_ISSUE_BRANCH_NAME` in the `openIssue.env` list. Keep unrelated entries.
[Linear's documentation](https://linear.app/docs/open-issues-with-custom-scripts)
explains the configuration format.

## Try an issue

Choose **Work on issue → Custom script**, then select the issue's local checkout.
Check the new Terminal window: Codex should recognize the issue and repository.
Opening a window alone does not establish that the task started.

If `codex` is missing, make Codex CLI available in your Terminal login environment.
If macOS blocks Terminal, check **System Settings → Privacy & Security → Automation**.
Opening the issue does not update its Linear status or authorize merging.
