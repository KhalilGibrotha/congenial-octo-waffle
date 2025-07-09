# ==============================================================================
# RHEL WSL Automated Setup - Example Configuration
# ==============================================================================
# Copy this file to config.psd1 and customize for your environment
# This example shows a typical development environment setup
# ==============================================================================

@{
    # Red Hat Access Download Configuration
    # =====================================
    # Get fresh tokens from access.redhat.com (they expire frequently)
    RedHatAccess = @{
        UserToken = "your_user_token_here"
        AuthToken = "your_auth_token_here"
        BaseDownloadUrl = "https://access.redhat.com/downloads/content"
    }

    # RHEL Distribution Configuration - Example for Development
    # =========================================================
    RHELDistributions = @{
        RHEL8 = @{
            Name = "RHEL8-Dev"
            Version = "8"
            FileName = "rhel-8-wsl.tar.gz"
            DownloadPath = "/path/from/redhat/access/rhel8"  # Copy from Red Hat Access URL
            InstallPath = "C:\WSL\RHEL8-Dev"
            Enabled = $false  # Enable as needed
        }
        RHEL9 = @{
            Name = "RHEL9-Dev"
            Version = "9"
            FileName = "rhel-9-wsl.tar.gz"
            DownloadPath = "/path/from/redhat/access/rhel9"  # Copy from Red Hat Access URL
            InstallPath = "C:\WSL\RHEL9-Dev"
            Enabled = $true
        }
        RHEL10 = @{
            Name = "RHEL10-Dev"
            Version = "10"
            FileName = "rhel-10-wsl.tar.gz"
            DownloadPath = "/path/from/redhat/access/rhel10"  # Copy from Red Hat Access URL
            InstallPath = "C:\WSL\RHEL10-Dev"
            Enabled = $false  # Enable when RHEL 10 is available
        }
    }

    # WSL Configuration
    # =================
    WSLConfig = @{
        DefaultUser = "developer"
        DefaultPassword = "DevPass123!"
        RequirePasswordChange = $true
        AddToSudoers = $true
        HomeDirectory = "/home"
    }

    # Red Hat Satellite Configuration
    # ================================
    SatelliteConfig = @{
        Enabled = $true
        Hostname = "satellite.yourcompany.com"
        Organization = "YourOrg"
        ActivationKey = "rhel-wsl-dev-key"
        ForceRegistration = $false
        TestConnectivity = $true
        
        # Fallback to direct Red Hat registration if Satellite fails
        FallbackToDirectRH = @{
            Enabled = $true
            PromptForCredentials = $true
        }
    }

    # Repository Configuration
    # ========================
    RepositoryConfig = @{
        EnableCodeReadyBuilder = $true
        EnableEPEL = $true
        UpdateSystem = $true
        CleanCache = $true
        
        # Additional repositories to enable (uncomment as needed)
        AdditionalRepos = @(
            # "rhel-9-for-x86_64-supplementary-rpms",
            # "rhel-9-for-x86_64-optional-rpms"
        )
    }

    # Python Virtual Environment Configuration
    # =========================================
    PythonConfig = @{
        Enabled = $true
        VenvPath = "/opt/dev_environment"
        VenvOwner = "developer"
        VenvGroup = "developer"
        
        # Custom wheel file configuration
        CustomWheel = @{
            Enabled = $true
            WindowsPath = "C:\path\to\your\analytics-package.whl"  # Update this path
            WSLTempPath = "/tmp/analytics-package.whl"
            CleanupAfterInstall = $true
        }
        
        # Standard Python packages to install
        StandardPackages = @(
            "pip",
            "setuptools",
            "wheel",
            "virtualenv",
            "requests",
            "numpy"
        )
    }

    # Logging Configuration
    # =====================
    LoggingConfig = @{
        Enabled = $true
        LogLevel = "INFO"  # DEBUG, INFO, WARN, ERROR
        LogPath = ".\logs"
        LogFileName = "rhel-wsl-setup-{0}.log"  # {0} will be replaced with timestamp
        MaxLogFiles = 5
        MaxLogSizeMB = 25
    }

    # Download Configuration
    # ======================
    DownloadConfig = @{
        DownloadPath = ".\downloads"
        VerifyDownloads = $true
        RetryAttempts = 3
        RetryDelaySeconds = 5
        CleanupAfterImport = $false  # Keep downloaded files for re-use
    }

    # Advanced Configuration
    # ======================
    AdvancedConfig = @{
        # Parallel processing
        MaxConcurrentDistributions = 1
        
        # Error handling
        ContinueOnError = $false
        PromptOnError = $true
        
        # WSL specific
        SetAsDefault = $true
        LaunchAfterSetup = $false
        
        # Backup and cleanup
        BackupExistingDistributions = $true
        BackupPath = ".\backups"
        
        # Validation
        ValidateAfterSetup = $true
        TestCommands = @(
            "cat /etc/redhat-release",
            "subscription-manager status",
            "python3 --version"
        )
    }

    # Environment Validation
    # ======================
    ValidationConfig = @{
        CheckWSLVersion = $true
        MinimumWSLVersion = "2"
        CheckAdminRights = $false  # Set to true if you want to enforce admin privileges
        CheckDiskSpace = $true
        MinimumDiskSpaceGB = 5
        CheckInternetConnectivity = $true
        TestUrls = @(
            "https://access.redhat.com",
            "https://satellite.yourcompany.com"  # Update with your Satellite hostname
        )
    }
}
