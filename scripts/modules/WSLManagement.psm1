# ==============================================================================
# WSL Management Module for RHEL WSL Setup
# ==============================================================================

function Import-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Distro,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )
    
    Write-Log -Message "Starting WSL import for $($Distro.Name)" -Level INFO
    
    # Verify source file exists
    if (-not (Test-Path $SourcePath)) {
        Write-Log -Message "Source file not found: $SourcePath" -Level ERROR
        return @{ Success = $false; Error = "Source file not found" }
    }
    
    # Create installation directory
    if (-not (Test-Path $Distro.InstallPath)) {
        New-Item -Path $Distro.InstallPath -ItemType Directory -Force | Out-Null
        Write-Log -Message "Created installation directory: $($Distro.InstallPath)" -Level INFO
    }
    
    # Check if distribution already exists
    $existingDistros = wsl --list --quiet 2>$null
    if ($existingDistros -contains $Distro.Name) {
        Write-Host "WSL distribution '$($Distro.Name)' already exists" -ForegroundColor Yellow
        
        if ($Config.AdvancedConfig.BackupExistingDistributions) {
            Write-Host "Backing up existing distribution..." -ForegroundColor Cyan
            $backupResult = Backup-WSLDistribution -DistributionName $Distro.Name -Config $Config
            if (-not $backupResult.Success) {
                Write-Log -Message "Failed to backup existing distribution: $($backupResult.Error)" -Level ERROR
                return @{ Success = $false; Error = "Backup failed: $($backupResult.Error)" }
            }
        }
        
        # Unregister existing distribution
        Write-Host "Unregistering existing distribution..." -ForegroundColor Yellow
        try {
            wsl --unregister $Distro.Name
            if ($LASTEXITCODE -ne 0) {
                throw "wsl --unregister failed with exit code $LASTEXITCODE"
            }
            Write-Log -Message "Successfully unregistered existing distribution: $($Distro.Name)" -Level INFO
        } catch {
            Write-Log -Message "Failed to unregister existing distribution: $_" -Level ERROR
            return @{ Success = $false; Error = "Failed to unregister: $_" }
        }
    }
    
    # Import the distribution
    try {
        Write-Host "Importing $($Distro.Name) to WSL..." -ForegroundColor Cyan
        Write-Log -Message "Importing WSL distribution: $($Distro.Name)" -Level INFO
        
        wsl --import $Distro.Name $Distro.InstallPath $SourcePath
        
        if ($LASTEXITCODE -ne 0) {
            # Check if this might be a permission issue
            if ($LASTEXITCODE -eq 5) {
                throw "WSL import failed with access denied (exit code 5). Try running as Administrator."
            } else {
                throw "wsl --import failed with exit code $LASTEXITCODE"
            }
        }
        
        # Verify import was successful
        $importedDistros = wsl --list --quiet 2>$null
        if ($importedDistros -contains $Distro.Name) {
            Write-Host "Successfully imported $($Distro.Name)" -ForegroundColor Green
            Write-Log -Message "Successfully imported WSL distribution: $($Distro.Name)" -Level INFO
            
            # Set as default if configured
            if ($Config.AdvancedConfig.SetAsDefault) {
                wsl --set-default $Distro.Name
                Write-Log -Message "Set $($Distro.Name) as default WSL distribution" -Level INFO
            }
            
            return @{ 
                Success = $true
                DistributionName = $Distro.Name
                InstallPath = $Distro.InstallPath
            }
        } else {
            throw "Distribution not found in WSL list after import"
        }
        
    } catch {
        Write-Host "Failed to import $($Distro.Name): $_" -ForegroundColor Red
        Write-Log -Message "Failed to import WSL distribution $($Distro.Name): $_" -Level ERROR
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Set-WSLUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Configuring user for distribution: $DistributionName" -Level INFO
    
    try {
        # Create user with home directory
        $createUserCmd = "useradd -m -s /bin/bash $($Config.DefaultUser)"
        $result = wsl -d $DistributionName --exec bash -c $createUserCmd
        
        if ($LASTEXITCODE -ne 0) {
            # User might already exist, try to verify
            $checkUserCmd = "id $($Config.DefaultUser)"
            $userCheck = wsl -d $DistributionName --exec bash -c $checkUserCmd 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "User $($Config.DefaultUser) already exists" -Level INFO
            } else {
                throw "Failed to create user and user doesn't exist"
            }
        } else {
            Write-Log -Message "Created user: $($Config.DefaultUser)" -Level INFO
        }
        
        # Set password
        $setPasswordCmd = "echo '$($Config.DefaultUser):$($Config.DefaultPassword)' | chpasswd"
        wsl -d $DistributionName --exec bash -c $setPasswordCmd
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set password for user"
        }
        
        Write-Log -Message "Set password for user: $($Config.DefaultUser)" -Level INFO
        
        # Force password change on first login
        if ($Config.RequirePasswordChange) {
            $expirePasswordCmd = "chage -d 0 $($Config.DefaultUser)"
            wsl -d $DistributionName --exec bash -c $expirePasswordCmd
            Write-Log -Message "Set password to expire on first login" -Level INFO
        }
        
        # Add to sudoers
        if ($Config.AddToSudoers) {
            $sudoersCmd = "echo '$($Config.DefaultUser) ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/$($Config.DefaultUser)"
            wsl -d $DistributionName --exec bash -c $sudoersCmd
            Write-Log -Message "Added user to sudoers" -Level INFO
        }
        
        # Set default user for the distribution
        wsl --set-default-user $DistributionName $Config.DefaultUser
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Set default user for distribution" -Level INFO
        }
        
        Write-Host "User configuration completed for $DistributionName" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Failed to configure user for $DistributionName`: $_" -ForegroundColor Red
        Write-Log -Message "Failed to configure user for $DistributionName`: $_" -Level ERROR
        return $false
    }
}

