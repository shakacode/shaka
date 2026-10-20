@echo off
setlocal EnableExtensions
rem Cursor's hook process cannot run an extensionless Ruby script, and ruby.exe
rem may be missing from that process PATH. Find it on the saved user or machine PATH.
set "SCRIPT=%~dp0cursor-usage-hook"
set "FOUND=%TEMP%\shaka-ruby-path-%RANDOM%%RANDOM%.txt"
set "SHAKA_RUBY_PATH=%FOUND%"
powershell -NoProfile -Command "$paths = @($env:Path); foreach ($key in @('HKCU:\Environment', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')) { $entry = (Get-ItemProperty -Path $key -Name Path -ErrorAction SilentlyContinue).Path; if ($entry) { $paths += [Environment]::ExpandEnvironmentVariables($entry) } }; $hit = ''; foreach ($dir in ($paths -join ';' -split ';')) { $dir = $dir.Trim(); if ($dir -and (Test-Path -LiteralPath (Join-Path $dir 'ruby.exe'))) { $hit = Join-Path $dir 'ruby.exe'; break } }; Set-Content -LiteralPath $env:SHAKA_RUBY_PATH -Encoding ascii -Value $hit" <nul
set "RUBY="
set /p RUBY=<"%FOUND%"
del "%FOUND%" >nul 2>&1
if not defined RUBY (
  echo cursor-usage-hook: ruby.exe was not found 1>&2
  exit /b 1
)
"%RUBY%" --disable-gems --disable-rubyopt "%SCRIPT%"
exit /b %ERRORLEVEL%
