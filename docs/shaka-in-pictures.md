# Shaka in pictures

Build a small click-counter website with your coding agent, then approve the
change yourself. You need a GitHub account and an agent that can run commands
on your computer, such as Claude Code, Codex, or Cursor.

A **pull request**, or PR, proposes a change to your project. To **merge** it is
to accept the change, like accepting suggested edits in a document.

![Google Docs suggests changing 8 am to 7 am. A GitHub pull request proposes the same edit, ready to merge.](img/suggesting-mode.svg)

Shaka asks the agent to test and get an independent review before handing you
the PR. You decide what goes in. Tests and review can miss bugs.

<a id="what-you-will-get-from-this-page"></a>
<a id="why-use-shaka"></a>
<a id="it-works-like-suggesting-mode"></a>
<a id="what-shaka-does-while-you-wait"></a>
<a id="who-says-yes"></a>

## Tutorial: your first Shaka task

Use `/shaka` in Claude Code, Cursor, or OpenCode, and `$shaka` in Codex.
For another tool, see [coding agents](coding-agents.md).

### What you need

Use a playground so you can experiment without changing a real project.
The agent checks the required tools during installation.

### Step 1: Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Start a new chat and invoke `/shaka` or `$shaka` by itself. A welcome confirms
the skill is available. Follow the diagnostic's instructions for missing tools.
Missing project settings are expected before the playground is set up.

### Step 2: Make a playground project

```text
Create a private GitHub repository named shaka-playground, outside my other
projects. Give it a one-page website with a button and one automated test.
Upload it to GitHub.
```

Open the repository link to confirm the files arrived. Then ask:

```text
Help me start a new chat in the shaka-playground folder.
```

Ask the new chat which project folder it is using. Confirm that it names
`shaka-playground` before continuing. A **repository** is the project's GitHub home;
the local folder holds the copy your agent edits.

### Step 3: Run a health check

```text
/shaka doctor
```

Use `$shaka doctor` in Codex. Missing project settings (**Repository seam**) are expected here;
the next step adds them. Ask the agent to resolve other failures before continuing.

### Step 4: Give Shaka a task

```text
/shaka Add a counter that shows how many times the button was clicked.
Set up Shaka just for me. Use merge policy ask. Go.
```

Individual setup keeps Shaka settings out of commits. If the agent asks a
question, answer in your own words. Ask it to explain any permission request
you do not understand before approving it.

### Step 5: Watch it work

The agent builds, tests, reviews, and opens a PR. You can give feedback while
it works. If the agent stops, ask what it needs to continue.

Continue when the agent gives you a PR link and says it is ready for your review.

### Step 6: Read the pull request

Open the PR. Read its summary to understand what changed, then open
**Verification** to see what was tested and what remains unverified. Follow
**Code Review** to see the reviewer's findings and how they were handled.

Try the counter in its preview, or ask the agent to show it. Click several times
and confirm that each click increases the number by one. Ask about any failed
checks or unresolved concerns before merging.

### Step 7: Ask for a change

In the same chat:

```text
Make the counter number bigger.
```

Reload the PR when the agent finishes. Your main project version stays unchanged
until you merge, so you can keep asking for revisions.

Try the updated counter again and confirm that the number is easier to read.

### Step 8: Merge

The agent's **handoff** is its message naming the PR and the commit ready to merge.

When you are satisfied with the result and its checks, tell the agent:

```text
Merge the commit in your handoff.
```

Required checks and approvals still apply. A purple **Merged** status confirms
that the change joined your project.

You can also merge through GitHub. Confirm that its latest commit matches the
agent's handoff before using the offered merge control.

### Step 9: See what you gained

```text
Open the playground website so I can click the button.
```

Try a few clicks. You have practiced requesting a change, checking it, revising
it, and accepting it without running Git commands yourself.

## When something seems wrong

- If you dislike the result, ask for another revision or close the PR without merging.
- If you regret a merged change, ask the agent to open a PR that undoes it.
- If a check fails, ask what is broken and what needs to happen next.
- If the chat stops, use [resume unfinished work](working-with-shaka.md#resume-unfinished-work).

## Next steps

Use Shaka on a small task in a real project. [Start here](getting-started.md)
helps with setup; [Working with Shaka](working-with-shaka.md) has prompts for
planning, review, and feedback.
