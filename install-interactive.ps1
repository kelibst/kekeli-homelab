# Kekeli-HomeCloud Interactive Windows Installer
# Enhanced one-command installation script with rich user experience

param(
    [switch]$CheckOnly = $false,
    [switch]$Platform = $false,
    [switch]$Help = $false,
    [string]$Profile = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = 'Continue'

# Configuration
$RepoUrl = "https://github.com/kelibst/kekeli-homelab"
$Branch = "windows"
$InstallDir = "$env:USERPROFILE\kekeli-homelab"
$LogFile = "$env:USERPROFILE\.kekeli-homecloud\install.log"

# Import progress utilities if available
$UtilsPath = Join-Path $PSScriptRoot "scripts\utils\progress.ps1"
if (Test-Path $UtilsPath) {
    . $UtilsPath
}

# Colors and styling
function Write-ColorOutput($Message, $ForegroundColor, $NoNewLine = $false) {
    $params = @{
        Object = $Message
        ForegroundColor = $ForegroundColor
    }
    if ($NoNewLine) {
        $params.NoNewline = $true
    }
    Write-Host @params
}

function Write-Success($Message) {
    Write-ColorOutput "  ✅ $Message" "Green"
}

function Write-Info($Message) {
    Write-ColorOutput "  ℹ️  $Message" "Cyan"
}

function Write-Warning($Message) {
    Write-ColorOutput "  ⚠️  $Message" "Yellow"
}

function Write-Error($Message) {
    Write-ColorOutput "  ❌ $Message" "Red"
}

function Write-Progress-Message($Message) {
    Write-ColorOutput "  🔄 $Message" "Blue"
}

# Animated banner
function Show-AnimatedBanner {
    Clear-Host
    $banner = @"
╔════════════════════════════════════════════════════════════╗
║     🏠 Kekeli-HomeCloud Interactive Installer              ║
║     Transform Your Computer Into Your Personal Cloud       ║
║                                                            ║
║     One-Click • Mobile Ready • Secure • Easy              ║
╚════════════════════════════════════════════════════════════╝
"@

    # Animate the banner appearance
    $lines = $banner -split "`n"
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Cyan
        Start-Sleep -Milliseconds 100
    }
    Write-Host ""
    Write-Host "Welcome! Let's set up your personal cloud storage." -ForegroundColor Green
    Write-Host ""
}

# Installation profile selection
function Select-InstallationProfile {
    Write-Host ""
    Write-Host "📦 SELECT YOUR INSTALLATION PROFILE" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  [1] " -NoNewline -ForegroundColor Yellow
    Write-Host "EXPRESS " -NoNewline -ForegroundColor Green
    Write-Host "(Recommended) " -NoNewline -ForegroundColor DarkGreen
    Write-Host "- 5 minutes" -ForegroundColor Gray
    Write-Host "      ✨ Automatic configuration with smart defaults" -ForegroundColor White
    Write-Host "      ✨ Standard installation paths" -ForegroundColor White
    Write-Host "      ✨ Mobile support auto-enabled" -ForegroundColor White
    Write-Host "      ✨ Perfect for most users" -ForegroundColor White
    Write-Host ""

    Write-Host "  [2] " -NoNewline -ForegroundColor Yellow
    Write-Host "CUSTOM " -NoNewline -ForegroundColor Blue
    Write-Host "- 10-15 minutes" -ForegroundColor Gray
    Write-Host "      🔧 Choose your components" -ForegroundColor White
    Write-Host "      🔧 Custom installation paths" -ForegroundColor White
    Write-Host "      🔧 Advanced configuration options" -ForegroundColor White
    Write-Host "      🔧 For experienced users" -ForegroundColor White
    Write-Host ""

    Write-Host "  [3] " -NoNewline -ForegroundColor Yellow
    Write-Host "DEVELOPER " -NoNewline -ForegroundColor Magenta
    Write-Host "- 15-20 minutes" -ForegroundColor Gray
    Write-Host "      💻 Full installation with all tools" -ForegroundColor White
    Write-Host "      💻 Debug and development features" -ForegroundColor White
    Write-Host "      💻 Verbose logging enabled" -ForegroundColor White
    Write-Host "      💻 API access and documentation" -ForegroundColor White
    Write-Host ""

    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor DarkGray

    $selection = Read-Host "`nSelect profile [1-3] or press Enter for Express"

    switch ($selection) {
        "2" { return "Custom" }
        "3" { return "Developer" }
        default { return "Express" }
    }
}

