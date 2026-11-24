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

To add the script yourself instead, open the cloud environment
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
"$HOME/.local/share/shaka/source/bin/install" --agent claude
```

The script installs Shaka from its own clone, separate from your project, so
the branch you are changing cannot change the Shaka that checks it.

Building Ruby takes a few minutes. When the script finishes within about five
minutes, Claude Code saves the container and starts later sessions from that
copy without running the script again; a slower script is not saved, so every
new session waits for it. Claude Code reruns the script when you edit it, when
you change the environment's allowed network hosts, and when the saved copy
expires after about a week. A session that is already running keeps what it
has, so start a new session to use an edited script.

A cached session therefore runs the Shaka its copy was saved with. The
installer tries to turn on Shaka's
[update reminder](reference/scheduled-update-checks.md#get-a-reminder-when-a-claude-code-chat-starts),
which tells you in a new chat when Shaka needs a check or an update. An update
made in a session lasts only for that session, because the next one starts from
the saved copy again. To update the saved copy, edit the setup script, which
makes Claude Code rebuild it.

Shaka runs on the Ruby that installed it, but the session's own shell still
starts on Ruby 3.3. If your project's commands need Ruby 3.4 too, review the
branch's Gemfile, its gemspec, and any file they load first. `bundle install`
runs them as Ruby with the session's credentials and GitHub access, so do not run it on a branch you have not
reviewed, such as one from a fork. Then ask Claude in the session:

```text
Run this project's Ruby commands with /opt/rbenv/versions/3.4.10/bin first on PATH. Stop if ruby -v does not report 3.4, otherwise run bundle install
```

Claude sets `PATH` on each command, so shells it does not start that way keep
Ruby 3.3.

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
