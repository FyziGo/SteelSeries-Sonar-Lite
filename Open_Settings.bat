@echo off
title Open Sonar Settings
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SonarLite.ps1" config