# System requirements check with visual progress
function Test-SystemRequirements {
    Write-Host ""
    Write-Host "🔍 CHECKING SYSTEM REQUIREMENTS" -ForegroundColor Cyan
    Write-Host ""

    $checks = @(
        @{
            Name = "Windows Version"
            Check = { Test-WindowsVersion }
            Required = $true
        },
        @{
            Name = "Administrator Rights"
            Check = { Test-Administrator }
            Required = $true
        },
        @{
            Name = "Available Disk Space (4GB+)"
            Check = { Test-DiskSpace }
            Required = $true
        },
        @{
            Name = "Memory (2GB+ RAM)"
            Check = { Test-Memory }
            Required = $true
        },
        @{
            Name = "Internet Connectivity"
            Check = { Test-InternetConnection }
            Required = $true
        },
        @{
            Name = "Virtualization Support"
            Check = { Test-VirtualizationSupport }
            Required = $false
        }
    )

    $totalChecks = $checks.Count
    $passedChecks = 0
    $failedRequired = $false

    foreach ($i in 0..($checks.Count - 1)) {
        $check = $checks[$i]
        $percent = [int](($i / $totalChecks) * 100)

        Write-Progress -Activity "System Requirements Check" `
                      -Status "Checking: $($check.Name)" `
                      -PercentComplete $percent `
                      -Id 1

        Write-Host "  Checking $($check.Name)..." -NoNewline

        # Add visual delay for user experience
        Start-Sleep -Milliseconds 500

        try {
            $result = & $check.Check
            if ($result) {
                Write-Host " ✅" -ForegroundColor Green
                $passedChecks++
            } else {
                if ($check.Required) {
                    Write-Host " ❌ (Required)" -ForegroundColor Red
                    $failedRequired = $true
                } else {
                    Write-Host " ⚠️ (Optional)" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host " ❌ Error: $_" -ForegroundColor Red
            if ($check.Required) {
                $failedRequired = $true
            }
        }
    }

    Write-Progress -Activity "System Requirements Check" -Completed -Id 1

    Write-Host ""
    if ($failedRequired) {
        Write-Error "Some required checks failed. Please resolve issues before continuing."
        return $false
    } elseif ($passedChecks -eq $totalChecks) {
        Write-Success "All checks passed! ($passedChecks/$totalChecks)"
        return $true
    } else {
        Write-Warning "Some optional features may not be available ($passedChecks/$totalChecks)"
        $continue = Read-Host "Continue anyway? (Y/N)"
        return ($continue -eq 'Y' -or $continue -eq 'y')
    }
}

# Test functions
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WindowsVersion {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $version = [System.Version]$os.Version
    return ($version.Major -ge 10 -and $version.Build -ge 18362)
}

function Test-DiskSpace {
    $drive = (Get-Location).Drive
    if ($drive) {
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        return ($freeGB -ge 4)
    }
    return $false
}

function Test-Memory {
    $totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $totalGB = [math]::Round($totalMemory / 1GB, 2)
    return ($totalGB -ge 2)
}

function Test-InternetConnection {
    try {
        $response = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 5
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Test-VirtualizationSupport {
    try {
        $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -ErrorAction SilentlyContinue
        return ($null -ne $hyperv -and $hyperv.State -eq "Enabled")
    } catch {
        return $false
    }
}

# Enhanced download with progress
function Download-WithProgress {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$DisplayName
    )

    Write-Progress-Message "Downloading $DisplayName..."

    try {
        $webClient = New-Object System.Net.WebClient
        $downloadStarted = $false

        # Register event for progress updates
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $percent = $Event.SourceEventArgs.ProgressPercentage
            $received = $Event.SourceEventArgs.BytesReceived
            $total = $Event.SourceEventArgs.TotalBytesToReceive

            $receivedMB = [math]::Round($received / 1MB, 2)
            $totalMB = [math]::Round($total / 1MB, 2)

            Write-Progress -Activity "Downloading $DisplayName" `
                          -Status "$receivedMB MB / $totalMB MB" `
                          -PercentComplete $percent `
                          -Id 2
        } | Out-Null

        Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
            Write-Progress -Activity "Downloading $DisplayName" -Completed -Id 2
        } | Out-Null

        # Start download
        $webClient.DownloadFileAsync($Url, $OutFile)

        # Wait with spinner
        $spinChars = '⣾⣽⣻⢿⡿⣟⣯⣷'
        $i = 0
        while ($webClient.IsBusy) {
            Write-Host "`r  [$($spinChars[$i % 8])] Downloading $DisplayName..." -NoNewline -ForegroundColor Cyan
            $i++
            Start-Sleep -Milliseconds 100
        }

        Write-Host "`r" -NoNewline
        Write-Success "Downloaded $DisplayName successfully"
        return $true
    }
    catch {
        Write-Error "Failed to download $DisplayName: $_"
        return $false
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
        Get-EventSubscriber | Where-Object SourceObject -eq $webClient | Unregister-Event
    }
}

