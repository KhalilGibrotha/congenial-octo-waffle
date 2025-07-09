# congenial-octo-waffle
RHEL WSL Automated Setup

RHEL WSL Automated Setup Script
Overview
This PowerShell script automates the process of setting up Red Hat Enterprise Linux (RHEL) distributions within Windows Subsystem for Linux (WSL). It handles downloading the RHEL WSL images, importing them, configuring a default sudo user, and crucially, integrates with Red Hat Satellite for content management. It also includes steps for setting up a custom Python virtual environment.

Features
Automated Download: Downloads RHEL 8, 9, and 10 WSL images from Red Hat Access (requires valid authentication tokens).

WSL Distribution Import: Imports the downloaded .tar.gz images as new WSL distributions.

Initial User Setup: Creates a default sudo user with a temporary password and forces a password change on first login for security.

Satellite Registration: Registers the WSL instance with your Red Hat Satellite server.

Repository Management: Enables specific repositories (e.g., CodeReady Builder, EPEL) on the registered WSL instance.

Custom Python Virtual Environment: Sets up a Python virtual environment and installs a custom wheel file into it.

Prerequisites
Windows 10/11 with WSL 2 enabled and installed.

Valid Red Hat Access Download Tokens: The download URLs in the script contain time-sensitive user and _auth_ tokens. You must update these in the script variables with fresh tokens obtained from Red Hat Access.

Red Hat Satellite Server: Your Satellite server must be operational with the necessary Content Views (RHEL OS, AppStream, CRB, EPEL) published and promoted, and an Activation Key prepared for registering your WSL instances.

Python Wheel File: If you plan to use the custom Python virtual environment setup, you'll need the .whl file created by another script, accessible from your Windows environment.

## Project Structure

```
congenial-octo-waffle/
├── Setup-RHEL-WSL.ps1              # Main PowerShell setup script
├── Initialize-Setup.ps1             # Initial setup helper script
├── QuickStart.bat                   # Simple batch file interface
├── config/
│   ├── config.psd1                 # Your configuration (create from example)
│   └── config.example.psd1         # Example configuration template
├── scripts/
│   └── modules/
│       ├── Logging.psm1            # Logging and output management
│       ├── Validation.psm1         # Environment validation
│       ├── Download.psm1           # RHEL image downloads
│       ├── WSLManagement.psm1      # WSL operations and user setup
│       ├── SatelliteRegistration.psm1  # Red Hat Satellite integration
│       └── PythonEnvironment.psm1  # Python virtual environment setup
├── templates/
│   └── CONFIGURATION_GUIDE.md      # Detailed configuration guide
├── downloads/                      # Downloaded RHEL images (auto-created)
├── logs/                          # Setup logs (auto-created)
├── backups/                       # WSL distribution backups (auto-created)
├── analytics/                     # Python analytics packaging tools
└── ansible/                       # Ansible development environment tools
```

## Quick Start

### Option 1: Using the Setup Helper (Recommended)
```powershell
# Run the initial setup helper (as Administrator)
.\Initialize-Setup.ps1

# Or use the batch file for a guided experience
.\QuickStart.bat
```

### Option 2: Manual Configuration
```powershell
# Copy the example configuration
Copy-Item .\config\config.example.psd1 .\config\config.psd1

# Edit with your Red Hat Access tokens and environment details
notepad .\config\config.psd1
```

