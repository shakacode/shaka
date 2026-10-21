@echo off
setlocal EnableExtensions
rem Cursor's hook process cannot run an extensionless Ruby script, and ruby.exe
rem may be missing from that process PATH. Find it on the saved user or machine PATH.
set "SCRIPT=%~dp0cursor-usage-hook"
rem A child of PowerShell does not inherit the hook pipe, and cmd percent-parsing
rem emptied a temp launcher path. Read the payload here and hand those bytes to ruby.exe.
powershell -NoProfile -NonInteractive -Command "& { param($hook) $paths = @($env:Path); foreach ($key in @('HKCU:\Environment', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')) { $entry = (Get-ItemProperty -Path $key -Name Path -ErrorAction SilentlyContinue).Path; if ($entry) { $paths += [Environment]::ExpandEnvironmentVariables($entry) } }; $hit = ''; foreach ($dir in ($paths -join ';' -split ';')) { $dir = $dir.Trim(); if ($dir -and (Test-Path -LiteralPath (Join-Path $dir 'ruby.exe'))) { $hit = Join-Path $dir 'ruby.exe'; break } }; if (-not $hit) { [Console]::Error.WriteLine('cursor-usage-hook: ruby.exe was not found'); exit 1 }; $in = [Console]::OpenStandardInput(); $ms = New-Object System.IO.MemoryStream; $in.CopyTo($ms); $bytes = $ms.ToArray(); if ($bytes.Length -eq 0) { [Console]::Error.WriteLine('cursor-usage-hook: hook payload was empty') }; $psi = New-Object System.Diagnostics.ProcessStartInfo; $psi.FileName = $hit; $q = [char]34; $psi.Arguments = '--disable-gems --disable-rubyopt ' + $q + $hook + $q; $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $p = [System.Diagnostics.Process]::Start($psi); if ($bytes.Length -gt 0) { $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length) }; $p.StandardInput.Close(); $p.WaitForExit(); exit $p.ExitCode } '%SCRIPT%'"
exit /b %ERRORLEVEL%
