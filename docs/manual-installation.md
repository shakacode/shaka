# Install Shaka manually

For most installations, ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka for this coding agent
```

Use [Start here](getting-started.md) for your first task. This page also explains
how to check, update, or repair the installation. To inspect and run the installer
yourself, see [Install](#install).

## What the installer changes

The installer uses a dedicated Shaka checkout outside the projects you edit.
It links Shaka into each selected coding agent, records the source and Ruby it
uses, and leaves an empty lock file in each skills directory. Project settings
stay in the project. See [where Shaka keeps things](settings-guide.md#where-shaka-keeps-things)
and the [local timing log](reference/timings.md#local-timing-log).

The installer does not use `sudo`, edit your shell profile or `PATH`, or install
gems. It refuses installation folders other accounts can write to.

## Install

If you prefer the terminal, use Ruby 3.4 or later, Git 2.41 or later, and an
authenticated [GitHub CLI](https://cli.github.com/). Read the source and the
[installer](https://github.com/shakacode/shaka/blob/main/bin/install) before running it.

<details>
<summary>Manual installation commands</summary>

```bash
shaka_install_dir="$HOME/.local/share/shaka/source"
umask 022
mkdir -p "$(dirname "$shaka_install_dir")"
git clone https://github.com/shakacode/shaka.git "$shaka_install_dir"
```

After reading the checkout, run its installer:

```bash
"$shaka_install_dir/bin/install" --directory "$shaka_install_dir" --agent codex
```

Replace `codex` with your coding agent: `claude`, `cursor`, `opencode`, or `copilot`.
Repeat `--agent` to select more than one. Pi loads the shared skill linked for
`codex`. Keep the checkout outside `~/.agents/`, which holds settings.

| Agent | Skills directory |
| --- | --- |
| Codex | `~/.agents/skills` |
| Claude Code | `~/.claude/skills` |
| Cursor | `~/.cursor/skills` |
| OpenCode | `~/.config/opencode/skills` |
| GitHub Copilot | `~/.copilot/skills` |

The installer links `shaka` inside each selected directory. Pass
`--skills-dir DIR` for a custom directory in place of `--agent`.

</details>

The installer reports which checkout and skill links it uses. Start a new chat,
check the installation, and [set up your project](getting-started.md#2-set-up-your-project).

## Install your own fork

See [create and install a fork](fork-and-hack.md#fork-and-install) or
[install a fork you already have](fork-and-hack.md#install-a-fork-you-already-have).
The fork guide also shows how to switch back to the official version.

## Keep a tested release

```text
Install the latest published stable Shaka release if the installer supports it.
Keep my current version available for rollback
```

If no suitable stable release is available, ask the agent to explain the official
installation options before choosing one. A release stays at its recorded commit.
The installer can keep the earlier version available while it moves the skill links.

## Verify and update

```text
Which Shaka version am I using, and is an update available?
```

The agent can check the source checkout, skill links, and Ruby. Finish active
Shaka chats before updating. Then ask the agent to update and verify the
installation, and start a new chat. Updates can stop if the installed checkout
has local changes or its history no longer matches the recorded branch.
Set `SHAKA_NOTICES=off` if you want to silence Shaka's local reminders. In Claude
Code, you can opt in to reminders at chat start; that adds a `SessionStart` hook
to your user settings in `~/.claude/settings.json`.

<details>
<summary>Check or update from a terminal</summary>

Start with the checkout you installed. If you switched sources, use the
destination the installer printed. From a custom skills folder, run
`./shaka/scripts/shaka install --status` to find the active checkout.
If the helper cannot start, inspect the `shaka` link. Its target is
`skills/shaka` inside the active checkout.

For the default checkout, run:

```bash
shaka_source="$HOME/.local/share/shaka/source"
shaka_helper="$shaka_source/skills/shaka/scripts/shaka"
"$shaka_helper" install --status
```

If you installed elsewhere, set `shaka_source` to the active checkout before
setting `shaka_helper`. If the helper says its recorded Ruby is unavailable,
use Ruby 3.4 or later and run `ruby "$shaka_source/bin/install" --status`.
Status shows the next step. When it asks you to reinstall to record Ruby again,
run `ruby "$shaka_source/bin/install"` from that checkout.

Check the result with `"$shaka_helper" install --verify`. To inspect an update
to a branch installation, confirm `origin` points to the repository you
installed from. Then run this from the active checkout:

```bash
git fetch origin && git diff HEAD '@{upstream}'
```

The comparison leaves your installed files and skill links in place.
After active chats finish, run `"$shaka_helper" install --update` to apply a
branch update. The updater fetches the branch again when it runs.
For a pinned release, use the [tested release prompt](#keep-a-tested-release)
to install a newer release.

Before running `"$shaka_helper" install --repair`, check the status output.
If it proposes a take-over for a split installation, the command names the
checkout that will receive the skill links. Check which agents will switch.
If Claude Code's startup hook follows a link that moves, new Claude chats
will run the new checkout. Run repair if you want that move.
If status gives you a decision instead of a command, leave the links in place
and ask your agent to inspect the checkouts before you choose which to keep.

Repair keeps local commits on a `kept-<commit>` branch and renames unused
records so you can inspect them later. It deletes only the temporary checkout
left by an interrupted update. It stops when it needs a decision.

To enable Claude Code's startup reminder, run
`"$shaka_source/bin/install" --directory "$shaka_source" --agent claude --session-hook`.
Run it again without `--session-hook` to remove the reminder.

</details>

### Schedule daily checks or updates

```text
Use Shaka's manual installation guide to schedule `update-check` daily
```

Your agent can find the installed helper, configure the scheduler, and run one
check to confirm the log. To set it up yourself, use the steps for your system.

If you leave Shaka chats running overnight, schedule `update-check`. It reports
the status of a supported GitHub branch without changing the installed revision.
If its `reason` is `unsupported_source`, use the [manual upstream comparison](#verify-and-update).
Read the job's log for `status` and `guidance`. If the guidance calls for
`install --update`, finish your active Shaka chats first. Then ask your agent
to update and verify Shaka as described [above](#verify-and-update). An `unknown`
result or an error without a status means the check could not determine whether
an update is available.

For a branch installation, schedule `install --update` only if every Shaka chat
using that installation will be closed whenever the job can run. Shaka does
not check for active chats before updating the shared checkout. Account for
missed runs that start late, such as when your computer wakes. If chats could
overlap any run, keep the job on `update-check`. To move a pinned installation
to a newer version, [install a newer release](#keep-a-tested-release).

Find your installed checkout with `install --status` as shown above. Use its
absolute helper path in the job. Before moving the installation, stop future
runs and wait for any running update to finish. On Linux, use
`systemctl --user disable --now shaka-update-check.timer`. After the move, set
the new path and run `update-check` against it before re-enabling the job.
Run it under the account that installed Shaka, with Git and the authenticated
GitHub CLI available to that account.
Scheduled jobs may get a different `PATH` from your terminal. If needed, set it
in the job or in a wrapper script. Include the directories that contain your
`git` and `gh` executables. Check the job's output even when the scheduler
reports success.

#### macOS

Create `~/Library/LaunchAgents/com.shakacode.update-check.plist`. Create its
parent directory if needed. Replace the example helper and log paths with
absolute paths for your account. Escape XML characters in the plist values,
such as `&amp;` for `&`. Adjust `PATH` for your Git and GitHub CLI.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.shakacode.update-check</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/me/.local/share/shaka/source/skills/shaka/scripts/shaka</string>
    <string>update-check</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/Users/me/Library/Logs/Shaka/shaka-schedule.log</string>
  <key>StandardErrorPath</key><string>/Users/me/Library/Logs/Shaka/shaka-schedule.log</string>
</dict>
</plist>
```