function Backup-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Creating backup of WSL distribution: $DistributionName" -Level INFO
    
    try {
        # Create backup directory
        $backupDir = $Config.AdvancedConfig.BackupPath
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }
        
        # Generate backup filename with timestamp
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFileName = "$DistributionName-backup-$timestamp.tar"
        $backupPath = Join-Path $backupDir $backupFileName
        
        # Export the distribution
        wsl --export $DistributionName $backupPath
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $backupPath)) {
            Write-Log -Message "Successfully created backup: $backupPath" -Level INFO
            return @{ Success = $true; BackupPath = $backupPath }
        } else {
            throw "Export command failed or backup file not created"
        }
        
    } catch {
        Write-Log -Message "Failed to create backup of $DistributionName`: $_" -Level ERROR
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Testing WSL distribution: $DistributionName" -Level INFO
    
    $testResults = @()
    
    foreach ($testCommand in $Config.TestCommands) {
        try {
            Write-Host "Testing: $testCommand" -ForegroundColor Cyan
            $output = wsl -d $DistributionName --exec bash -c $testCommand 2>&1
            
            $success = $LASTEXITCODE -eq 0
            $testResults += [PSCustomObject]@{
                Command = $testCommand
                Success = $success
                Output = $output
            }
            
            $color = if ($success) { "Green" } else { "Red" }
            $symbol = if ($success) { "✓" } else { "✗" }
            Write-Host "$symbol $testCommand`: $($success)" -ForegroundColor $color
            
            if ($success) {
                Write-Log -Message "Test passed - $testCommand" -Level INFO
            } else {
                Write-Log -Message "Test failed - $testCommand`: $output" -Level WARN
            }
            
        } catch {
            $testResults += [PSCustomObject]@{
                Command = $testCommand
                Success = $false
                Output = $_.Exception.Message
            }
            Write-Log -Message "Test error - $testCommand`: $_" -Level ERROR
        }
    }
    
    $passedTests = ($testResults | Where-Object Success).Count
    $totalTests = $testResults.Count
    
    Write-Host "Test Results: $passedTests/$totalTests passed" -ForegroundColor Cyan
    Write-Log -Message "Distribution test results: $passedTests/$totalTests passed" -Level INFO
    
    return $testResults
}

Export-ModuleMember -Function Import-WSLDistribution, Set-WSLUser, Backup-WSLDistribution, Test-WSLDistribution
