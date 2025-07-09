#Requires -Version 5.1

<#
.SYNOPSIS
    Initial Setup Helper for RHEL WSL Automated Setup

.DESCRIPTION
    This script helps users set up their initial configuration by:
    1. Copying the example configuration if needed
    2. Guiding users to get Red Hat Access tokens
    3. Optionally opening the configuration file for editing

.PARAMETER OpenConfig
    Automatically open the configuration file for editing after setup

.PARAMETER Force
    Overwrite existing configuration file if it exists

.EXAMPLE
    .\Initialize-Setup.ps1
    
.EXAMPLE
    .\Initialize-Setup.ps1 -OpenConfig

.EXAMPLE
    .\Initialize-Setup.ps1 -Force -OpenConfig

.NOTES
    Author: RHEL WSL Setup Project
    Version: 1.0.0
    Last Modified: July 9, 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$OpenConfig,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Script paths
$ScriptRoot = $PSScriptRoot
$ExampleConfigPath = Join-Path $ScriptRoot "config\config.example.psd1"
$ConfigPath = Join-Path $ScriptRoot "config\config.psd1"
$ConfigDir = Join-Path $ScriptRoot "config"

# Colors for output
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
    Prompt = "Magenta"
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n===================================================" -ForegroundColor $Colors.Header
    Write-Host $Message -ForegroundColor $Colors.Header
    Write-Host "===================================================" -ForegroundColor $Colors.Header
}

function Write-Step {
    param([string]$Message, [int]$Step)
    Write-Host "`n[$Step] $Message" -ForegroundColor $Colors.Info
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $Colors.Info
}

function Show-TokenInstructions {
    Write-Header "Red Hat Access Token Instructions"
    
    Write-Host @"
To get your Red Hat Access tokens, follow these steps:

1. 📋 OPEN RED HAT ACCESS WEBSITE
   Open your web browser and go to: https://access.redhat.com

2. 🔐 LOGIN TO YOUR ACCOUNT
   Sign in with your Red Hat developer account
   (If you don't have one, create a free developer account)

3. 📥 NAVIGATE TO RHEL WSL DOWNLOADS
   Go to: Products → Red Hat Enterprise Linux → Downloads
   Look for "Red Hat Enterprise Linux for WSL" section

4. 🔍 FIND THE DOWNLOAD LINKS
   Locate the RHEL version you want (RHEL 8, 9, or 10)
   RIGHT-CLICK on the download link and select "Copy Link Address"

5. 📝 EXTRACT THE TOKENS
   The copied URL will look like:
   https://access.redhat.com/downloads/content/[PATH]?user=[USER_TOKEN]&_auth_=[AUTH_TOKEN]
   
   Copy the values after:
   • user= (this is your UserToken)
   • _auth_= (this is your AuthToken)

6. 📋 COPY THE DOWNLOAD PATH
   The [PATH] portion (everything between /content/ and the ?) is your DownloadPath
   Example: /69/rhel-9-wsl/rhel-9.tar.gz

7. ⚡ IMPORTANT NOTES
   • Tokens expire after a few hours - you'll need to refresh them periodically
   • Each RHEL version may have different download paths
   • Keep your tokens secure - don't share them publicly

"@ -ForegroundColor $Colors.Info

    Write-Host "`nPress any key when you have your tokens ready..." -ForegroundColor $Colors.Prompt
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-ConfigurationExists {
    return Test-Path $ConfigPath
}

function Copy-ExampleConfiguration {
    try {
        if (-not (Test-Path $ConfigDir)) {
            New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
            Write-Success "Created configuration directory"
        }

        if (-not (Test-Path $ExampleConfigPath)) {
            Write-Host "Example configuration not found at: $ExampleConfigPath" -ForegroundColor $Colors.Error
            return $false
        }

        Copy-Item -Path $ExampleConfigPath -Destination $ConfigPath -Force
        Write-Success "Configuration file created at: $ConfigPath"
        return $true
    }
    catch {
        Write-Host "Failed to copy configuration: $_" -ForegroundColor $Colors.Error
        return $false
    }
}

function Show-NextSteps {
    Write-Header "Next Steps"
    
    Write-Host @"
✅ CONFIGURATION SETUP COMPLETE

Now you need to customize your configuration:

1. 📝 EDIT CONFIGURATION FILE
   Open: $ConfigPath
   
2. 🔑 UPDATE RED HAT TOKENS
   Replace these placeholders with your actual tokens:
   • UserToken = "your_user_token_here"
   • AuthToken = "your_auth_token_here"
   
3. 📂 UPDATE DOWNLOAD PATHS
   For each RHEL version you want to install, update:
   • DownloadPath = "/path/from/redhat/access/rhel9"
   
4. 🛠️ CUSTOMIZE SETTINGS
   Review and modify other settings as needed:
   • Satellite configuration
   • Python environment settings
   • WSL user preferences

5. 🚀 RUN THE MAIN SETUP
   Once configured, run: .\Setup-RHEL-WSL.ps1

"@ -ForegroundColor $Colors.Info

    if ($OpenConfig) {
        Write-Info "Opening configuration file for editing..."
        try {
            Start-Process notepad.exe $ConfigPath
            Write-Success "Configuration file opened in Notepad"
        }
        catch {
            Write-Warning "Could not open Notepad. Please manually edit: $ConfigPath"
        }
    } else {
        Write-Info "To edit the configuration file, run: notepad `"$ConfigPath`""
    }
}

function Show-ProjectInfo {
    Write-Header "RHEL WSL Automated Setup - Initial Configuration"
    
    Write-Host @"
This script will help you set up the initial configuration for automated
RHEL WSL deployment. The setup process includes:

• Creating your personal configuration file
• Guiding you through getting Red Hat Access tokens
• Explaining how to customize settings for your environment

"@ -ForegroundColor $Colors.Info
}

# Main execution
try {
    Show-ProjectInfo
    
    # Step 1: Check if configuration already exists
    Write-Step "Checking existing configuration" 1
    
    if (Test-ConfigurationExists) {
        if ($Force) {
            Write-Warning "Configuration file exists but Force parameter specified"
            Write-Info "Will overwrite existing configuration..."
        } else {
            Write-Success "Configuration file already exists at: $ConfigPath"
            Write-Info "Use -Force parameter to overwrite existing configuration"
            
            $response = Read-Host "`nDo you want to view token instructions anyway? (y/N)"
            if ($response -match "^[Yy]") {
                Show-TokenInstructions
            }
            
            if ($OpenConfig) {
                Write-Info "Opening existing configuration file..."
                Start-Process notepad.exe $ConfigPath
            }
            
            Write-Success "Setup check completed"
            exit 0
        }
    }
    
    # Step 2: Show token instructions
    Write-Step "Red Hat Access Token Setup" 2
    Show-TokenInstructions
    
    # Step 3: Copy example configuration
    Write-Step "Creating configuration file" 3
    
    if (Copy-ExampleConfiguration) {
        Write-Success "Configuration file setup completed"
    } else {
        Write-Host "Failed to create configuration file" -ForegroundColor $Colors.Error
        exit 1
    }
    
    # Step 4: Show next steps
    Write-Step "Setup Complete" 4
    Show-NextSteps
    
    Write-Host "`n" -NoNewline
    Write-Success "Initial setup completed successfully!"
    Write-Info "Remember to update your tokens in the configuration file before running the main setup script."
    
} catch {
    Write-Host "`nSetup failed with error: $_" -ForegroundColor $Colors.Error
    exit 1
}
