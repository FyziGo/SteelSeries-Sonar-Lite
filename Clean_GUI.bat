@echo off
title Purge SteelSeries GUI
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" clean-gui
pause
