@echo off
setlocal

set "APP_NAME=SNBattleSim"
if defined PORT (
  set "APP_URL=http://127.0.0.1:%PORT%/"
) else (
  set "APP_URL=http://127.0.0.1:4174/"
)
set "SERVER_SCRIPT=%~dp0tools\serve.mjs"

call :find_node
if not defined NODE_EXE (
  echo Node.js was not found. Installing the latest Node.js LTS release...
  call :install_node
  if errorlevel 1 goto :install_failed
  call :find_node
)

if not defined NODE_EXE goto :install_failed

echo Starting %APP_NAME% with:
"%NODE_EXE%" --version
echo Open %APP_URL% in your browser.
echo Keep this window open while using %APP_NAME%.
echo.

if not defined STEAM_NAVIGATOR_NO_BROWSER (
  start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Milliseconds 800; Start-Process '%APP_URL%'"
)

pushd "%~dp0"
"%NODE_EXE%" "%SERVER_SCRIPT%"
set "APP_EXIT_CODE=%ERRORLEVEL%"
popd

if not "%APP_EXIT_CODE%"=="0" (
  echo.
  echo %APP_NAME% stopped with exit code %APP_EXIT_CODE%.
  pause
)
exit /b %APP_EXIT_CODE%

:find_node
set "NODE_EXE="
for /f "delims=" %%N in ('where node.exe 2^>nul') do if not defined NODE_EXE set "NODE_EXE=%%~fN"
if defined NODE_EXE exit /b 0
if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if exist "%LocalAppData%\Programs\nodejs\node.exe" set "NODE_EXE=%LocalAppData%\Programs\nodejs\node.exe"
exit /b 0

:install_node
where winget.exe >nul 2>&1
if not errorlevel 1 (
  winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements
  if not errorlevel 1 exit /b 0
  echo winget could not install Node.js. Trying the official Node.js installer...
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } elseif ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }; $fileKey = 'win-' + $arch + '-msi'; $releases = Invoke-RestMethod 'https://nodejs.org/dist/index.json'; $release = foreach ($item in $releases) { if ($item.lts -and $item.files -contains $fileKey) { $item; break } }; if (-not $release) { throw 'No compatible Node.js LTS installer was found.' }; $installer = Join-Path ([IO.Path]::GetTempPath()) ('node-' + $release.version + '-' + $arch + '.msi'); try { Invoke-WebRequest ('https://nodejs.org/dist/' + $release.version + '/node-' + $release.version + '-' + $arch + '.msi') -OutFile $installer -UseBasicParsing; $process = Start-Process msiexec.exe -ArgumentList '/i', ('"' + $installer + '"'), '/passive', '/norestart' -Wait -PassThru; if ($process.ExitCode -notin 0, 3010) { throw ('Node.js installer failed with exit code ' + $process.ExitCode) } } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }"
exit /b %ERRORLEVEL%

:install_failed
echo.
echo Node.js could not be installed automatically.
echo Check your internet connection and Windows installer permissions, then run this file again.
pause
exit /b 1
