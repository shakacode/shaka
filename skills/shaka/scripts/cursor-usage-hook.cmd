@echo off
setlocal EnableExtensions
rem Cursor's hook process cannot run an extensionless Ruby script, and ruby.exe
rem may be missing from that process PATH. Find it on the saved user or machine PATH.
set "SCRIPT=%~dp0cursor-usage-hook"
set "FOUND=%TEMP%\shaka-ruby-path-%RANDOM%%RANDOM%.cmd"
set "SHAKA_RUBY_PATH=%FOUND%"
set "SHAKA_HOOK_SCRIPT=%SCRIPT%"
rem Write a UTF-16 launcher. set /p would keep only the ANSI code page, so a path
rem such as C:\Users\José\Ruby\bin\ruby.exe would not survive.
powershell -NoProfile -Command "$paths = @($env:Path); foreach ($key in @('HKCU:\Environment', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')) { $entry = (Get-ItemProperty -Path $key -Name Path -ErrorAction SilentlyContinue).Path; if ($entry) { $paths += [Environment]::ExpandEnvironmentVariables($entry) } }; $hit = ''; foreach ($dir in ($paths -join ';' -split ';')) { $dir = $dir.Trim(); if ($dir -and (Test-Path -LiteralPath (Join-Path $dir 'ruby.exe'))) { $hit = Join-Path $dir 'ruby.exe'; break } }; if (-not $hit) { exit 2 }; $q = [char]34; $nl = [Environment]::NewLine; $line = '@echo off' + $nl + $q + $hit + $q + ' --disable-gems --disable-rubyopt ' + $q + $env:SHAKA_HOOK_SCRIPT + $q + $nl + 'exit /b %%ERRORLEVEL%%' + $nl; $enc = New-Object System.Text.UnicodeEncoding $false, $true; [System.IO.File]::WriteAllText('%FOUND%', $line, $enc)" <nul
if not exist "%FOUND%" (
  echo cursor-usage-hook: ruby.exe was not found 1>&2
  exit /b 1
)
call "%FOUND%"
set "SAVED=%ERRORLEVEL%"
del "%FOUND%" >nul 2>&1
exit /b %SAVED%
