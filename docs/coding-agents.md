# Coding agents

Shaka runs inside your coding agent, which supplies the model, permissions, and
tools. Install the skill once, then use it in your repositories.

| Coding agent | Start a task | Notes |
| --- | --- | --- |
| Codex | `$shaka` | Desktop app or CLI; the optional RCT skill needs desktop task tools |
| Claude Code | `/shaka` | Desktop app or CLI; Claude tower skills need desktop session tools |
| Cursor | `/shaka` | Start a new Agent chat after installation |
| OpenCode | `/shaka` | Use the installed skill in a session; an optional launcher is also available |
| Pi | Load the installed Shaka skill | Uses Pi's existing permissions; no separate Shaka launcher |

Start with the [installation prompt](getting-started.md). The installing agent
uses the [installation reference](../skills/shaka/references/installation.md)
for directories and environment-specific setup.

Want to add another coding agent? Submit a PR with installation instructions,
a demonstrated task, and any limitations. Keep environment-specific code separate
from the shared delivery workflow. See [contributing](../CONTRIBUTING.md).
