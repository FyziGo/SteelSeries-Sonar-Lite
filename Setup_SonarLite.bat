@echo off
setlocal EnableDelayedExpansion
title SteelSeries Sonar Lite Manager

:: Check for Administrator elevation
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:MENU
cls
echo ===================================================================
echo                  STEELSERIES SONAR LITE SETUP
echo       Run Sonar without Moments, 3DAT and heavy Electron bloat
echo ===================================================================
echo.
echo   [1] Enable Pure Sonar Mode (Headset only - Maximum lightness: ~240MB)
echo   [2] Enable Sonar + Engine (Keep SteelSeries Mice/Keyboards/RGB active)
echo   [3] Open SteelSeries Settings (Configure EQ / devices, then auto-purge UI)
echo   [4] Check Current Status and Memory Usage
echo   [5] Purge leftover GUI processes (Free ~800MB)
echo   [6] Restore Factory SteelSeries GG Defaults
echo   [0] Exit
echo.
echo ===================================================================
set /p CHOICE="Choose an option [0-6]: "

if "%CHOICE%"=="1" (
    cls
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" debloat
    pause
    goto MENU
)
if "%CHOICE%"=="2" (
    cls
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" keep-engine
    pause
    goto MENU
)
if "%CHOICE%"=="3" (
    cls
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" config
    goto MENU
)
if "%CHOICE%"=="4" (
    cls
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" status
    pause
    goto MENU
)
if "%CHOICE%"=="5" (
    cls
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" clean-gui
    pause
    goto MENU
)
if "%CHOICE%"=="6" (
    cls
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" restore
    pause
    goto MENU
)
if "%CHOICE%"=="0" exit /b

goto MENU