**To get Red Hat Access tokens:**
1. Go to [Red Hat Access](https://access.redhat.com)
2. Navigate to the RHEL WSL download page
3. Copy the `user=` and `_auth_=` parameters from the download URLs
4. Update these values in your `config.psd1` file

### Run the Setup Script
```powershell
# Open PowerShell as Administrator
# Navigate to the project directory
.\Setup-RHEL-WSL.ps1
```

### First Login
```bash
# Launch your new WSL distribution
wsl -d RHEL9

# Change password when prompted
# Activate Python environment (if configured)
source ~/activate-venv.sh
```

## Configuration

The script uses a modular configuration system in `config/config.psd1`. Key sections include:

- **RedHatAccess**: Download tokens and URLs
- **RHELDistributions**: Which RHEL versions to install
- **SatelliteConfig**: Red Hat Satellite integration settings
- **PythonConfig**: Custom Python virtual environment setup
- **LoggingConfig**: Logging and output preferences

See `templates/CONFIGURATION_GUIDE.md` for detailed configuration options.

Pseudocode for Advanced Configuration (To be integrated into the main script)
This section outlines the logic for Satellite registration, repository enablement, and Python venv setup. You would integrate these steps into the main PowerShell script after the WSL distribution has been successfully imported and the default user created.

# --- Inside the main PowerShell script loop for each RHEL version ---
# --- (After WSL distribution is imported and default user is created) ---

# Variables for Satellite registration and Python setup (e.g., $satelliteOrg, $activationKey, $customWheelFilePathWindows)

Display message: "Starting advanced configuration for this RHEL WSL instance."

# 1. Register with Red Hat Satellite or Directly with Redhat
  Try:
    # Ensure system can communicate with Satellite (e.g., ping hostname)
    # Run subscription-manager register command as root inside WSL instance using predefined organization and activation key.
    # Check if registration was successful.
    # Run subscription-manager attach --auto command as root to attach subscriptions.
    Display message: "Successfully registered with Satellite."
  Catch errors:
    Display error message if Satellite registration fails.
    Try:
      # test communication with direct with red hat
      # run subscription manager register as root, prompt user for login and activation keys
    Continue to next RHEL version if registration is critical for subsequent steps.

# 2. Enable Correct Repositories (e.g., CodeReady Builder, EPEL)
  Display message: "Enabling required repositories."
  Try:
    # As root inside WSL instance:
    # Clean DNF cache and rebuild metadata for fresh repo data.
    # Enable CodeReady Builder repository using subscription-manager.
    # Install the 'epel-release' package via dnf.
    # Enable the EPEL repository using subscription-manager.
    # Perform a final 'dnf update' to ensure all changes are applied.
    Display message: "Repositories enabled and system updated."
  Catch errors:
    Display error message if repository enablement fails.

# 3. Install Custom Python Virtual Environment using a Wheel File
  Display message: "Setting up custom Python virtual environment."
  Try:
    # As root inside WSL instance:
    # Install Python3, pip, and virtualenv packages using dnf.
    # Copy the custom Python wheel file from the Windows host to a temporary location inside the WSL instance.
    # As the default sudo user inside WSL instance:
    # Create the Python virtual environment in a designated path (e.g., /opt/custom_venv).
    # Activate the virtual environment.
    # Install the copied wheel file into the active virtual environment using pip.
    # Deactivate the virtual environment.
    # As root inside WSL instance:
    # Remove the temporary wheel file from the WSL instance.
    Display message: "Custom Python virtual environment setup complete."
  Catch errors:
    Display error message if Python virtual environment setup fails.
Scope for Tools in This Repo vs. Separate Repo
You're asking a very practical question about repository organization, Lex, especially given your goal of standardizing WSL instance deployments.

My recommendation is to keep the repo that handles packaging up Python requirements for air-gapped systems SEPARATE from this WSL deployment repo.

Here's the reasoning:

Single Responsibility Principle:

This Repo: Its core responsibility is the lifecycle management of RHEL WSL instances (download, import, initial setup, Satellite integration, base environment provisioning).

Other Repo: Its core responsibility is the packaging and distribution of Python dependencies, specifically for air-gapped systems.

Decoupling: The "Python packaging" repo has different concerns (e.g., dependency resolution, building wheels, potentially managing a private PyPI mirror, handling air-gap specific challenges). Changes or updates to how those packages are built should not directly impact or require changes to your WSL deployment script, as long as it receives a valid wheel file.

Reusability: The Python packaging repo's output (wheel files) might be consumed by other targets beyond WSL (e.g., physical servers, VMs, containers in air-gapped environments). Keeping it separate makes it a more general-purpose "service" for package distribution.

Team Ownership & Workflows: The team or individuals responsible for packaging Python applications might be different from those managing base OS deployments. Separating repos aligns with clear ownership and allows for independent CI/CD pipelines.

Dependency Management (of the repos): This WSL repo consumes a wheel file. It doesn't need to know how that wheel file was created, only where to get it from. This simplifies the dependencies between your repositories.

Therefore, the ideal scope for this repo is clearly defined as the automated deployment and initial configuration of RHEL WSL instances. It consumes the artifacts (like the wheel file) produced by other, specialized repositories, rather than producing them itself.
