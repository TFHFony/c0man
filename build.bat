@echo off
cd /d "%~dp0"
"%~dp0sjasmplus.exe" src/main.asm --raw=c0man.rom
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)
echo Build OK: c0man.rom
