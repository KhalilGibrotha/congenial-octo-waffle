#Requires -Version 5.1

<#
.SYNOPSIS
    Test script to verify RHEL WSL setup components work without admin privileges

.DESCRIPTION
    This script tests the core functionality that should work without administrator
    privileges, helping identify what requires elevation and what doesn't.

.EXAMPLE
    .\Test-UnprivilegedMode.ps1

.NOTES
    This test should be run as a regular user (not Administrator)
#>

[CmdletBinding()]
param()

# Colors for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
}

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n===================================================" -ForegroundColor $Colors.Header
    Write-Host $Message -ForegroundColor $Colors.Header
    Write-Host "===================================================" -ForegroundColor $Colors.Header
}

function Write-TestStep {
    param([string]$Message, [int]$Step)
    Write-Host "`n[$Step] Testing: $Message" -ForegroundColor $Colors.Info
}

function Write-TestResult {
    param([string]$Test, [bool]$Success, [string]$Details = "")
    $symbol = if ($Success) { "✓" } else { "✗" }
    $color = if ($Success) { $Colors.Success } else { $Colors.Error }
    
    Write-Host "  $symbol $Test" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return $isAdmin
}

# Main test execution
try {
    Write-TestHeader "RHEL WSL Setup - Unprivileged Mode Test"
    
    # Check if running as admin (should not be)
    $isAdmin = Test-AdminPrivileges
    if ($isAdmin) {
        Write-Host "WARNING: You are running as Administrator!" -ForegroundColor $Colors.Warning
        Write-Host "This test is meant to verify unprivileged functionality." -ForegroundColor $Colors.Warning
        Write-Host "Consider running as a regular user for accurate testing." -ForegroundColor $Colors.Warning
    } else {
        Write-Host "✓ Running as regular user (good for this test)" -ForegroundColor $Colors.Success
    }
    
    $testResults = @()
    
    # Test 1: Basic PowerShell Module Loading
    Write-TestStep "PowerShell Module Loading" 1
    try {
        $ModulePath = Join-Path $PSScriptRoot "scripts\modules"
        if (Test-Path $ModulePath) {
            $modules = Get-ChildItem -Path $ModulePath -Filter "*.psm1"
            $loadedCount = 0
            foreach ($module in $modules) {
                try {
                    Import-Module $module.FullName -Force
                    $loadedCount++
                } catch {
                    Write-TestResult "Load $($module.BaseName)" $false $_.Exception.Message
                }
            }
            $allLoaded = $loadedCount -eq $modules.Count
            Write-TestResult "Module Loading" $allLoaded "$loadedCount/$($modules.Count) modules loaded"
            $testResults += @{ Test = "Module Loading"; Success = $allLoaded }
        } else {
            Write-TestResult "Module Directory" $false "Module path not found: $ModulePath"
            $testResults += @{ Test = "Module Loading"; Success = $false }
        }
    } catch {
        Write-TestResult "Module Loading" $false $_.Exception.Message
        $testResults += @{ Test = "Module Loading"; Success = $false }
    }
    
    # Test 2: Configuration File Loading
    Write-TestStep "Configuration File Loading" 2
    try {
        $ExampleConfigPath = Join-Path $PSScriptRoot "config\config.example.psd1"
        if (Test-Path $ExampleConfigPath) {
            $Config = Import-PowerShellDataFile -Path $ExampleConfigPath
            $hasRequiredSections = $Config.ContainsKey("RedHatAccess") -and $Config.ContainsKey("RHELDistributions")
            Write-TestResult "Example Config Load" $hasRequiredSections
            $testResults += @{ Test = "Config Loading"; Success = $hasRequiredSections }
        } else {
            Write-TestResult "Example Config File" $false "File not found: $ExampleConfigPath"
            $testResults += @{ Test = "Config Loading"; Success = $false }
        }
    } catch {
        Write-TestResult "Configuration Loading" $false $_.Exception.Message
        $testResults += @{ Test = "Config Loading"; Success = $false }
    }
    
    # Test 3: Basic WSL Functionality (Read-only)
    Write-TestStep "WSL Availability Check" 3
    try {
        $wslOutput = wsl --version 2>&1
        $wslAvailable = $LASTEXITCODE -eq 0
        Write-TestResult "WSL Command" $wslAvailable
        
        if ($wslAvailable) {
            $distros = wsl --list --quiet 2>$null
            $canListDistros = $LASTEXITCODE -eq 0
            Write-TestResult "List WSL Distributions" $canListDistros "Found $(@($distros).Count) distributions"
            $testResults += @{ Test = "WSL Basic Operations"; Success = $canListDistros }
        } else {
            $testResults += @{ Test = "WSL Basic Operations"; Success = $false }
        }
    } catch {
        Write-TestResult "WSL Operations" $false $_.Exception.Message
        $testResults += @{ Test = "WSL Basic Operations"; Success = $false }
    }
    
    # Test 4: Directory Creation (in user space)
    Write-TestStep "Directory Creation Test" 4
    try {
        $testDir = Join-Path $PSScriptRoot "test-temp"
        $downloadDir = Join-Path $testDir "downloads"
        $logDir = Join-Path $testDir "logs"
        
        New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        
        $dirsCreated = (Test-Path $downloadDir) -and (Test-Path $logDir)
        Write-TestResult "Directory Creation" $dirsCreated
        
        # Cleanup
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force
        }
        
        $testResults += @{ Test = "Directory Operations"; Success = $dirsCreated }
    } catch {
        Write-TestResult "Directory Creation" $false $_.Exception.Message
        $testResults += @{ Test = "Directory Operations"; Success = $false }
    }
    
    # Test 5: Network Connectivity
    Write-TestStep "Network Connectivity Test" 5
    try {
        $testUrls = @("https://access.redhat.com", "https://registry.redhat.io")
        $successCount = 0
        
        foreach ($url in $testUrls) {
            try {
                $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    $successCount++
                    Write-TestResult "Connect to $url" $true
                } else {
                    Write-TestResult "Connect to $url" $false "Status: $($response.StatusCode)"
                }
            } catch {
                Write-TestResult "Connect to $url" $false $_.Exception.Message
            }
        }
        
        $networkOK = $successCount -gt 0
        $testResults += @{ Test = "Network Connectivity"; Success = $networkOK }
    } catch {
        Write-TestResult "Network Test" $false $_.Exception.Message
        $testResults += @{ Test = "Network Connectivity"; Success = $false }
    }
    
    # Summary
    Write-TestHeader "Test Summary"
    
    $successCount = ($testResults | Where-Object { $_.Success }).Count
    $totalTests = $testResults.Count
    
    Write-Host "Results: $successCount/$totalTests tests passed" -ForegroundColor $Colors.Info
    Write-Host ""
    
    foreach ($result in $testResults) {
        $color = if ($result.Success) { $Colors.Success } else { $Colors.Error }
        $symbol = if ($result.Success) { "✓" } else { "✗" }
        Write-Host "$symbol $($result.Test)" -ForegroundColor $color
    }
    
    Write-Host ""
    if ($successCount -eq $totalTests) {
        Write-Host "🎉 All tests passed! The setup should work in unprivileged mode." -ForegroundColor $Colors.Success
        Write-Host "Note: WSL import operations may still require elevation depending on your system." -ForegroundColor $Colors.Warning
    } elseif ($successCount -gt 0) {
        Write-Host "⚠️  Some tests passed. Review failures above." -ForegroundColor $Colors.Warning
        Write-Host "The setup may work with some limitations." -ForegroundColor $Colors.Warning
    } else {
        Write-Host "❌ Most tests failed. Check your environment setup." -ForegroundColor $Colors.Error
    }
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor $Colors.Info
    Write-Host "1. If tests passed, try running: .\Initialize-Setup.ps1" -ForegroundColor $Colors.Info
    Write-Host "2. If WSL operations fail, try running as Administrator" -ForegroundColor $Colors.Info
    Write-Host "3. Check logs in the logs/ directory for detailed information" -ForegroundColor $Colors.Info

} catch {
    Write-Host "Test execution failed: $_" -ForegroundColor $Colors.Error
    exit 1
}
