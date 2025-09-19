# Kekeli-HomeCloud Windows Installer
# One-command installation script for Windows
# This script downloads and runs the Kekeli-HomeCloud installer

param(
    [switch]$CheckOnly = $false,
    [switch]$Platform = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Configuration
$RepoUrl = "https://github.com/kelibst/kekeli-homelab"
$Branch = "windows"
$InstallDir = "$env:USERPROFILE\kekeli-homelab"

# Colors for output
function Write-ColorOutput($Message, $ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success($Message) {
    Write-ColorOutput "✅ $Message" "Green"
}

function Write-Info($Message) {
    Write-ColorOutput "ℹ️  $Message" "Cyan"
}

function Write-Warning($Message) {
    Write-ColorOutput "⚠️  $Message" "Yellow"
}

function Write-Error($Message) {
    Write-ColorOutput "❌ $Message" "Red"
}

# Show banner
function Show-Banner {
    Write-Host @"

╔════════════════════════════════════════════════════╗
║     🏠 Kekeli-HomeCloud Easy Installer             ║
║     Transform Your Computer Into Your Cloud        ║
╚════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

# Show help
if ($Help) {
    Show-Banner
    Write-Host @"
Usage: install.ps1 [options]

Options:
    -CheckOnly      Only check requirements without installing
    -Platform       Show platform information
    -Help           Show this help message

Examples:
    # Full installation (recommended)
    .\install.ps1

    # Check requirements only
    .\install.ps1 -CheckOnly

    # Show platform info
    .\install.ps1 -Platform

"@
    exit 0
}

# Show platform info
if ($Platform) {
    Write-Info "Platform Information:"
    Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Host "Architecture: $env:PROCESSOR_ARCHITECTURE"
    Write-Host "User: $env:USERNAME"
    Write-Host "Install Directory: $InstallDir"
    exit 0
}

Show-Banner

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Error "This script must be run as Administrator!"
    Write-Info "Please right-click PowerShell and select 'Run as Administrator'"

    # Attempt to restart as Administrator
    $response = Read-Host "Would you like to restart as Administrator? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    exit 1
}

Write-Success "Running with Administrator privileges"

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.0 or later is required"
    Write-Info "Please update PowerShell: https://aka.ms/powershell"
    exit 1
}

# Check Windows version
$os = Get-WmiObject -Class Win32_OperatingSystem
$version = [System.Version]$os.Version
if ($version.Major -lt 10 -or ($version.Major -eq 10 -and $version.Build -lt 18362)) {
    Write-Error "Windows 10 version 1903 or later is required"
    Write-Info "Current version: Windows $($version.Major) build $($version.Build)"
    exit 1
}

Write-Success "System requirements met"

# Check for Python
Write-Info "Checking Python installation..."
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python (\d+\.\d+)") {
        $version = [version]$matches[1]
        if ($version -ge [version]"3.6") {
            Write-Success "Python $version found"
        } else {
            throw "Python 3.6+ required, found $version"
        }
    }
} catch {
    Write-Warning "Python not found or version too old"
    Write-Info "Installing Python..."

    # Download and install Python
    $pythonUrl = "https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-installer.exe"

    Write-Info "Downloading Python installer..."
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller

    Write-Info "Installing Python (this may take a few minutes)..."
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Write-Success "Python installed successfully"
}

# Check for Git
Write-Info "Checking Git installation..."
try {
    $gitVersion = git --version 2>&1
    if ($gitVersion -match "git version") {
        Write-Success "Git found: $gitVersion"
    }
} catch {
    Write-Warning "Git not found"
    Write-Info "Installing Git..."

    # Download and install Git
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"

    Write-Info "Downloading Git installer..."
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller

    Write-Info "Installing Git (this may take a few minutes)..."
    Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT", "/NORESTART" -Wait

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Write-Success "Git installed successfully"
}

if ($CheckOnly) {
    Write-Success "All requirements satisfied!"
    Write-Info "Run without -CheckOnly flag to proceed with installation"
    exit 0
}

# Clone or update repository
Write-Info "Setting up Kekeli-HomeCloud..."

if (Test-Path $InstallDir) {
    Write-Info "Found existing installation at $InstallDir"
    $response = Read-Host "Update existing installation? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Set-Location $InstallDir
        Write-Info "Updating from repository..."
        git fetch origin $Branch
        git checkout $Branch
        git pull origin $Branch
        Write-Success "Repository updated"
    }
} else {
    Write-Info "Cloning repository..."
    git clone -b $Branch $RepoUrl $InstallDir
    Set-Location $InstallDir
    Write-Success "Repository cloned"
}

# Install Python requirements if requirements.txt exists
if (Test-Path "requirements.txt") {
    Write-Info "Installing Python dependencies..."
    python -m pip install --upgrade pip
    python -m pip install -r requirements.txt
    Write-Success "Dependencies installed"
}

# Run the main installer
Write-Info "Starting Kekeli-HomeCloud installation..."
Write-Host ""

try {
    python install.py
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Success "Installation completed successfully!"
        Write-Info "Your Nextcloud instance should be accessible soon"
        Write-Info "Check the generated documentation for mobile setup instructions"
    } else {
        Write-Error "Installation failed with exit code $exitCode"
        Write-Info "Check the installation log for details"
        exit $exitCode
    }
} catch {
    Write-Error "Installation failed: $_"
    Write-Info "Please check the error messages above and try again"
    exit 1
}

Write-Host ""
Write-Info "Installation directory: $InstallDir"
Write-Info "For troubleshooting, see: $InstallDir\docs\troubleshooting.md"
Write-Host ""
Write-Success "Thank you for using Kekeli-HomeCloud!"