Use a private directory for the log. Set `shaka_log_dir` to the parent of the
absolute log path used in the plist. Load the LaunchAgent and run it once.

```bash
shaka_log_dir="$HOME/Library/Logs/Shaka"
mkdir -p -m 700 "$shaka_log_dir"
chmod 700 "$shaka_log_dir"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.shakacode.update-check.plist"
launchctl kickstart "gui/$(id -u)/com.shakacode.update-check"
```

The example runs at 9 a.m. local time. A run missed during sleep can start when
the Mac wakes. See [Apple's guide to scheduled jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html).

#### Linux with systemd

This example uses systemd 240 or later to append to a log file.
Create `~/.config/systemd/user/shaka-update-check.service`. `%h` expands to your
home directory. Create the parent directory if needed. Replace the helper path
if you installed elsewhere. If Git or `gh` lives outside the service's `PATH`,
set `Environment=PATH=...` in the service with the absolute directories it needs.

```ini
[Service]
Type=oneshot
UMask=0077
ExecStart="%h/.local/share/shaka/source/skills/shaka/scripts/shaka" update-check
StandardOutput=append:%h/shaka-schedule.log
StandardError=inherit
```

Create `~/.config/systemd/user/shaka-update-check.timer`.

```ini
[Timer]
OnCalendar=*-*-* 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

`Persistent=true` catches up on a missed run when the timer starts. Remove it
if you want the job to wait for the next scheduled time after the timer restarts.
A timer that stays active during sleep can still catch up when the system wakes.
A user timer runs while your user manager is active. If it should run when
you're logged out, check whether your system allows `loginctl enable-linger`.
See [systemd timer settings](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html).

```bash
(umask 077; touch "$HOME/shaka-schedule.log")
chmod 600 "$HOME/shaka-schedule.log"
systemctl --user daemon-reload
systemctl --user enable --now shaka-update-check.timer
systemctl --user start shaka-update-check.service
tail -n 20 "$HOME/shaka-schedule.log"
```

If the service fails to start or the log has no new output, run
`systemctl --user status shaka-update-check.service` to see its state and any
startup error systemd recorded.

#### Windows and WSL

For Shaka installed in WSL, save the following in a PowerShell script named
`shaka-schedule.ps1`. Replace the distribution, Linux user, and helper path
with those of your WSL installation.

```powershell
wsl.exe --distribution Ubuntu --user me --exec "/home/me/.local/share/shaka/source/skills/shaka/scripts/shaka" update-check *>> "$env:USERPROFILE\shaka-schedule.log"
exit $LASTEXITCODE
```

In Windows Task Scheduler, create a daily task under your Windows account.
Set **Program/script** to `powershell.exe`. In **Add arguments**, enter
`-NoProfile -File "C:\Users\me\shaka-schedule.ps1"`, using your script's absolute
path. Your PowerShell execution policy must allow the script. If the first run
produces no log, run `powershell.exe -NoProfile -File "C:\Users\me\shaka-schedule.ps1"`
in a terminal under that account, using your script path. Read a successful run's output
in `shaka-schedule.log` in your Windows profile. Before running the task, check
the destination folder and any existing log in **Properties → Security**.
Use a location where unrelated accounts cannot read the log.
See [Microsoft's PowerShell execution policy guide](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
and [WSL command reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands).

`--exec` starts the helper without loading your shell profile. If Git or `gh`
depends on your profile's `PATH`, put the Linux command in a wrapper that sets
`PATH` and use that wrapper as the `--exec` target.

For Shaka installed directly on Windows, use a daily reminder to ask your
agent to [compare the installed branch with its upstream](#verify-and-update).
The current `update-check` helper expects Unix-style paths when it looks up Git
and the GitHub CLI. The WSL task checks the separate Shaka installation inside
that distribution.

#### Switch a daily check to an update

For a branch installation, test the job with `update-check` first. Make sure Git
can fetch the registered origin from the scheduled environment without prompting.
A successful `update-check` uses the GitHub CLI and does not test Git fetch access.
If every chat will be closed whenever the job can run, change the job arguments
to `install` and `--update`. The job applies eligible commits from the registered
branch without asking you to review each update. On macOS, unload the job with
`launchctl bootout "gui/$(id -u)/com.shakacode.update-check"` and run the
`launchctl bootstrap` command above again. On Linux, run
`systemctl --user daemon-reload` after editing the service. A persistent timer
can also catch up when the user manager starts at login. On Windows with WSL,
edit the PowerShell script. In Task Scheduler, check whether **Run task as soon
as possible after a scheduled start is missed** is enabled. That setting can
start the update outside its usual time.

After the first scheduled update, run `install --verify` with the installed
helper to verify the checkout and skill links. If the update fails, read the
job log for the error. Use `install --status` to diagnose local checkout or
skill-link problems.

### Repair a broken installation

```text
Check my Shaka installation and help me fix what's broken.
Preserve my changes and tell me if you need a decision
```

The agent checks what your coding tool loads, fixes what it can, and verifies
the result. If an old checkout or local changes need a decision, it explains
what it found first. If your old installation lives in `~/.agents/shaka`, ask the
agent to move it to a dedicated checkout and verify the skill links. Keep the old
checkout until the new one works.

## Develop Shaka in a separate clone

```text
Set up a separate clone for developing Shaka. Keep my installed copy working
```

Your coding agent loads the installed checkout directly. A separate development
clone lets you change Shaka without breaking the version you use in other projects.
Avoid installing from a temporary worktree that could disappear after its PR merges.

### Move Shaka out of a clone you develop in

```text
Move my Shaka installation to its own checkout. Preserve my branches, worktrees,
and local changes. Verify the installation afterward
```

The agent checks which copy is installed and explains what it needs to move.
Ask it to confirm your development work is still available before removing any
old checkout.

<details>
<summary>Move Shaka's skill links to a dedicated checkout</summary>

Run the command below from the checkout your coding agents currently use.
It moves every skill link registered to that checkout. Check which agents
will switch before you run it. A Claude Code startup hook that follows a
moved link will run the new checkout in new chats. The old checkout keeps
its files, branches, and worktrees.
Choose a destination with no linked worktrees or extra branches. If the default
directory is in use, choose a separate destination.

```bash
./bin/install --directory "$HOME/.local/share/shaka/source" --take-over
```

If you run it from another checkout and use a custom skills folder, pass
that folder with `--skills-dir`. Verify from the new checkout with
`bin/install --verify`.

If the installer was force-stopped during the move and neither checkout has an
active installation record, restore the newest
`.git/shaka-install.retired-*.json` in the old checkout to
`.git/shaka-install.json`. Retry with the same source and destination options,
then verify. If either checkout still has an active record, leave it in place
and check the installation state before retrying.

</details>
