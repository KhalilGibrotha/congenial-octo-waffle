# ==============================================================================
# Logging Module for RHEL WSL Setup
# ==============================================================================

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path $Config.LogPath)) {
        New-Item -Path $Config.LogPath -ItemType Directory -Force | Out-Null
    }
    
    # Generate log filename with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $global:LogFileName = $Config.LogFileName -f $timestamp
    $global:LogFilePath = Join-Path $Config.LogPath $global:LogFileName
    $global:LogLevel = $Config.LogLevel
    
    # Clean up old log files
    if ($Config.MaxLogFiles -gt 0) {
        Get-ChildItem -Path $Config.LogPath -Filter "rhel-wsl-setup-*.log" | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -Skip $Config.MaxLogFiles | 
            Remove-Item -Force
    }
    
    Write-Log -Message "Logging initialized: $global:LogFilePath" -Level INFO
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    if (-not $global:LogFilePath) {
        return
    }
    
    $levelOrder = @{ "DEBUG" = 0; "INFO" = 1; "WARN" = 2; "ERROR" = 3 }
    $currentLevelOrder = $levelOrder[$global:LogLevel]
    $messageLevelOrder = $levelOrder[$Level]
    
    if ($messageLevelOrder -ge $currentLevelOrder) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $global:LogFilePath -Value $logEntry
        
        # Also write to console for important messages
        if ($Level -in @("WARN", "ERROR")) {
            $color = if ($Level -eq "WARN") { "Yellow" } else { "Red" }
            Write-Host $logEntry -ForegroundColor $color
        } elseif ($Level -eq "DEBUG" -and $global:LogLevel -eq "DEBUG") {
            Write-Host $logEntry -ForegroundColor Gray
        }
    }
}

Export-ModuleMember -Function Initialize-Logging, Write-Log
