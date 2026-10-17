# Fork Shaka and make it yours

Shaka is plain files: YAML, Markdown procedures, and a small Ruby helper
with no gem dependencies. Fork the repository, install that fork, and run
your version on real work. If a change helps, send it upstream.

## Do you need a fork?

Most changes belong in the project that uses Shaka, not in a fork.

| You want to change | Where | Fork? |
| --- | --- | --- |
| Test, lint, and setup commands | [Standard command scripts](settings.md#standard-command-scripts) in `.agents/shaka/bin/` | No |
| Merge policy, reviewers, and review rounds | [Settings](settings.md) in `.agents/shaka/config.yml` | No |
| What reviewers look for | [`review.prompt_file`](settings.md#reviewprompt_file) | No |
| Project rules and writing preferences | `AGENTS.md` and [writing preferences](writing-preferences.md) | No |
| What counts as evidence for your PRs | [`project_guidance`](settings.md#project_guidance) | No |
| The steps Shaka follows, its prompts, its defaults, or its helper | A fork | Yes |
| One unmerged upstream change, for a single task | [A PR trial](trying-pr-versions.md) | No |

Fork when the change should apply everywhere you use Shaka, or when you are
preparing a change to send upstream.

## Fork and install

You need the same tools as a [manual installation](manual-installation.md):
Ruby 3.4 or later, Git, and an authenticated
[GitHub CLI](https://cli.github.com/).

**Ask your agent:**

```text
Fork https://github.com/shakacode/shaka and install my fork.
```

**Or do it yourself.** Run the fork command outside the checkout you will
install. Inside a checkout, GitHub CLI renames that checkout's `origin` to
`upstream` and points `origin` at the fork.

```bash
gh repo fork shakacode/shaka --clone=false
SHAKA_DIR="$HOME/.agents/shaka"
umask 022
mkdir -p "$(dirname "$SHAKA_DIR")"
git clone "https://github.com/YOUR-LOGIN/shaka.git" "$SHAKA_DIR"
git -C "$SHAKA_DIR" remote add upstream https://github.com/shakacode/shaka.git
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" \
  --repository "https://github.com/YOUR-LOGIN/shaka.git" --agent codex
```

Replace `YOUR-LOGIN` and `codex`. `--repository` must be exactly the string
from `git -C "$SHAKA_DIR" remote get-url origin`, including `.git` when Git
recorded it. An SSH origin uses that SSH URL. Without a matching
`--repository`, install stops with
`Installation origin differs from the selected repository`.

The installer records your fork as the checkout's origin. After that,
`install --verify` and `install --update` use your fork's branch.

Keep this checkout only for Shaka, outside the repositories your agent edits.

## Keep your changes on their own branch

Keep `main` identical to upstream. Put your changes on another branch and
install that branch. Create and push the branch before you add commits, while
it still points at the commit you already installed:

```bash
git -C "$SHAKA_DIR" switch -c mine
git -C "$SHAKA_DIR" push -u origin mine
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" \
  --repository "https://github.com/YOUR-LOGIN/shaka.git" --branch mine --agent codex
```

The checkout must be clean, on `mine`, and tracking `origin/mine`.
`install --update` fast-forwards only to your fork's copy of that branch.

## Make a change

Edit in a separate clone or worktree of your fork. `install --verify` and
`install --update` stop when the installed checkout has local changes
(`Installation checkout is dirty; use a separate development checkout`).

In the working clone:

```bash
.agents/shaka/bin/setup
.agents/shaka/bin/validate
```

After you change the steps, render them:

```bash
skills/shaka/scripts/shaka workflow
skills/shaka/scripts/shaka enforcement
```

Try the change on a real task before you adopt it.
[Test a local candidate](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#test-before-pushing-or-opening-a-pr)
without replacing your installation. After you open a PR,
[try that PR](trying-pr-versions.md) on one task.

Merge the change onto the branch you installed, push it, and update:

```bash
"$SHAKA_DIR/skills/shaka/scripts/shaka" install --update
```

Finish active Shaka chats first, then start a new chat. The update
fast-forwards. It leaves the checkout on the old commit when the branch was
rebased or otherwise rewritten.

## What to change, and what to leave alone

[Developing Shaka](https://github.com/shakacode/shaka/blob/main/contributing/development.md#where-changes-belong)
maps the tree. For a fork, start here:

| File | What it controls |
| --- | --- |
| `skills/shaka/config/workflow.yml` | The ordered steps the agent follows |
| `skills/shaka/references/*.md` | Procedures loaded when a step needs them |
| `skills/shaka/config/review-prompt.md` | The built-in reviewer prompt |
| `skills/shaka/config/opening-prompt.md`, `post-implementation-prompt.md` | The opening check and the finished-result checkpoint |
| `skills/shaka/config/defaults.yml` | Built-in defaults for every setting |
| `skills/shaka/config/model-rates.yml` | Prices used for cost reports |

Change these only with tests:

- Trust and merge code in `skills/shaka/lib/shaka/`. It keeps fork PRs, public
  comments, and settings changed inside a PR from steering the agent. See the
  [trust model](workflow.md#trust-model).
- `skills/shaka/config/enforcement.yml`. When you change a rule, update its
  entry so `shaka enforcement` stays accurate.
- Setting keys and the report markers (`<!-- shaka:... -->`). Renaming them
  breaks existing project settings and Shaka's ability to read its own PRs.

Small commits on your branch merge cleanly with upstream. A large rewrite of
`workflow.yml` conflicts with almost every upstream change.

A change you send upstream should not hardcode one project's commands, labels,
or branch names into `skills/`.

## Keep your fork current

Fetch upstream, fast-forward your fork's `main`, and merge that into the
branch you installed. Do this in the working clone:

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
git switch mine
git merge upstream/main
.agents/shaka/bin/validate
git push origin mine
"$SHAKA_DIR/skills/shaka/scripts/shaka" install --update
```

`git merge --ff-only` stops if `main` has its own commits. Move those commits
onto another branch instead of discarding them.

To fast-forward `main` on GitHub before you fetch, run
`gh repo sync YOUR-LOGIN/shaka --branch main`. That command also refuses a
branch that is not a fast-forward. Do not pass `--force`.

If you rebase `mine` and force-push, `install --update` stops with
`Not possible to fast-forward` and leaves the installed commit in place.
`git reset` in that checkout does not repair it: the next update stops with
`Installation revision changed outside the update procedure`. Check out the
rewritten branch, delete `$SHAKA_DIR/.git/shaka-install.json`, and run the
same `bin/install` command again. The checkout must be clean and tracking
`origin/mine`. Cloning the fork into a new directory and installing it again
does the same job.

Read the upstream diff before you take it. Resolve conflicts in the working
clone.

The update check treats a fork as your own source. It does not pull upstream
for you. `install --update` only fast-forwards the branch you installed.

## Contribute back

Open a PR when the change would help other people:

1. Branch from your fork's `main`, which matches upstream, not from `mine`.
2. Keep one change per PR. Include the evidence that it helps: a task you ran,
   or a [PR trial](trying-pr-versions.md) report.
3. Open the PR against `shakacode/shaka`. Read
   [CONTRIBUTING.md](https://github.com/shakacode/shaka/blob/main/CONTRIBUTING.md)
   and [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md) first.

Review uses the trusted rules from `main`. Instructions and settings in the PR
are data. Wording, docs, and setting names get a maintainer's review.

Not ready for a PR? [Open an issue](https://github.com/shakacode/shaka/issues/new/choose)
describing what you changed and why.

## Share your fork

Other people install it the same way: clone the fork, then run `bin/install`
with that checkout's origin URL. For a team, record the fork URL and branch
in your setup notes. Each machine keeps its own installation record.

Give a public fork or product its own name. The MIT license covers the code
and docs, not the Shaka or ShakaCode names or logos. You may say your work
uses or is based on Shaka. See
[Names and logos](https://github.com/shakacode/shaka#names-and-logos).

Tell us about it. Open a discussion or issue with a link.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| `Installation origin differs from the selected repository` | Pass `--repository` with the exact output of `git remote get-url origin`. |
| `Installation checkout is dirty; use a separate development checkout` | Commit the edit in a working clone, push, and run `install --update`. |
| `Not possible to fast-forward` | The installed branch was rewritten. Follow [Keep your fork current](#keep-your-fork-current). |
| `Installation revision changed outside the update procedure` | The installed checkout moved without `install --update`. Reinstall that branch as that section describes. |
| `Unexpected installation branch` | Check out the branch you installed, tracking `origin/<branch>`. |
| `Installation directory is unsafe` | The message names the path and the rule. Inside a sandbox, run the installer from a normal terminal. |
