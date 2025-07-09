#Requires -Version 5.1
# Note: Administrator privileges are only required for certain operations
# The script will check and prompt for elevation if needed

<#
.SYNOPSIS
    Automated RHEL WSL Distribution Setup Script

.DESCRIPTION
    This script automates the process of setting up Red Hat Enterprise Linux (RHEL) 
    distributions within Windows Subsystem for Linux (WSL). It handles downloading 
    RHEL WSL images, importing them, configuring users, and integrating with Red Hat 
    Satellite for content management.

.PARAMETER ConfigPath
    Path to the configuration file (config.psd1). Defaults to .\config\config.psd1

.PARAMETER LogPath
    Override the log path specified in configuration

.PARAMETER WhatIf
    Show what would be done without actually performing actions

.PARAMETER Force
    Skip confirmation prompts and force operations

.EXAMPLE
    .\Setup-RHEL-WSL.ps1
    
.EXAMPLE
    .\Setup-RHEL-WSL.ps1 -ConfigPath ".\custom-config.psd1" -Force

.NOTES
    Author: Your Organization
    Version: 1.0.0
    Last Modified: $(Get-Date -Format 'yyyy-MM-dd')
    
    Prerequisites:
    - Windows 10/11 with WSL 2 enabled
    - Valid Red Hat Access tokens in configuration
    - Administrator privileges may be required for some WSL operations
    - Red Hat Satellite server (optional)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ConfigPath = ".\config\config.psd1",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ==============================================================================
# SCRIPT INITIALIZATION
# ==============================================================================

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import required modules
$ModulePath = Join-Path $PSScriptRoot "scripts\modules"
Get-ChildItem -Path $ModulePath -Filter "*.psm1" | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Load configuration
try {
    Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Green
    $Config = Import-PowerShellDataFile -Path $ConfigPath
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to load configuration file: $_"
    exit 1
}

# Initialize logging
if ($LogPath) {
    $Config.LoggingConfig.LogPath = $LogPath
}

if ($Config.LoggingConfig.Enabled) {
    Initialize-Logging -Config $Config.LoggingConfig
    Write-Log -Message "RHEL WSL Setup Started" -Level INFO
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

try {
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "RHEL WSL Automated Setup Script" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    
    # Step 1: Environment Validation
    Write-Host "`n[1/6] Validating Environment..." -ForegroundColor Yellow
    if (-not (Test-Environment -Config $Config.ValidationConfig)) {
        throw "Environment validation failed. Please check the requirements."
    }
    Write-Host "Environment validation passed" -ForegroundColor Green
    
    # Step 2: Download RHEL Images
    Write-Host "`n[2/6] Downloading RHEL Images..." -ForegroundColor Yellow
    $DownloadResults = @{}
    foreach ($distroName in $Config.RHELDistributions.Keys) {
        $distro = $Config.RHELDistributions[$distroName]
        if ($distro.Enabled) {
            Write-Host "Downloading $($distro.Name)..." -ForegroundColor Cyan
            $downloadPath = Join-Path $Config.DownloadConfig.DownloadPath $distro.FileName
            $DownloadResults[$distroName] = Invoke-RHELDownload -Distro $distro -Config $Config -DestinationPath $downloadPath
        }
    }
    
    # Step 3: Import WSL Distributions
    Write-Host "`n[3/6] Importing WSL Distributions..." -ForegroundColor Yellow
    $ImportResults = @{}
    foreach ($distroName in $DownloadResults.Keys) {
        if ($DownloadResults[$distroName].Success) {
            $distro = $Config.RHELDistributions[$distroName]
            Write-Host "Importing $($distro.Name) to WSL..." -ForegroundColor Cyan
            $ImportResults[$distroName] = Import-WSLDistribution -Distro $distro -Config $Config -SourcePath $DownloadResults[$distroName].FilePath
        }
    }
    
    # Step 4: Configure Initial Users
    Write-Host "`n[4/6] Configuring Initial Users..." -ForegroundColor Yellow
    foreach ($distroName in $ImportResults.Keys) {
        if ($ImportResults[$distroName].Success) {
            $distro = $Config.RHELDistributions[$distroName]
            Write-Host "Configuring user for $($distro.Name)..." -ForegroundColor Cyan
            Set-WSLUser -DistributionName $distro.Name -Config $Config.WSLConfig
        }
    }
    
    # Step 5: Advanced Configuration (Satellite, Repositories, Python)
    Write-Host "`n[5/6] Running Advanced Configuration..." -ForegroundColor Yellow
    foreach ($distroName in $ImportResults.Keys) {
        if ($ImportResults[$distroName].Success) {
            $distro = $Config.RHELDistributions[$distroName]
            Write-Host "Advanced configuration for $($distro.Name)..." -ForegroundColor Cyan
            
            # Satellite Registration
            if ($Config.SatelliteConfig.Enabled) {
                Register-WithSatellite -DistributionName $distro.Name -Config $Config.SatelliteConfig
            }
            
            # Repository Configuration
            if ($Config.RepositoryConfig.EnableCodeReadyBuilder -or $Config.RepositoryConfig.EnableEPEL) {
                Set-Repositories -DistributionName $distro.Name -Config $Config.RepositoryConfig
            }
            
            # Python Virtual Environment
            if ($Config.PythonConfig.Enabled) {
                Set-PythonEnvironment -DistributionName $distro.Name -Config $Config.PythonConfig
            }
        }
    }
    
    # Step 6: Validation and Cleanup
    Write-Host "`n[6/6] Final Validation and Cleanup..." -ForegroundColor Yellow
    if ($Config.AdvancedConfig.ValidateAfterSetup) {
        foreach ($distroName in $ImportResults.Keys) {
            if ($ImportResults[$distroName].Success) {
                $distro = $Config.RHELDistributions[$distroName]
                Write-Host "Validating $($distro.Name)..." -ForegroundColor Cyan
                Test-WSLDistribution -DistributionName $distro.Name -Config $Config.AdvancedConfig
            }
        }
    }
    
    # Summary Report
    Write-Host "`n===================================================" -ForegroundColor Green
    Write-Host "SETUP COMPLETE - SUMMARY REPORT" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
    
    foreach ($distroName in $Config.RHELDistributions.Keys) {
        $distro = $Config.RHELDistributions[$distroName]
        if ($distro.Enabled) {
            $status = if ($ImportResults[$distroName] -and $ImportResults[$distroName].Success) { "SUCCESS" } else { "FAILED" }
            $color = if ($status -eq "SUCCESS") { "Green" } else { "Red" }
            Write-Host "$($distro.Name): $status" -ForegroundColor $color
        }
    }
    
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Launch WSL: wsl -d RHEL9 (or your preferred distribution)" -ForegroundColor White
    Write-Host "2. Login with user: $($Config.WSLConfig.DefaultUser)" -ForegroundColor White
    Write-Host "3. Change password when prompted" -ForegroundColor White
    Write-Host "4. Verify Satellite registration: subscription-manager status" -ForegroundColor White
    
    Write-Log -Message "RHEL WSL Setup Completed Successfully" -Level INFO

} catch {
    Write-Error "Script execution failed: $_"
    Write-Log -Message "Script execution failed: $_" -Level ERROR
    exit 1
} finally {
    # Cleanup operations
    if ($Config.LoggingConfig.Enabled) {
        Write-Log -Message "Script execution finished" -Level INFO
    }
}

Write-Host "`nScript execution completed. Check logs for detailed information." -ForegroundColor Green
