# Cloud sessions

Run Shaka in a cloud agent, such as Claude Code on the web, to keep work going
while your computer is off. A cloud agent can make changes and open a PR when it
has the tools and repository access Shaka needs. If it cannot run a required
review or check, it should report what remains and stop before calling the PR
ready.

Once a PR exists, you can [resume it locally](working-with-shaka.md#resume-unfinished-work).
Before the first push, the work lives only in the cloud chat and its checkout, so
continue it there. [Reviewers in the cloud](#reviewers-in-the-cloud) explains
which reviews a cloud machine can run.

## Claude Code on the web

Claude Code sessions on claude.ai/code start in a fresh container each time, so
Shaka is not there unless the cloud environment installs it. The container also
ships Ruby 3.3, and Shaka needs Ruby 3.4. Give the environment a setup script so
`/shaka` is ready in every new session. Ask Claude in a cloud session:

```text
Add a setup script to this cloud environment that installs Ruby 3.4 and Shaka for Claude Code
```

You approve the change on a card. To add it yourself, open the cloud environment
menu in the session's title bar, choose **Edit**, and paste this under
**Setup script**:

```bash
#!/bin/bash
set -euo pipefail
# Shaka needs Ruby 3.4+; the image ships 3.3.
MAKE_OPTS=-j8 RUBY_CONFIGURE_OPTS=--disable-install-doc /opt/rbenv/bin/rbenv install -s 3.4.10
export PATH=/opt/rbenv/versions/3.4.10/bin:$PATH
# Official install from a clone outside the project checkout, linked for Claude Code (/shaka).
umask 022
mkdir -p "$HOME/.local/share/shaka"
if [ ! -d "$HOME/.local/share/shaka/source" ]; then
  git clone -q https://github.com/shakacode/shaka.git "$HOME/.local/share/shaka/source"
fi
"$HOME/.local/share/shaka/source/bin/install" --agent claude --no-session-hook
# Bring a kept install up to date; if the update fails, the session still starts.
"$HOME/.local/share/shaka/source/skills/shaka/scripts/shaka" install --update ||
  echo "Shaka update failed; run $HOME/.local/share/shaka/source/skills/shaka/scripts/shaka install --status" >&2
```

Building Ruby adds a few minutes to each new container. The script installs
Shaka from its own clone, separate from your project, so the branch you are
changing cannot change the Shaka that checks it. When a container keeps an
earlier clone, the update step brings it to the latest Shaka, so it accepts
settings your repository added since. Because the update step runs with the
script, the script turns off the update reminder for new chats. If the update
fails, the session still starts, and the setup log names the command that shows
the installation's state. The script applies to new
sessions; a session that is already running keeps what it has.

Shaka runs on the Ruby that installed it, but the session's own shell still
starts on Ruby 3.3. If your project's commands need Ruby 3.4 too, add these
lines to the end of the script. They put Ruby 3.4's commands, such as `ruby`,
`bundle`, and `rubocop`, first on the session's `PATH`:

```bash
# Session shells start on the image's Ruby 3.3; ~/.local/bin comes first on their PATH,
# so link each Ruby 3.4 command there, leaving any command already there alone.
# Use the Ruby version the script installs. A failure still lets the session start.
(mkdir -p "$HOME/.local/bin" &&
  for f in /opt/rbenv/versions/3.4.10/bin/*; do
    t="$HOME/.local/bin/${f##*/}"
    [ -e "$t" ] || [ -L "$t" ] || ln -s "$f" "$t" || exit 1
  done) ||
  echo "Linking Ruby 3.4 commands failed; session shells may still run Ruby 3.3" >&2
```

Skip these lines for a project pinned to another Ruby: the links make Ruby
3.4.10 the session's `ruby` whatever version the project selects. A command
already in `~/.local/bin` keeps its place, so it can still run Ruby 3.3.

With the lines in place, ask Claude to check `ruby -v` and `bundle -v` in the
session, then run `bundle install`.
Installing gems there, rather than in the setup script, keeps your project's
Gemfile from running before you have looked at the branch.

A cloud session cannot yet open or finish a Shaka PR. Claude Code blocks GitHub's
GraphQL API there, and Shaka uses it to create the PR, publish its
walkthrough, and merge. Shaka's doctor reports a
failed **GitHub GraphQL** check. See [reviewers in the cloud](#reviewers-in-the-cloud)
for what still works. Make and validate the change in the cloud session, ask it
to push the branch, then continue in a local session. Validation and review
results stay in the cloud container, so the local session runs them again on the
pushed branch before it opens the PR:

```text
/shaka Continue the pushed branch BRANCH and open its PR
```

## Reviewers in the cloud

Local review requires a reviewer the cloud environment can run. If none is
available, resume the PR in a local session. Cloud machines may lack the
local reviewer CLI, its sign-in, or Ruby 3.4. If GitHub GraphQL is blocked, Doctor and PR status can fall back to REST.
A review decision, merge queue state, or issue link in GitHub's Development
sidebar may be unknown. Where GitHub's Markdown preview is blocked too, publishing a local
review checks each comment after GitHub stores it and takes back one that renders wrong,
including a reviewer report that shows `\n` outside code; publish that review locally.
The comment is public, and GitHub sends its notifications, until it is taken back. If the
comment was already published unchanged, or taking it back fails, the error names the live comment.
A PR description is checked the same way; an edit made just before a restore can be lost, and its prose limits go unchecked when it holds text Shaka did not write.
Other PR actions still need GraphQL.

The opt-in [DeepSeek reviewer](settings.md#reviewlocal_review_agents) runs through
Shaka's Ruby OpenRouter API adapter. It does not require native DeepSeek support in
Codex, Claude Code or Cursor, and does not change the coding host's model.
To use it, add DeepSeek to the repository's reviewer list and set
`OPENROUTER_API_KEY` as a secret in the cloud environment running Shaka. It needs
Ruby and outbound HTTPS.

Try one review in the target environment before relying on it. A
[recorded Claude Code web trial](https://github.com/shakacode/shaka/issues/277#issuecomment-6541487155)
describes API, runtime and reviewer limits for that session.
