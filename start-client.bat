@echo off
cd /d "%~dp0client"

echo Stopping any running Calendar client...
taskkill /F /IM calendar_client.exe >nul 2>&1

echo Building Calendar client (Release)...
call flutter build windows
if errorlevel 1 (
    echo Build failed - not launching stale exe.
    pause
    exit /b 1
)

cd /d "%~dp0client\build\windows\x64\runner\Release"
echo Starting Calendar client...
start "" calendar_client.exe
