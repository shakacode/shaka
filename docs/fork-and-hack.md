# Fork Shaka and make it yours

Use a fork when you want to change Shaka's workflow, prompts, defaults, or helper
across your projects. For project-specific checks, reviewers, or merge choices,
[change settings](settings-guide.md) instead. To evaluate one upstream change,
[try its PR](trying-pr-versions.md) without maintaining a fork.

## Fork and install

Ask your agent:

```text
Fork https://github.com/shakacode/shaka and install my fork on a dedicated
branch. Keep upstream main available for syncing.
```

If Shaka is already installed, have the agent preserve its current revision
before switching it to your fork. Finish active tasks before changing versions,
then start a new chat. Use the same [prerequisites](manual-installation.md) as
a normal installation.

## Hack on it

Work in a separate clone, leaving the installation clean. Ask the agent to find
the existing workflow or helper that owns your change, rather than adding another
copy. See [Developing Shaka](../contributing/development.md#where-changes-belong).

```text
$shaka Change my fork so it asks for a design before implementing tasks with
open design choices. Show how to test it before changing my installation.
```

Keep tests for trust, merge decisions, and compatibility. A small instruction
edit can still change what the agent is allowed to do. Try the candidate on a
real task before adopting it everywhere.

## Keep your fork current

Ask your agent to inspect upstream changes, merge them into your custom
branch, and push it to your fork before updating the installation. Shaka does not pull upstream into a
fork automatically.

Merge rather than rewriting your installed branch's history. Updates only
fast-forward; a rebase can leave your installation on its old commit. If an
update refuses, keep that working installation and ask for a recovery plan
before changing history again.

## Contribute back

Start a focused PR from current upstream main, rather than including your fork's
other customizations. Include the task or [trial](trying-pr-versions.md) showing
why the change helps. Follow [Contributing](../CONTRIBUTING.md).

A candidate PR uses the rules already trusted on upstream main; its own edits
cannot choose how it is reviewed.

## Share your fork

Give a public fork or product its own name. The MIT license covers code and
docs, not the Shaka or ShakaCode names or logos. You may say it uses or is based
on Shaka; see [Names and logos](../README.md#names-and-logos).

## Troubleshooting

Ask the agent to inspect the installation state before repairing it. The common
causes are an origin URL different from the registered one, local edits in the
installed checkout, a rewritten branch, or links pointing at the wrong clone.
[Manual installation](manual-installation.md#verify-and-update) provides the
read-only status command when the skill itself is unavailable.
