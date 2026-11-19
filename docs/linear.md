# Start a Shaka task from Linear

Open a Linear issue in Codex CLI with the issue and project already selected.
You need macOS, the Linear desktop app, Codex CLI, and a
[source installation of Shaka](manual-installation.md). The integration opens
Terminal and keeps your usual Codex account and model settings.

## Configure Linear

Ask your agent:

```text
Set up Linear to open issues with Shaka in Codex CLI. Keep my existing Linear settings
```

In Linear, enable **Custom script** under **Settings → Code & reviews →
Configure coding tools**. The agent connects the script to your installed copy
of Shaka. See the adapter configuration below and
[Linear's custom script guide](https://linear.app/docs/open-issues-with-custom-scripts).

## Try an issue

Choose **Work on issue → Custom script**, then select the local folder for the
project. If macOS asks, allow Linear to open Terminal. In the new window, check
that Codex started and recognizes the issue and project before it begins work.
Shaka uses the branch name suggested by Linear. Your usual review and merge
choices apply.

## Fix a setup problem

| What you see | What to check |
| --- | --- |
| Terminal opens but cannot find Codex | Ask the agent to check that Codex CLI is available in a new Terminal window and signed in. |
| Linear cannot open Terminal | Check macOS **System Settings → Privacy & Security → Automation** for Linear. |
| Codex opens the wrong project or issue | Stop and choose the correct issue and local folder. |

If the setup still fails, tell your agent what you selected and paste the error.

<a id="configure-the-adapter"></a>

<details>
<summary>Adapter configuration</summary>

Run the [custom script](https://linear.app/docs/open-issues-with-custom-scripts) once to generate `~/.linear/coding-tools.json`.
Edit its `openIssue` entry to match this example, retaining unrelated entries:

```json
{
  "openIssue": {
    "path": "/Users/YOU/.local/share/shaka/source/examples/linear-codex",
    "env": [
      "LINEAR_PROMPT",
      "LINEAR_WORK_DIR",
      "LINEAR_ISSUE_IDENTIFIER",
      "LINEAR_ISSUE_BRANCH_NAME"
    ]
  }
}
```

Replace `/Users/YOU/.local/share/shaka/source` with your Shaka checkout's absolute
path. Keep that checkout outside the repositories Codex edits. The adapter
requires all four values and refuses a missing or relative working directory.
[Linear's custom script documentation](https://linear.app/docs/open-issues-with-custom-scripts)
describes how Linear supplies them.

The adapter treats issue content as data, and does not change issue status.
Check the new Codex window for the selected project and issue.

</details>