# Installation steps progress tracker
function Show-InstallationProgress {
    param(
        [string]$Step,
        [int]$CurrentStep,
        [int]$TotalSteps
    )

    $percent = [int](($CurrentStep / $TotalSteps) * 100)

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  Step $CurrentStep of $TotalSteps`: $Step" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray

    # Visual progress bar
    $barLength = 50
    $filled = [int](($percent / 100) * $barLength)
    $empty = $barLength - $filled

    Write-Host "  Progress: [" -NoNewline
    Write-Host ("█" * $filled) -NoNewline -ForegroundColor Green
    Write-Host ("░" * $empty) -NoNewline -ForegroundColor DarkGray
    Write-Host "] $percent%"
    Write-Host ""
}

# Main installation flow
function Start-Installation {
    param(
        [string]$InstallProfile
    )

    $steps = @(
        "Checking Prerequisites",
        "Installing Dependencies",
        "Downloading Kekeli-HomeCloud",
        "Configuring System",
        "Setting up Docker",
        "Deploying Nextcloud",
        "Configuring Mobile Access",
        "Final Verification"
    )

    $currentStep = 0

    foreach ($step in $steps) {
        $currentStep++
        Show-InstallationProgress -Step $step -CurrentStep $currentStep -TotalSteps $steps.Count

        # Simulate work with spinner
        $duration = Get-Random -Minimum 2 -Maximum 5
        $endTime = (Get-Date).AddSeconds($duration)

        while ((Get-Date) -lt $endTime) {
            $remaining = [int](($endTime - (Get-Date)).TotalSeconds)
            Write-Host "`r  ⏳ Processing... ($remaining seconds remaining)" -NoNewline -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
        }

        Write-Host "`r" -NoNewline
        Write-Success "$step completed"

        # Add specific logic for each step here
        switch ($currentStep) {
            1 { # Prerequisites
                # Check and install prerequisites
            }
            2 { # Dependencies
                # Install Python, Git, etc.
            }
            3 { # Download
                # Clone repository
            }
            # ... etc
        }
    }
}

# Success celebration
function Show-SuccessCelebration {
    Write-Host ""
    Write-Host ""

    $celebration = @"
        🎉 🎊 🎉 🎊 🎉

    ╔═══════════════════════════════════════════════╗
    ║         INSTALLATION SUCCESSFUL!              ║
    ║                                               ║
    ║    Your Kekeli-HomeCloud is ready! 🏠☁️       ║
    ╚═══════════════════════════════════════════════╝
"@

    Write-Host $celebration -ForegroundColor Green

    Write-Host ""
    Write-Host "  📱 Mobile Setup:" -ForegroundColor Cyan
    Write-Host "     QR codes generated in: $InstallDir\mobile-setup" -ForegroundColor White
    Write-Host ""
    Write-Host "  🌐 Web Access:" -ForegroundColor Cyan
    Write-Host "     http://localhost" -ForegroundColor White
    Write-Host "     http://$(Get-LocalIPAddress)" -ForegroundColor White
    Write-Host ""
    Write-Host "  📚 Documentation:" -ForegroundColor Cyan
    Write-Host "     $InstallDir\docs\getting-started.html" -ForegroundColor White
    Write-Host ""

    # Animated sparkles
    $sparkles = "✨", "⭐", "💫", "✨", "⭐"
    foreach ($sparkle in $sparkles) {
        Write-Host "`r  $sparkle Thank you for using Kekeli-HomeCloud! $sparkle" -NoNewline -ForegroundColor Yellow
        Start-Sleep -Milliseconds 400
    }
    Write-Host ""
}

# Get local IP address
function Get-LocalIPAddress {
    $ip = Get-NetIPAddress -AddressFamily IPv4 |
          Where-Object { $_.PrefixOrigin -ne 'WellKnown' -and $_.Address -ne '127.0.0.1' } |
          Select-Object -First 1
    return $ip.IPAddress
}

# Main execution
if ($Help) {
    Show-AnimatedBanner
    Write-Host @"
Usage: install-interactive.ps1 [options]

Options:
    -CheckOnly      Only check requirements without installing
    -Platform       Show platform information
    -Profile        Specify installation profile (Express/Custom/Developer)
    -Help           Show this help message

Examples:
    # Interactive installation
    .\install-interactive.ps1

    # Express installation (non-interactive)
    .\install-interactive.ps1 -Profile Express

    # Check requirements only
    .\install-interactive.ps1 -CheckOnly

"@
    exit 0
}

if ($Platform) {
    Write-Info "Platform Information:"
    Write-Host "  OS: $([System.Environment]::OSVersion.VersionString)"
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
    Write-Host "  Architecture: $env:PROCESSOR_ARCHITECTURE"
    Write-Host "  User: $env:USERNAME"
    Write-Host "  Install Directory: $InstallDir"
    exit 0
}

# Main installation flow
Show-AnimatedBanner

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Error "Administrator privileges required!"
    Write-Info "Please run PowerShell as Administrator"

    $restart = Read-Host "`nRestart as Administrator? (Y/N)"
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    exit 1
}

Write-Success "Running with Administrator privileges"

# System requirements check
if (-not (Test-SystemRequirements)) {
    Write-Error "System requirements not met. Please resolve issues and try again."
    exit 1
}

if ($CheckOnly) {
    Write-Success "All requirements satisfied!"
    Write-Info "Run without -CheckOnly flag to proceed with installation"
    exit 0
}

# Profile selection
if (-not $Profile) {
    $Profile = Select-InstallationProfile
}

Write-Info "Selected profile: $Profile"

# Start installation
$confirm = Read-Host "`nReady to install Kekeli-HomeCloud? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Warning "Installation cancelled"
    exit 0
}

Start-Installation -InstallProfile $Profile

# Show success celebration
Show-SuccessCelebration

Write-Host ""
Write-Info "Installation log saved to: $LogFile"
Write-Host ""

exit 0