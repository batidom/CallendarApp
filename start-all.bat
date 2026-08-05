@echo off
cd /d "%~dp0"

echo Starting Ollama...
start "Ollama" cmd /k call "%~dp0start-ollama.bat"

echo Starting backend...
start "Backend" cmd /k call "%~dp0start-backend.bat"

echo Waiting for backend to come up...
timeout /t 12 /nobreak >nul

echo Starting client...
call "%~dp0start-client.bat"

echo All set. Ollama and Backend are running in their own windows.
