# RHEL WSL Automated Setup

## Quick Start

1. **Configure Red Hat Access Tokens**
   ```powershell
   # Copy example configuration
   Copy-Item .\config\config.example.psd1 .\config\config.psd1
   
   # Edit config.psd1 with your Red Hat Access tokens
   notepad .\config\config.psd1
   ```

2. **Run Setup Script**
   ```powershell
   # Run as Administrator
   .\Setup-RHEL-WSL.ps1
   ```

3. **First Login**
   ```bash
   # Launch your new WSL distribution
   wsl -d RHEL9
   
   # Change password when prompted
   # Activate Python environment
   source /home/your-user/activate-venv.sh
   ```

## Configuration Variables Reference

### Red Hat Access Tokens
- `UserToken`: Your Red Hat Access user token
- `AuthToken`: Your Red Hat Access authentication token

**How to get tokens:**
1. Go to [access.redhat.com](https://access.redhat.com)
2. Navigate to RHEL WSL downloads
3. Copy `user=` and `_auth_=` parameters from download URLs

### Distribution Configuration
```powershell
RHELDistributions = @{
    RHEL9 = @{
        Name = "RHEL9"              # WSL distribution name
        Version = "9"               # RHEL version
        FileName = "rhel-9-wsl.tar.gz"  # Downloaded file name
        DownloadPath = "/path/from/redhat"  # Path from Red Hat Access URL
        InstallPath = "C:\WSL\RHEL9"    # Where to install WSL distribution
        Enabled = $true             # Whether to process this distribution
    }
}
```

### Satellite Configuration
```powershell
SatelliteConfig = @{
    Enabled = $true
    Hostname = "satellite.yourcompany.com"
    Organization = "YourOrg"
    ActivationKey = "your-activation-key"
    ForceRegistration = $false
    TestConnectivity = $true
    
    FallbackToDirectRH = @{
        Enabled = $true
        PromptForCredentials = $true
    }
}
```

### Python Environment
```powershell
PythonConfig = @{
    Enabled = $true
    VenvPath = "/opt/custom_venv"
    VenvOwner = "rhel-user"
    VenvGroup = "rhel-user"
    
    CustomWheel = @{
        Enabled = $true
        WindowsPath = "C:\path\to\your\custom_wheel.whl"
        WSLTempPath = "/tmp/custom_wheel.whl"
        CleanupAfterInstall = $true
    }
}
```

## Folder Structure

```
congenial-octo-waffle/
├── Setup-RHEL-WSL.ps1          # Main setup script
├── config/
│   ├── config.psd1             # Your configuration (create from example)
│   └── config.example.psd1     # Example configuration
├── scripts/
│   └── modules/
│       ├── Logging.psm1        # Logging functionality
│       ├── Validation.psm1     # Environment validation
│       ├── Download.psm1       # RHEL image downloads
│       ├── WSLManagement.psm1  # WSL operations
│       ├── SatelliteRegistration.psm1  # Satellite integration
│       └── PythonEnvironment.psm1      # Python setup
├── downloads/                  # Downloaded RHEL images
├── logs/                      # Setup logs
├── backups/                   # WSL distribution backups
└── templates/                 # Configuration templates
```

## Example Usage Scenarios

### Scenario 1: Basic RHEL 9 Setup
```powershell
# Minimal configuration for RHEL 9 only
$config = @{
    RHELDistributions = @{
        RHEL9 = @{ ... }
    }
    SatelliteConfig = @{ Enabled = $false }
    PythonConfig = @{ Enabled = $false }
}
```

### Scenario 2: Development Environment with Analytics
```powershell
# Full setup with custom Python analytics package
$config = @{
    RHELDistributions = @{ RHEL9 = @{ ... } }
    SatelliteConfig = @{ Enabled = $true; ... }
    PythonConfig = @{
        Enabled = $true
        CustomWheel = @{
            WindowsPath = "C:\analytics\analytics-package.whl"
        }
    }
}
```

### Scenario 3: Multiple RHEL Versions
```powershell
# Setup both RHEL 8 and 9
$config = @{
    RHELDistributions = @{
        RHEL8 = @{ Enabled = $true; ... }
        RHEL9 = @{ Enabled = $true; ... }
    }
}
```

## Troubleshooting

### Common Issues

1. **Red Hat Access Tokens Expired**
   - Tokens expire after a few hours
   - Get fresh tokens from access.redhat.com
   - Update config.psd1 with new tokens

2. **WSL Import Fails**
   - Check if WSL 2 is enabled
   - Verify file integrity of downloaded RHEL image
   - Ensure sufficient disk space

3. **Satellite Registration Fails**
   - Verify network connectivity to Satellite server
   - Check organization and activation key
   - Enable fallback to direct Red Hat registration

4. **Python Environment Issues**
   - Verify custom wheel file path exists
   - Check file permissions in WSL
   - Review logs for detailed error messages

### Log Analysis
```powershell
# View latest log
Get-Content .\logs\rhel-wsl-setup-*.log | Select-Object -Last 50

# Search for errors
Select-String -Path .\logs\*.log -Pattern "ERROR"
```

## Advanced Configuration

### Custom Repository Sources
Add custom repositories to the configuration:

```powershell
RepositoryConfig = @{
    AdditionalRepos = @(
        "rhel-9-for-x86_64-supplementary-rpms",
        "rhel-9-for-x86_64-optional-rpms"
    )
}
```

### Custom Validation Tests
Add custom validation commands:

```powershell
AdvancedConfig = @{
    TestCommands = @(
        "cat /etc/redhat-release",
        "subscription-manager status",
        "python3 --version",
        "curl --version",
        "git --version"
    )
}
```

### Parallel Processing
Configure multiple distributions to be processed simultaneously:

```powershell
AdvancedConfig = @{
    MaxConcurrentDistributions = 2
}
```
