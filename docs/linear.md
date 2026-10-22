# Start a Shaka task from Linear

Open a Linear issue in Codex CLI with its prompt, repository, and suggested
branch already supplied. The optional macOS adapter opens Terminal and starts
Shaka's existing Codex launcher. You still choose the repository in Linear and
keep your usual Codex account and model settings.

Ask your agent:

```text
Set up Linear's custom script to open issues with Shaka in Codex CLI.
Use my installed Shaka checkout and preserve any existing Linear configuration.
```

You need macOS, the Linear desktop app, a working Codex CLI in a new Terminal
window, and a [source installation of Shaka](manual-installation.md). This
adapter uses macOS's system Ruby and Terminal. Shaka's launcher uses the Ruby
recorded by its installer. Windows, Linux, and other terminal apps are not
covered by this recipe.

## Configure Linear

In Linear, enable **Custom script** under **Settings → Code & reviews →
Configure coding tools**. Run it once to generate `~/.linear/coding-tools.json`.
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

## Try an issue

Select **Work on issue → Custom script**, then choose the issue's local Git
checkout. macOS may ask permission for Linear to control Terminal; allow it to
open the session. Codex starts with the installed Shaka workflow and the issue
context. Shaka uses the suggested tracker branch when claiming the task.

The issue's contents are passed as data; the adapter does not run commands from
the issue or change its Linear status. Normal Shaka review and merge choices
still apply. Opening Terminal confirms only the handoff: check the new window
to verify that Codex starts and recognizes the selected issue and repository.

If the window reports that `codex` is missing, install or expose Codex CLI in
your Terminal login environment. If macOS refuses to open Terminal, check
**System Settings → Privacy & Security → Automation** for the requesting app.
