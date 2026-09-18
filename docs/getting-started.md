# Install and complete your first task

Shaka guides an agent from a task description to a tested, reviewed GitHub PR.
Start with a small change in a repository you trust, such as fixing a search test
or correcting a broken link in a documentation site.

## Prerequisites

You need Git, Ruby 3.4, authenticated [GitHub CLI](https://cli.github.com/),
and a signed-in Codex app, [Codex CLI](https://learn.chatgpt.com/docs/codex/cli#getting-started),
[Claude Code](https://code.claude.com/docs/en/setup), [Cursor](https://cursor.com/docs/cli/installation)
desktop, or [OpenCode](https://opencode.ai).
Check `git --version`, `ruby --version`, and `gh auth status` in your terminal;
run `gh auth login` if needed. Codex terminal users also need `codex --version` to work;
Claude Code users need `claude --version`; OpenCode users need `opencode --version`.
The skill uses no development gems. Keep your application's own Ruby version.

Shaka's installed `SKILL.md` is a small trust bootstrap. It invokes `shaka workflow`,
which strictly validates and renders the packaged workflow configuration before the
agent acts. Your repository's separate `.agents/agent-workflow.yml` names executable
setup, validation, and focused-test paths, the base branch, review policy, and merge
authority. Shaka validates this contract and helps add it when it is missing.
[Settings](settings.md) documents every key, its allowed values, and what fails when
one is wrong. Keep long
commands in repository scripts and human-only constraints in `AGENTS.md`.
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

To organize work across repositories, add the desktop app's control tower skills:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.claude/skills" --with-claude-towers
```

Send `/mct-claude` in the session you want to hold the master role, then
`/rct-claude` in a session opened in each repository a tower should own. These skills
use the desktop app's session tools and stop with a setup error in a terminal
`claude`. See the control-tower guide for the
[master](control-towers.md#establish-a-master-tower-in-claude-code) and
[repository](control-towers.md#establish-a-repository-tower-in-claude-code) roles.

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

<a id="use-shaka-in-opencode"></a>

## Install in OpenCode

After cloning the source as above, install into OpenCode's canonical user skills directory:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.config/opencode/skills"
```

OpenCode also reads the compatibility directories `~/.claude/skills` and
`~/.agents/skills`; prefer the canonical path so the installation is not shadowed
by another host's copy and a project-local `.opencode/skills` override stays
explicit. Start a **new** OpenCode session in the repository you want to change
and confirm `shaka` appears in that session's skill list before sending a task.
Use `/shaka` wherever this guide shows `$shaka`. Do not copy `shaka` into a project
`.opencode/skills` directory inside a candidate checkout. Keep the trusted source
outside the working directory. Your usual permission mode applies; installation
adds no sandbox. `shaka work --host opencode` starts the interactive TUI from a
terminal with the same task flow. OpenCode publishes no session identifier to the
commands it runs, so name the session yourself: `shaka usage --host opencode --session
ID` exports it, and `opencode session list` prints the identifiers.
See [usage reporting](usage-reporting.md#what-the-opencode-reader-includes).

## Initialize a repository seam

Installing the skill does not write policy into every repository. Initialize each
repository explicitly after identifying its real scripts, checks, review provider,
and merge preference:

```bash
"$HOME/.agents/skills/shaka/scripts/shaka" seam init \
  --root /path/to/repository \
  --base-branch main \
  --setup-command "bin/setup" \
  --validate-command "bin/validate" \
  --test-command "bundle exec rake test" \
  --review-policy meaningful_changes \
  --review-check claude-review \
  --required-check validate
```

The command creates `.agents/agent-workflow.yml` and small executable wrappers
under `.agents/bin/`. Its default merge preference is **Ask**. Add
`--merge-preference auto` only when that is the repository's established authority;
choose `--review-policy always`, `meaningful_changes`, or `none`, and supply
`--review-check` unless the policy is `none`. Also
provide at least one `--required-check` and repeat it for every required GitHub check.
Repeat `--trusted-action` as needed, and use `--plan` for an existing
repository-relative plan. Commands are parsed as argument lists, so put shell pipelines
or other compound behavior in a repository-owned script.

Initialization validates every input before writing. It is safe to repeat when the
generated files are unchanged and refuses to overwrite a repository-owned file or
symlink. Use the path printed by `bin/install` when you installed elsewhere.

## Check your setup

`shaka doctor` reports, in one pass, whether this machine can run the workflow and
publish a complete pull request. It is read-only: it changes no repository and no
setting.

```bash
"$HOME/.agents/skills/shaka/scripts/shaka" doctor --root /path/to/repository
```

Each check is `HEALTHY`, `DEGRADED`, or `FAILED`, worst first, with the next step for
anything that is not healthy. A `FAILED` check blocks publication and the command exits
non-zero; a `DEGRADED` check still publishes, with something missing from the result.

Doctor fails rather than guessing when it cannot establish what it checks. A repository it
cannot resolve as writable fails, whatever the reason, so a passing report always means
verified write access. A missing or invalid repository seam fails too. An unset
`SHAKA_MACHINE_ALIAS` only degrades: the provenance row reads `UNKNOWN`. Set it to a short
deliberate token such as `m5`. Doctor also degrades when the alias *is* this machine's own
name, because publication accepts that value and would put your machine name in every public
pull request.

Doctor names the host it checked usage sources for. Detection falls back to Codex when a host
exposes no session identifier, so OpenCode users should pass `--host opencode`.

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
Pass `--host opencode` instead to start the OpenCode TUI in that repository;
OpenCode keeps its own sessions outside the checkout, so no separate session
directory is created.

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
and project tools; Claude Code desktop uses `--with-claude-towers` instead. Omit both
for a terminal install and pass your dedicated skills
directory instead; for Claude Code, pass `$HOME/.claude/skills`; for Cursor, pass
`$HOME/.cursor/skills`; for OpenCode, pass `$HOME/.config/opencode/skills`. Earlier installs used `agent-workflows-v2` or
`shakacode-workflows` source directories: keep that location and use it above.
Inspect old `sw` and `aw` symlinks and unlink only those belonging to this installation.
Replace any old `sw/scripts` shell `PATH` entry with the `shaka/scripts` path above.

## Remove or roll back

Inspect every link this installation created. If they point to your Shaka
installation, remove them:

```bash
test -L "$HOME/.agents/skills/shaka" && unlink "$HOME/.agents/skills/shaka"
test -L "$HOME/.agents/skills/rct" && unlink "$HOME/.agents/skills/rct"
```

A Claude Code install with towers puts all three of its links in that host's own
directory, so remove them there instead:

```bash
test -L "$HOME/.claude/skills/shaka" && unlink "$HOME/.claude/skills/shaka"
test -L "$HOME/.claude/skills/mct-claude" && unlink "$HOME/.claude/skills/mct-claude"
test -L "$HOME/.claude/skills/rct-claude" && unlink "$HOME/.claude/skills/rct-claude"
```

Remove every link the install created, not only the tower ones. The installer
refuses any destination it does not already own, so one link left behind blocks
reinstalling that revision.

Use your dedicated skills directory for a terminal install and remove its shell
`PATH` entry. For Claude Code, use `$HOME/.claude/skills`. For Cursor, use
`$HOME/.cursor/skills`. For OpenCode, use `$HOME/.config/opencode/skills`. Inspect and remove any old `sw` or `aw` links individually; preserve
unrelated skills and real directories. To roll back, remove the verified links,
check out the prior trusted source revision, and run that revision's installer.
