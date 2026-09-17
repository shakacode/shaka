# Install and complete your first task

Shaka guides an agent from a task description to a tested, reviewed GitHub PR.
Start with a small change in a repository you trust, such as fixing a search test
or correcting a broken link in a documentation site.

## Prerequisites

You need Git, Ruby 3.4, authenticated [GitHub CLI](https://cli.github.com/),
and a signed-in Codex app, [Codex CLI](https://learn.chatgpt.com/docs/codex/cli#getting-started),
[Claude Code](https://code.claude.com/docs/en/setup), or Cursor desktop.
Check `git --version`, `ruby --version`, and `gh auth status` in your terminal;
run `gh auth login` if needed. Codex terminal users also need `codex --version` to work;
Claude Code users need `claude --version`.
The skill uses no development gems. Keep your application's own Ruby version.

Your repository's `AGENTS.md` should name setup, validation, and review commands,
the base branch, and who may authorize merging. Shaka reads the scripts and offers
a small addition if required instructions are missing. Existing instructions count.
To merge, GitHub must enforce required checks for the acting account, allow squash
merges, and satisfy required approvals. Otherwise, Shaka explains the blocker on the PR.

## Install in the Codex app

Keep this trusted source checkout outside the repositories you will edit.
If it already exists, follow **Upgrade** below. First, get the source:

```bash
mkdir -p "$HOME/agent-tools"
git clone https://github.com/shakacode/shaka.git "$HOME/agent-tools/shaka"
```

Inspect the cloned `bin/install`, `skills/shaka/`, and `skills/rct/` source. Then,
with Ruby 3.4 available, install the skills:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills" --with-rct
```

<a id="use-shaka-in-the-codex-app"></a>

Open a Codex task in the repository you want to change. The skills should appear on
the next turn; restart Codex if it does not. Installation preserves other skills
and settings. The task uses the app's existing permissions; this installation does
not create a sandbox for untrusted contributor code.

<a id="use-shaka-in-claude-code"></a>

## Install in Claude Code

After cloning the source as above, install into Claude Code's user skills directory:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.claude/skills"
```

Start Claude Code in the repository you want to change, and use `/shaka` wherever
this guide shows `$shaka`. Claude Code runs your personal skill instead of a
same-named skill in a repository's `.claude/skills`, and the skill stops if it was
loaded from inside the checkout. Keep the trusted source outside any `--add-dir`
directory. Your usual permission mode applies; installation adds no sandbox.

<a id="use-shaka-in-cursor"></a>

## Install in Cursor

After cloning the source as above, install into Cursor's user skills directory:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.cursor/skills"
```

A successful installer message only means the symlink exists. Start a **new** Agent
chat and confirm `/shaka` appears in that chat's skill list before sending a task.
Use `/shaka` wherever this guide shows `$shaka`. A chat that started before the
link existed will not pick it up. Do not copy `shaka` into a project
`.cursor/skills` directory inside a candidate checkout. `shaka work` starts Codex
and is not a Cursor launcher. Complete Cursor delivery remains unverified.

To persist native token records, add this command to the `stop` array in
`~/.cursor/hooks.json` without removing other hooks:

```json
{
  "command": "skills/shaka/scripts/cursor-usage-hook"
}
```

User-level hooks run with `~/.cursor` as the working directory, so that path
reaches the skill installed into `~/.cursor/skills`.

The hook writes allowlisted usage metadata only. Start a new Agent chat after
changing hooks. `shaka usage` then reads `CURSOR_CONVERSATION_ID` against
`~/.cursor/shaka-usage`. See [usage reporting](usage-reporting.md#what-the-cursor-reader-includes).

## Complete your first task

Send this, replacing the example with your issue number, task URL, or description:

```text
$shaka Fix the failing search test. Bring the finished PR back for my approval.
```

An issue number uses the current repository. A URL can identify another one;
Shaka asks for its checkout if needed. If it cannot read the task, paste the
requirements. Private task content stays out of public PRs unless you allow sharing.

The agent reads the task and recommends a model and effort. It pauses for **ready**
unless you explicitly supplied matching model and effort and clearly authorized an
immediate start, with those settings active in the host. Unavailable or conflicting
settings still require one user action. It implements on a branch, runs your repo's
checks, opens a PR with a walkthrough, and handles review findings. You get the PR
link, validation result, and any blocker; detailed evidence is on the PR.

The example chooses **Ask**: you make the merge decision after the PR is ready.
To choose **Auto**, say “Merge when checks and required approvals pass” instead.
Existing merge authority is reused; review-only and PR-only requests stop there.
Auto still waits for required approvals and raises risky decisions. If a task stops
at a blocker, resume it to continue; it does not keep trying in the background.

## Add extensions

Shaka runs alone by default. To add advice from another installed skill at a fixed point,
name it in your repository's trusted `AGENTS.md` or in your own global instructions:

```markdown
Shaka extensions:
  after-green: /code-review
  before-merge: compound-engineering:ce-code-review mode:agent
```

Use any of `after-plan`, `after-green` (validation passed), `before-walkthrough`,
`after-review` (findings collected), or `before-merge`. Write each skill name exactly as
your host lists it, with any arguments the skill accepts. Shaka first resolves the name to
a skill installed alongside Shaka itself, never one inside your checkout or the task's
session and temporary directories; anything else counts as missing. It invokes the skill
through the host, treats what comes back as advice, and records the result and its
disposition in the next thing it publishes for that head: the walkthrough, the PR
description, or the final report. If Shaka acts on the advice, it verifies again before
publishing. A missing or failed extension is reported and the task continues. An extension
cannot weaken a gate, grant authority, or take over a step Shaka owns, so a skill that
commits, pushes, opens PRs, or merges on its own is an alternative to Shaka, not an
extension. An extension's own network use is your responsibility. Session prose styles
such as terse chat modes never change published PR text.

## Use a fresh terminal session

After cloning the source, install into a dedicated directory outside your repositories:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/agent-tools/shaka-pilot/skills"
export PATH="$HOME/agent-tools/shaka-pilot/skills/shaka/scripts:$PATH"
shaka work --repo /path/to/your/repository "Fix the failing search test. Use Ask."
```

Replace the repository path. This starts interactive Codex with the same task flow.
If your application's version manager selects another Ruby, run the command from
outside that checkout with Ruby 3.4 selected. Add the `PATH` line to your shell
startup file to make `shaka` available in new terminals.
The launcher uses a separate temporary session and native approval prompts;
[host support](host-support.md#startup-boundary-and-current-validation) records its tested limits.

## Upgrade

Set `shaka_source` to your existing trusted checkout. Inspect its remote and local
changes first; it should point to `shakacode/shaka`. Preserve local edits and resolve
conflicts before switching or pulling.

```bash
shaka_source="$HOME/agent-tools/shaka"
git -C "$shaka_source" remote -v
git -C "$shaka_source" status --short
git -C "$shaka_source" switch main
git -C "$shaka_source" pull --ff-only
"$shaka_source/bin/install" --skills-dir "$HOME/.agents/skills" --with-rct
```

Start a fresh task after upgrading. `--with-rct` is for the Codex app's native task
and project tools. Omit it for a terminal install and pass your dedicated skills
directory instead; for Claude Code, pass `$HOME/.claude/skills`; for Cursor, pass
`$HOME/.cursor/skills`. Earlier installs used `agent-workflows-v2` or
`shakacode-workflows` source directories: keep that location and use it above.
Inspect old `sw` and `aw` symlinks and unlink only those belonging to this installation.
Replace any old `sw/scripts` shell `PATH` entry with the `shaka/scripts` path above.

## Remove or roll back

Inspect both links. If they point to your Shaka installation, remove them:

```bash
test -L "$HOME/.agents/skills/shaka" && unlink "$HOME/.agents/skills/shaka"
test -L "$HOME/.agents/skills/rct" && unlink "$HOME/.agents/skills/rct"
```

Use your dedicated skills directory for a terminal install and remove its shell
`PATH` entry. For Claude Code, use `$HOME/.claude/skills`. For Cursor, use
`$HOME/.cursor/skills`. Inspect and remove any old `sw` or `aw` links individually; preserve
unrelated skills and real directories. To roll back, remove the verified links,
check out the prior trusted source revision, and run that revision's installer.
