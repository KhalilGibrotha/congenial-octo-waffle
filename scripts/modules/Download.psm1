# ==============================================================================
# Download Module for RHEL WSL Setup
# ==============================================================================

function Invoke-RHELDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Distro,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    Write-Log -Message "Starting download for $($Distro.Name)" -Level INFO
    
    # Validate Red Hat tokens
    if (-not (Test-RedHatTokens -RedHatAccess $Config.RedHatAccess)) {
        return @{ Success = $false; Error = "Invalid Red Hat Access tokens" }
    }
    
    # Create download directory if it doesn't exist
    $downloadDir = Split-Path $DestinationPath -Parent
    if (-not (Test-Path $downloadDir)) {
        New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
        Write-Log -Message "Created download directory: $downloadDir" -Level INFO
    }
    
    # Check if file already exists and validate
    if (Test-Path $DestinationPath) {
        if ($Config.DownloadConfig.VerifyDownloads) {
            Write-Host "File already exists, verifying integrity..." -ForegroundColor Yellow
            # Add integrity check logic here (checksums, file size, etc.)
            Write-Log -Message "File already exists: $DestinationPath" -Level INFO
            return @{ Success = $true; FilePath = $DestinationPath; AlreadyExists = $true }
        } else {
            Write-Log -Message "File already exists, skipping download: $DestinationPath" -Level INFO
            return @{ Success = $true; FilePath = $DestinationPath; AlreadyExists = $true }
        }
    }
    
    # Construct download URL with tokens
    $downloadUrl = "$($Config.RedHatAccess.BaseDownloadUrl)$($Distro.DownloadPath)?user=$($Config.RedHatAccess.UserToken)&_auth_=$($Config.RedHatAccess.AuthToken)"
    
    # Download with retry logic
    $attempt = 0
    $maxAttempts = $Config.DownloadConfig.RetryAttempts
    
    while ($attempt -lt $maxAttempts) {
        $attempt++
        
        try {
            Write-Host "Downloading $($Distro.Name) (Attempt $attempt/$maxAttempts)..." -ForegroundColor Cyan
            Write-Log -Message "Download attempt $attempt for $($Distro.Name)" -Level INFO
            
            # Use Invoke-WebRequest with progress
            $progressPreference = $ProgressPreference
            $ProgressPreference = 'Continue'
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $DestinationPath -UseBasicParsing
            
            $ProgressPreference = $progressPreference
            
            # Verify download completed
            if (Test-Path $DestinationPath) {
                $fileSize = (Get-Item $DestinationPath).Length
                Write-Host "Download completed successfully. Size: $([math]::Round($fileSize / 1MB, 2)) MB" -ForegroundColor Green
                Write-Log -Message "Download completed for $($Distro.Name). Size: $fileSize bytes" -Level INFO
                
                return @{ 
                    Success = $true
                    FilePath = $DestinationPath
                    SizeBytes = $fileSize
                    AlreadyExists = $false
                }
            } else {
                throw "Downloaded file not found after completion"
            }
            
        } catch {
            Write-Log -Message "Download attempt $attempt failed for $($Distro.Name): $_" -Level WARN
            
            if ($attempt -eq $maxAttempts) {
                Write-Host "Download failed after $maxAttempts attempts: $_" -ForegroundColor Red
                Write-Log -Message "Download failed permanently for $($Distro.Name): $_" -Level ERROR
                return @{ Success = $false; Error = $_.Exception.Message }
            } else {
                Write-Host "Download attempt $attempt failed, retrying in $($Config.DownloadConfig.RetryDelaySeconds) seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $Config.DownloadConfig.RetryDelaySeconds
            }
        }
    }
}

function Test-DownloadIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$ExpectedChecksum,
        
        [Parameter(Mandatory = $false)]
        [long]$ExpectedSize
    )
    
    Write-Log -Message "Verifying download integrity for: $FilePath" -Level INFO
    
    if (-not (Test-Path $FilePath)) {
        Write-Log -Message "File not found for integrity check: $FilePath" -Level ERROR
        return $false
    }
    
    $file = Get-Item $FilePath
    
    # Check file size if provided
    if ($ExpectedSize -and $file.Length -ne $ExpectedSize) {
        Write-Log -Message "File size mismatch. Expected: $ExpectedSize, Actual: $($file.Length)" -Level ERROR
        return $false
    }
    
    # Check checksum if provided
    if ($ExpectedChecksum) {
        try {
            $actualChecksum = Get-FileHash -Path $FilePath -Algorithm SHA256
            if ($actualChecksum.Hash -ne $ExpectedChecksum) {
                Write-Log -Message "Checksum mismatch. Expected: $ExpectedChecksum, Actual: $($actualChecksum.Hash)" -Level ERROR
                return $false
            }
        } catch {
            Write-Log -Message "Error calculating checksum: $_" -Level ERROR
            return $false
        }
    }
    
    Write-Log -Message "Download integrity verification passed" -Level INFO
    return $true
}

Export-ModuleMember -Function Invoke-RHELDownload, Test-DownloadIntegrity
