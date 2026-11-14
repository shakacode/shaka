# Schedule a daily update check

```text
Check whether my Shaka installation supports daily update checks. If it does, set one up using https://shaka.shakacode.com/docs/reference/scheduled-update-checks
```

Ask your agent to identify the installed helper and follow the steps for your
system, then run one check and read its log. You can also follow the steps yourself.

If you installed from a GitHub branch, such as the default `main`, and leave
Shaka chats running overnight, schedule `update-check`. It reports the status
of a supported branch without changing the installed revision. For a pinned
release, ask your agent about [installing a newer release](../manual-installation.md#keep-a-tested-release).
If the check reports the reason `unsupported_source`, ask your agent to compare with
official Shaka `main` or use the [manual comparison](../manual-installation.md#verify-and-update)
to check the branch you installed from.
Read the job's log for `status` and `guidance`. If the guidance recommends an
update, finish your active Shaka chats first. Then ask your agent to
[update and verify Shaka](../manual-installation.md#verify-and-update). An `unknown`
result or an error without a status means the check could not determine whether
an update is available.

The default checkout is `~/.local/share/shaka/source`. If you installed
elsewhere, ask your agent which checkout it uses or follow the terminal steps
in the [installation guide](../manual-installation.md#verify-and-update). Use
the absolute path to `skills/shaka/scripts/shaka` inside that checkout. Run it
under the account that installed Shaka,
with Git and the authenticated GitHub CLI available to that account.
Scheduled jobs may get a different `PATH` from your terminal. If needed, set it
in the job or in a wrapper script. Include the directories that contain your
`git` and `gh` executables. Check the job's output even when the scheduler
reports success.

## macOS

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

## Linux with systemd

This example uses systemd 240 or later to append to a log file.
Create `~/.config/systemd/user/shaka-update-check.service`. `%h` expands to your
home directory. Create the parent directory if needed. Replace the helper path
if you installed elsewhere. Write literal `%` characters in your path as `%%`.
Double literal backslashes and escape embedded double quotes with a backslash.
For a path with other special characters, see [systemd service command lines](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Command%20lines).
If Git or `gh` lives outside the service's `PATH`,
set `Environment=PATH=...` in the service with the absolute directories it needs.

```ini
[Service]
Type=oneshot
WorkingDirectory=/
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

## Windows and WSL

For Shaka installed in WSL, save the following in a PowerShell script named
`shaka-schedule.ps1`. Replace the distribution, Linux user, and helper path
with those of your WSL installation.

```powershell
wsl.exe --distribution Ubuntu --user me --exec "/home/me/.local/share/shaka/source/skills/shaka/scripts/shaka" update-check *>> "$env:USERPROFILE\shaka-schedule.log"
exit $LASTEXITCODE
```

In Windows Task Scheduler, create a daily task under your Windows account.
Select **Run only when user is logged on**, the mode used in the WSL test.
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
agent to [compare the installed branch with its upstream](../manual-installation.md#verify-and-update).
The current `update-check` helper expects Unix-style paths when it looks up Git
and the GitHub CLI. The WSL task checks the separate Shaka installation inside
that distribution.

## Stop a scheduled check

- On macOS, unload the LaunchAgent with
  `launchctl bootout "gui/$(id -u)/com.shakacode.update-check"` and move its plist
  out of `~/Library/LaunchAgents` to keep it from loading at the next login.
- On Linux, run `systemctl --user disable --now shaka-update-check.timer`.
- On Windows, disable the task in Task Scheduler.

## Move an installation with a scheduled check

After the move, change the job's helper path and run a check to confirm it
reports on the new installation. On macOS, unload the old job with
`launchctl bootout "gui/$(id -u)/com.shakacode.update-check"` before loading
the edited plist. On Linux, edit `ExecStart` in the service file and run
`systemctl --user daemon-reload`. On Windows, edit the PowerShell script used
by the task.
