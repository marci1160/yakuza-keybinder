@echo off
rem Brooklyn Keybinder - EXE bauen (AutoHotkey v1.1 muss installiert sein)
setlocal
set AHK=%ProgramFiles%\AutoHotkey
if not exist "%AHK%\Compiler\Ahk2Exe.exe" set AHK=%ProgramFiles(x86)%\AutoHotkey
set SRC=%~dp0..\src
"%AHK%\Compiler\Ahk2Exe.exe" /in "%SRC%\Brooklyn.ahk" /out "%~dp0BrooklynKeybinder.exe" /icon "%SRC%\brooklyn.ico" /bin "%AHK%\Compiler\Unicode 32-bit.bin"
if errorlevel 1 (echo Fehler beim Kompilieren & exit /b 1)
echo Fertig: %~dp0BrooklynKeybinder.exe
