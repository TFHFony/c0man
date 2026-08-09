@echo off
cd /d "%~dp0"
"%~dp0sjasmplus.exe" src/main.asm --raw=0man.rom
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)
echo Build OK: 0man.rom
