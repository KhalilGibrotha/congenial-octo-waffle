# ==============================================================================
# Environment Validation Module for RHEL WSL Setup
# ==============================================================================

function Test-Environment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Starting environment validation" -Level INFO
    $validationResults = @()
    
    # Test 1: Administrator Rights
    if ($Config.CheckAdminRights) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $validationResults += [PSCustomObject]@{
            Test = "Administrator Rights"
            Status = $isAdmin
            Message = if ($isAdmin) { "Running as Administrator" } else { "Not running as Administrator (may be required for some WSL operations)" }
        }
        Write-Log -Message "Administrator check: $isAdmin" -Level INFO
        
        if (-not $isAdmin) {
            Write-Host "Note: Some WSL operations may require administrator privileges." -ForegroundColor Yellow
            Write-Host "If you encounter permission errors, try running as Administrator." -ForegroundColor Yellow
        }
    }
    
    # Test 2: WSL Installation and Version
    if ($Config.CheckWSLVersion) {
        try {
            $wslOutput = wsl --version 2>&1
            $wslInstalled = $LASTEXITCODE -eq 0
            
            if ($wslInstalled -and $wslOutput -match "WSL version: ([\d\.]+)") {
                $wslVersion = [version]$matches[1]
                $minVersion = [version]$Config.MinimumWSLVersion
                $versionOK = $wslVersion -ge $minVersion
                
                $validationResults += [PSCustomObject]@{
                    Test = "WSL Version"
                    Status = $versionOK
                    Message = "WSL $wslVersion (Required: $minVersion+)"
                }
                Write-Log -Message "WSL version check: $wslVersion (Required: $minVersion+)" -Level INFO
            } else {
                $validationResults += [PSCustomObject]@{
                    Test = "WSL Installation"
                    Status = $false
                    Message = "WSL not installed or not accessible"
                }
                Write-Log -Message "WSL not found or not accessible" -Level ERROR
            }
        } catch {
            $validationResults += [PSCustomObject]@{
                Test = "WSL Installation"
                Status = $false
                Message = "Error checking WSL: $_"
            }
            Write-Log -Message "Error checking WSL: $_" -Level ERROR
        }
    }
    
    # Test 3: Disk Space
    if ($Config.CheckDiskSpace) {
        try {
            $drive = (Get-Location).Drive
            $freeSpaceGB = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($drive.Name)'").FreeSpace / 1GB, 2)
            $spaceOK = $freeSpaceGB -ge $Config.MinimumDiskSpaceGB
            
            $validationResults += [PSCustomObject]@{
                Test = "Disk Space"
                Status = $spaceOK
                Message = "$freeSpaceGB GB available (Required: $($Config.MinimumDiskSpaceGB) GB)"
            }
            Write-Log -Message "Disk space check: $freeSpaceGB GB available" -Level INFO
        } catch {
            $validationResults += [PSCustomObject]@{
                Test = "Disk Space"
                Status = $false
                Message = "Error checking disk space: $_"
            }
            Write-Log -Message "Error checking disk space: $_" -Level ERROR
        }
    }
    
    # Test 4: Internet Connectivity
    if ($Config.CheckInternetConnectivity) {
        foreach ($url in $Config.TestUrls) {
            try {
                $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -UseBasicParsing
                $connected = $response.StatusCode -eq 200
                
                $validationResults += [PSCustomObject]@{
                    Test = "Connectivity to $url"
                    Status = $connected
                    Message = if ($connected) { "Connection successful" } else { "Connection failed" }
                }
                Write-Log -Message "Connectivity test to $url`: $connected" -Level INFO
            } catch {
                $validationResults += [PSCustomObject]@{
                    Test = "Connectivity to $url"
                    Status = $false
                    Message = "Connection failed: $_"
                }
                Write-Log -Message "Connectivity test to $url failed: $_" -Level WARN
            }
        }
    }
    
    # Display Results
    Write-Host "`nEnvironment Validation Results:" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    foreach ($result in $validationResults) {
        $color = if ($result.Status) { "Green" } else { "Red" }
        $symbol = if ($result.Status) { "✓" } else { "✗" }
        Write-Host "$symbol $($result.Test): $($result.Message)" -ForegroundColor $color
    }
    
    $allPassed = ($validationResults | Where-Object { -not $_.Status -and $_.Test -ne "Administrator Rights" }).Count -eq 0
    $adminWarning = ($validationResults | Where-Object { $_.Test -eq "Administrator Rights" -and -not $_.Status }).Count -gt 0
    
    if ($allPassed) {
        Write-Host "`nAll critical validation checks passed!" -ForegroundColor Green
        if ($adminWarning) {
            Write-Host "Warning: Not running as Administrator - some operations may require elevation" -ForegroundColor Yellow
        }
        Write-Log -Message "Environment validation passed (admin warning: $adminWarning)" -Level INFO
    } else {
        Write-Host "`nSome critical validation checks failed. Please address the issues above." -ForegroundColor Red
        Write-Log -Message "Environment validation failed" -Level ERROR
    }
    
    return $allPassed
}

function Test-RedHatTokens {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$RedHatAccess
    )
    
    Write-Log -Message "Validating Red Hat Access tokens" -Level INFO
    
    if ($RedHatAccess.UserToken -eq "REPLACE_WITH_YOUR_USER_TOKEN" -or 
        $RedHatAccess.AuthToken -eq "REPLACE_WITH_YOUR_AUTH_TOKEN") {
        Write-Host "Red Hat Access tokens need to be updated in configuration!" -ForegroundColor Red
        Write-Host "Please visit access.redhat.com and update the tokens in config.psd1" -ForegroundColor Yellow
        Write-Log -Message "Red Hat Access tokens not configured" -Level ERROR
        return $false
    }
    
    Write-Log -Message "Red Hat Access tokens appear to be configured" -Level INFO
    return $true
}

Export-ModuleMember -Function Test-Environment, Test-RedHatTokens
