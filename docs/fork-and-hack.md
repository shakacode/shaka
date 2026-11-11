# Fork Shaka and make it yours

A fork is your own copy of Shaka on GitHub. Use one when you want to change
Shaka itself across projects, such as the order of sections in its PR descriptions.
For checks, reviewers, or merge choices in one project, use
[project settings](settings-guide.md). To try an upstream change on one task,
[try a Shaka PR](trying-pr-versions.md).

## Fork and install

Ask your coding agent:

```text
Fork https://github.com/shakacode/shaka and install my fork for this coding agent.
Explain how I switch between using my fork and the official version.
```

The agent sets up a branch for your changes and tells you which version your
coding agent loads. Keep a separate development clone for edits so the installed
copy stays usable. See [manual installation](manual-installation.md) for prerequisites.

Before switching, ask the agent to record the current source, branch or release,
and commit. Select the official Shaka source or your fork's URL and branch. The
installer switches your skill links to a separate checkout and keeps the previous
checkout available. If other coding agents use that installation, switching
moves their links too. Ask the agent to show which links will move and verify the active links and commit, and
explain how to switch back before you start a new chat.

## Hack on it

Try a small change with a visible result:

```text
In my Shaka development clone, move Verification above Intent in PR descriptions.
Run the relevant checks and show me a sample description.
```

Ask the agent to run the candidate on a small README task in a practice project
without replacing your installation. Include "Do not merge" in that task. Check
that the open PR shows **Verification** above **Intent**.
When the result is right, ask the agent to install the tested version of your fork.
See [developing Shaka](https://github.com/shakacode/shaka/blob/main/contributing/development.md#where-changes-belong)
and [testing a local candidate](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#test-before-pushing-or-opening-a-pr).
Keep existing settings keys and PR record markers compatible so Shaka can still
read older projects and PRs. Follow the repository's rules when changing the workflow.

<details>
<summary>Set up a development clone from a terminal</summary>

Set `fork_url` to your fork's clone URL, `fork_branch` to the branch you
installed, and `dev_dir` to a new directory outside your installed checkout.

```bash
git clone --branch "$fork_branch" "$fork_url" "$dev_dir" &&
  cd "$dev_dir" &&
  git remote add upstream https://github.com/shakacode/shaka.git &&
  .agents/shaka/bin/setup &&
  .agents/shaka/bin/validate
```

Run the validation command again after editing. To see the workflow the agent
reads, run `skills/shaka/scripts/shaka workflow` from the development clone.

</details>

## Keep your fork current

```text
Bring the latest official Shaka changes into my fork. Keep my customizations,
resolve conflicts, and test the result. Install the exact commit that passed testing.
```

Bring upstream changes into your working branch without rewriting the installed
branch's history. The updater needs to move forward from the installed commit.
Publish the tested commit to your fork's install branch before installing it.
Finish active Shaka chats, install the tested commit, and start a new chat.

<details>
<summary>Publish the tested update from a terminal</summary>

In the development clone, switch to your fork's install branch, merge your
integration, and run `.agents/shaka/bin/validate`. Set `tested_commit` to the
commit you validated. Check that both `git remote get-url origin` and
`git remote get-url --push origin` point to your fork. Use the same
`fork_branch` as above to publish the tested commit and confirm it is on the
remote branch:

```bash
git push origin "$tested_commit:refs/heads/$fork_branch" &&
  git fetch origin "$fork_branch" &&
  git merge-base --is-ancestor "$tested_commit" FETCH_HEAD
```

If any command fails, stop before updating the installation. Ask your agent to
install that exact commit from the fork.

</details>

If the branch was rewritten, the updater leaves the installed copy in place.
From that checkout, confirm `origin` points to your fork. Run `git fetch origin`
and compare the two histories with
`git log --oneline --left-right HEAD...origin/mine`, using your branch name in
place of `mine`. You can ask your coding agent to help even if Shaka cannot
start. Choose which history to keep before changing either checkout.

<details>
<summary>Keep the rewritten contents and restore the installed commit to the history</summary>

Use a clean development checkout on the rewritten branch. Set
`shaka_source` to the path of the installed checkout, then run:

```bash
git fetch "$shaka_source" HEAD &&
  git merge-base HEAD FETCH_HEAD &&
  git merge --no-ff -s ours FETCH_HEAD
```

If Git finds no common ancestor, stop. The histories are unrelated, and this
recipe cannot restore the installed commit to the branch. When the merge
succeeds, it records the installed commit as an ancestor while keeping the
rewritten branch's files. Check the result, push your branch, then
[update the installation](manual-installation.md#verify-and-update).

</details>

## Contribute back

If a change could help other Shaka users, ask your agent to prepare a focused PR:

```text
Prepare an upstream Shaka PR for this one change. Include what I tested and what it showed.
```

Start from the official default branch and leave out your other customizations.
See [Contributing](https://github.com/shakacode/shaka/blob/main/CONTRIBUTING.md)
and [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md).
For a suggestion without code, use the [issue tracker](https://github.com/shakacode/shaka/issues/new/choose).

<a id="share-your-fork"></a>

See [Names and logos](https://github.com/shakacode/shaka#names-and-logos) for use
of the Shaka name.

## Troubleshooting

The examples below use `mine` for your fork's branch name.

| What you see | What to do |
| --- | --- |
| `Installation origin differs from the expected repository` | Pass `--repository` with the URL you cloned, exactly as `git config --get remote.origin.url` prints it. |
| `Installation checkout has uncommitted changes` | Move the edit to your working clone, push it to the registered branch, and [update the installation](manual-installation.md#verify-and-update). |
| `The registered branch (origin/mine of ...) was rewritten` | `mine` was rewritten. Compare the histories and choose a recovery path in [Keep your fork current](#keep-your-fork-current). |
| `Installation checkout is not on the registered branch` or `Installation branch mine does not follow origin/mine` | Run the `git` command at the end of the message to return to the branch you installed. |
