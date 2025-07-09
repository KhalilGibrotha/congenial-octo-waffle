# ==============================================================================
# Red Hat Satellite Registration Module for RHEL WSL Setup
# ==============================================================================

function Register-WithSatellite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Starting Satellite registration for: $DistributionName" -Level INFO
    
    try {
        # Test connectivity to Satellite server
        if ($Config.TestConnectivity) {
            Write-Host "Testing connectivity to Satellite server..." -ForegroundColor Cyan
            $pingResult = Test-SatelliteConnectivity -DistributionName $DistributionName -Hostname $Config.Hostname
            
            if (-not $pingResult.Success) {
                Write-Host "Cannot reach Satellite server: $($pingResult.Error)" -ForegroundColor Yellow
                
                if ($Config.FallbackToDirectRH.Enabled) {
                    Write-Host "Attempting direct Red Hat registration..." -ForegroundColor Yellow
                    return Register-WithRedHatDirect -DistributionName $DistributionName -Config $Config.FallbackToDirectRH
                } else {
                    throw "Satellite server unreachable and fallback disabled"
                }
            }
        }
        
        # Check if already registered
        $statusCheck = wsl -d $DistributionName --exec bash -c "subscription-manager status" 2>&1
        $alreadyRegistered = $LASTEXITCODE -eq 0 -and $statusCheck -match "Overall Status: Current"
        
        if ($alreadyRegistered -and -not $Config.ForceRegistration) {
            Write-Host "System is already registered with Satellite" -ForegroundColor Green
            Write-Log -Message "System already registered, skipping registration" -Level INFO
            return @{ Success = $true; AlreadyRegistered = $true }
        }
        
        if ($alreadyRegistered -and $Config.ForceRegistration) {
            Write-Host "Force registration enabled, unregistering first..." -ForegroundColor Yellow
            wsl -d $DistributionName --exec bash -c "subscription-manager unregister" 2>$null
        }
        
        # Register with Satellite
        Write-Host "Registering with Red Hat Satellite..." -ForegroundColor Cyan
        $registerCmd = "subscription-manager register --org=$($Config.Organization) --activationkey=$($Config.ActivationKey) --serverurl=https://$($Config.Hostname)/rhsm --baseurl=https://$($Config.Hostname)/pulp/repos"
        
        $registerResult = wsl -d $DistributionName --exec bash -c $registerCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Registration failed: $registerResult"
        }
        
        Write-Log -Message "Successfully registered with Satellite" -Level INFO
        
        # Attach subscriptions
        Write-Host "Attaching subscriptions..." -ForegroundColor Cyan
        $attachResult = wsl -d $DistributionName --exec bash -c "subscription-manager attach --auto" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "Auto-attach failed, but registration succeeded: $attachResult" -Level WARN
        } else {
            Write-Log -Message "Successfully attached subscriptions" -Level INFO
        }
        
        # Verify registration
        $verifyResult = wsl -d $DistributionName --exec bash -c "subscription-manager status" 2>&1
        $registrationSuccessful = $LASTEXITCODE -eq 0
        
        if ($registrationSuccessful) {
            Write-Host "Satellite registration completed successfully" -ForegroundColor Green
            Write-Log -Message "Satellite registration verification passed" -Level INFO
            return @{ Success = $true; Method = "Satellite" }
        } else {
            throw "Registration verification failed: $verifyResult"
        }
        
    } catch {
        Write-Host "Satellite registration failed: $_" -ForegroundColor Red
        Write-Log -Message "Satellite registration failed: $_" -Level ERROR
        
        # Try fallback to direct Red Hat registration
        if ($Config.FallbackToDirectRH.Enabled) {
            Write-Host "Attempting fallback to direct Red Hat registration..." -ForegroundColor Yellow
            return Register-WithRedHatDirect -DistributionName $DistributionName -Config $Config.FallbackToDirectRH
        }
        
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Register-WithRedHatDirect {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Starting direct Red Hat registration for: $DistributionName" -Level INFO
    
    try {
        if ($Config.PromptForCredentials) {
            Write-Host "Direct Red Hat registration requires your Red Hat credentials" -ForegroundColor Yellow
            $username = Read-Host "Red Hat Username"
            $password = Read-Host "Red Hat Password" -AsSecureString
            $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
            
            # Register with username and password
            $registerCmd = "subscription-manager register --username=$username --password='$passwordText' --auto-attach"
        } else {
            throw "Direct registration requires credentials but prompting is disabled"
        }
        
        Write-Host "Registering directly with Red Hat..." -ForegroundColor Cyan
        $registerResult = wsl -d $DistributionName --exec bash -c $registerCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Direct registration failed: $registerResult"
        }
        
        Write-Host "Direct Red Hat registration completed successfully" -ForegroundColor Green
        Write-Log -Message "Direct Red Hat registration completed successfully" -Level INFO
        return @{ Success = $true; Method = "DirectRedHat" }
        
    } catch {
        Write-Host "Direct Red Hat registration failed: $_" -ForegroundColor Red
        Write-Log -Message "Direct Red Hat registration failed: $_" -Level ERROR
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-SatelliteConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [string]$Hostname
    )
    
    try {
        # Test ping to Satellite server
        $pingResult = wsl -d $DistributionName --exec bash -c "ping -c 3 $Hostname" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Satellite connectivity test passed" -Level INFO
            return @{ Success = $true }
        } else {
            Write-Log -Message "Satellite ping failed: $pingResult" -Level WARN
            return @{ Success = $false; Error = "Ping failed: $pingResult" }
        }
        
    } catch {
        Write-Log -Message "Error testing Satellite connectivity: $_" -Level ERROR
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Set-Repositories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistributionName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Log -Message "Configuring repositories for: $DistributionName" -Level INFO
    
    try {
        # Clean DNF cache
        if ($Config.CleanCache) {
            Write-Host "Cleaning DNF cache..." -ForegroundColor Cyan
            wsl -d $DistributionName --exec bash -c "dnf clean all"
            Write-Log -Message "Cleaned DNF cache" -Level INFO
        }
        
        # Enable CodeReady Builder repository
        if ($Config.EnableCodeReadyBuilder) {
            Write-Host "Enabling CodeReady Builder repository..." -ForegroundColor Cyan
            $crbResult = wsl -d $DistributionName --exec bash -c "subscription-manager repos --enable codeready-builder-for-rhel-*-rpms" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "Enabled CodeReady Builder repository" -Level INFO
            } else {
                Write-Log -Message "Failed to enable CodeReady Builder: $crbResult" -Level WARN
            }
        }
        
        # Install and enable EPEL
        if ($Config.EnableEPEL) {
            Write-Host "Installing and enabling EPEL repository..." -ForegroundColor Cyan
            
            # Install EPEL release package
            $epelInstallResult = wsl -d $DistributionName --exec bash -c "dnf install -y epel-release" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "Installed EPEL release package" -Level INFO
                
                # Enable EPEL repository
                $epelEnableResult = wsl -d $DistributionName --exec bash -c "subscription-manager repos --enable epel" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log -Message "Enabled EPEL repository" -Level INFO
                } else {
                    Write-Log -Message "EPEL repository enable attempt: $epelEnableResult" -Level INFO
                }
            } else {
                Write-Log -Message "Failed to install EPEL: $epelInstallResult" -Level WARN
            }
        }
        
        # Enable additional repositories
        foreach ($repo in $Config.AdditionalRepos) {
            Write-Host "Enabling repository: $repo" -ForegroundColor Cyan
            $repoResult = wsl -d $DistributionName --exec bash -c "subscription-manager repos --enable $repo" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "Enabled repository: $repo" -Level INFO
            } else {
                Write-Log -Message "Failed to enable repository $repo`: $repoResult" -Level WARN
            }
        }
        
        # Update system
        if ($Config.UpdateSystem) {
            Write-Host "Updating system packages..." -ForegroundColor Cyan
            $updateResult = wsl -d $DistributionName --exec bash -c "dnf update -y" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "System update completed successfully" -ForegroundColor Green
                Write-Log -Message "System update completed" -Level INFO
            } else {
                Write-Log -Message "System update had issues: $updateResult" -Level WARN
            }
        }
        
        Write-Host "Repository configuration completed" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Repository configuration failed: $_" -ForegroundColor Red
        Write-Log -Message "Repository configuration failed: $_" -Level ERROR
        return $false
    }
}

Export-ModuleMember -Function Register-WithSatellite, Register-WithRedHatDirect, Test-SatelliteConnectivity, Set-Repositories
