@echo off
setlocal EnableExtensions
rem Cursor's hook process cannot run an extensionless Ruby script, and ruby.exe
rem may be missing from that process PATH. Find it on the saved user or machine PATH.
set "SCRIPT=%~dp0cursor-usage-hook"
rem PowerShell starts ruby.exe. A temp batch path was emptied by cmd's percent
rem parser, so the script path is the only percent variable on the next line.
powershell -NoProfile -NonInteractive -Command "& { param($hook) $paths = @($env:Path); foreach ($key in @('HKCU:\Environment', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')) { $entry = (Get-ItemProperty -Path $key -Name Path -ErrorAction SilentlyContinue).Path; if ($entry) { $paths += [Environment]::ExpandEnvironmentVariables($entry) } }; $hit = ''; foreach ($dir in ($paths -join ';' -split ';')) { $dir = $dir.Trim(); if ($dir -and (Test-Path -LiteralPath (Join-Path $dir 'ruby.exe'))) { $hit = Join-Path $dir 'ruby.exe'; break } }; if (-not $hit) { [Console]::Error.WriteLine('cursor-usage-hook: ruby.exe was not found'); exit 1 }; & $hit --disable-gems --disable-rubyopt $hook; exit $LASTEXITCODE }" -args "%SCRIPT%"
exit /b %ERRORLEVEL%
