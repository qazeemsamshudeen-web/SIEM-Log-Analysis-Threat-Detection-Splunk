@echo off
title Push to GitHub - Enterprise Splunk SIEM Log Analysis Lab
echo ========================================================
echo Pushing Day 4 Splunk SIEM Threat Analysis Lab to GitHub...
echo Default Target: https://github.com/qazeemsamshudeen-web/SIEM-Log-Analysis-Threat-Detection-Splunk
echo ========================================================
echo.

cd /d "%~dp0"

set "GIT_EXE=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"

if not exist "%GIT_EXE%" (
    set "GIT_EXE=C:\Program Files\Git\cmd\git.exe"
)

if not exist "%GIT_EXE%" (
    set "GIT_EXE=git"
)

:: Check if git remote origin is configured
"%GIT_EXE%" remote get-url origin >nul 2>&1
if errorlevel 1 (
    echo [*] Configuring remote origin...
    "%GIT_EXE%" remote add origin https://github.com/qazeemsamshudeen-web/SIEM-Log-Analysis-Threat-Detection-Splunk.git
)

echo.
echo [1/3] Staging all files, reports, PDF runbook, XML, and screenshots...
"%GIT_EXE%" add -A

echo.
echo [2/3] Committing latest changes...
"%GIT_EXE%" commit -m "Complete Enterprise SOC SIEM Log Analysis, Dashboards, and AI Risk Reports" >nul 2>&1

echo.
echo [3/3] Synchronizing and pushing to GitHub (main)...
echo --------------------------------------------------------
echo NOTE: Ensure you have created the empty repository at:
echo https://github.com/new  (Repository name: SIEM-Log-Analysis-Threat-Detection-Splunk)
echo --------------------------------------------------------
"%GIT_EXE%" push -u origin main --force

if errorlevel 1 (
    echo.
    echo [!] Push failed. 
    echo Please ensure the repository 'SIEM-Log-Analysis-Threat-Detection-Splunk' is created under your GitHub account:
    echo https://github.com/new
) else (
    echo.
    echo ========================================================
    echo [SUCCESS] Your repository is LIVE on GitHub!
    echo Visit: https://github.com/qazeemsamshudeen-web/SIEM-Log-Analysis-Threat-Detection-Splunk
    echo ========================================================
)

echo.
pause
