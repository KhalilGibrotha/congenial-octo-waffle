@echo off
REM =============================================================================
REM RHEL WSL Setup - Quick Start Batch File
REM =============================================================================
REM This batch file provides a simple interface to run the PowerShell setup
REM =============================================================================

setlocal EnableDelayedExpansion

echo.
echo ==================================================
echo RHEL WSL Automated Setup - Quick Start
echo ==================================================
echo.

REM Check if running as administrator (but don't require it)
net session >nul 2>&1
if %errorLevel% equ 0 (
    echo [INFO] Running with Administrator privileges
) else (
    echo [INFO] Running with standard user privileges
    echo [INFO] Some WSL operations may require elevation if they fail
)

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] PowerShell is not available or not working
    echo Please ensure PowerShell 5.1 or later is installed
    pause
    exit /b 1
)

echo [INFO] PowerShell is available
echo.

REM Check if this is first run
if not exist "config\config.psd1" (
    echo [SETUP] First time setup detected
    echo [SETUP] Running initial configuration setup...
    echo.
    
    powershell -ExecutionPolicy Bypass -File "Initialize-Setup.ps1" -OpenConfig
    
    if !errorLevel! neq 0 (
        echo [ERROR] Initial setup failed
        pause
        exit /b 1
    )
    
    echo.
    echo [SUCCESS] Initial setup completed
    echo [INFO] Please update your configuration file with Red Hat tokens
    echo [INFO] Then run this script again to begin the main setup
    echo.
    pause
    exit /b 0
)

echo [INFO] Configuration file found
echo [INFO] Ready to run main RHEL WSL setup
echo.

REM Ask user what they want to do
echo Choose an option:
echo.
echo 1. Run full RHEL WSL setup (recommended)
echo 2. Run setup with detailed logging (debug mode)
echo 3. Preview what would be done (dry run)
echo 4. Edit configuration file
echo 5. Re-run initial setup
echo 6. Run as Administrator (if needed for WSL operations)
echo 7. Exit
echo.

set /p choice="Enter your choice (1-7): "

if "%choice%"=="1" (
    echo [INFO] Running full RHEL WSL setup...
    powershell -ExecutionPolicy Bypass -File "Setup-RHEL-WSL.ps1"
) else if "%choice%"=="2" (
    echo [INFO] Running setup with debug logging...
    powershell -ExecutionPolicy Bypass -File "Setup-RHEL-WSL.ps1" -LogPath ".\logs\debug-run"
) else if "%choice%"=="3" (
    echo [INFO] Running dry run (preview mode)...
    powershell -ExecutionPolicy Bypass -File "Setup-RHEL-WSL.ps1" -WhatIf
) else if "%choice%"=="4" (
    echo [INFO] Opening configuration file...
    notepad "config\config.psd1"
    echo [INFO] Configuration file closed
) else if "%choice%"=="5" (
    echo [INFO] Re-running initial setup...
    powershell -ExecutionPolicy Bypass -File "Initialize-Setup.ps1" -Force -OpenConfig
) else if "%choice%"=="6" (
    echo [INFO] Restarting as Administrator...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~f0' -Verb RunAs"
    exit /b 0
) else if "%choice%"=="7" (
    echo [INFO] Exiting...
    exit /b 0
) else (
    echo [ERROR] Invalid choice: %choice%
    echo Please run the script again and choose 1-7
    pause
    exit /b 1
)

echo.
if %errorLevel% equ 0 (
    echo [SUCCESS] Operation completed successfully
) else (
    echo [ERROR] Operation failed with error code: %errorLevel%
    echo Check the logs directory for detailed error information
)

echo.
pause
