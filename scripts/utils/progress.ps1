# PowerShell Progress and Interactive Utilities
# Provides enhanced user experience for Windows installation

# Progress Bar Functions
function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$Id = 1
    )

    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
}

function Show-DownloadProgress {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$DisplayName
    )

    $ProgressPreference = 'Continue'

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head
        $totalSize = [int]$response.Headers.'Content-Length'

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
                          -PercentComplete $percent
        } | Out-Null

        Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
            Write-Progress -Activity "Downloading $DisplayName" -Completed
        } | Out-Null

        # Start download
        $webClient.DownloadFileAsync($Url, $OutFile)

        # Wait for completion
        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 100
        }

        return $true
    }
    catch {
        Write-Host "Error downloading: $_" -ForegroundColor Red
        return $false
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
        Get-EventSubscriber | Where-Object SourceObject -eq $webClient | Unregister-Event
    }
}

# Spinner Animation
function Show-Spinner {
    param(
        [string]$Message,
        [scriptblock]$Task,
        [int]$TimeoutSeconds = 60
    )

    $spinChars = '|/-\'
    $i = 0
    $jobStarted = $false

    Write-Host "`n  " -NoNewline

    # Start the task in background
    $job = Start-Job -ScriptBlock $Task

    $startTime = Get-Date
    while ($job.State -eq 'Running') {
        if ((Get-Date) - $startTime -gt [TimeSpan]::FromSeconds($TimeoutSeconds)) {
            Stop-Job -Job $job
            Remove-Job -Job $job
            Write-Host "`r  ❌ $Message (Timeout)" -ForegroundColor Red
            return $false
        }

        Write-Host "`r  $($spinChars[$i % 4]) $Message" -NoNewline -ForegroundColor Cyan
        $i++
        Start-Sleep -Milliseconds 200
    }

    $result = Receive-Job -Job $job
    Remove-Job -Job $job

    if ($job.State -eq 'Completed') {
        Write-Host "`r  ✅ $Message" -ForegroundColor Green
        return $true
    } else {
        Write-Host "`r  ❌ $Message (Failed)" -ForegroundColor Red
        return $false
    }
}

# Interactive Menu
function Show-Menu {
    param(
        [string]$Title,
        [string]$Question,
        [string[]]$Options,
        [int]$DefaultChoice = 0
    )

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Title" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "$Question" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $Options.Length; $i++) {
        if ($i -eq $DefaultChoice) {
            Write-Host "  ➤ [$($i+1)] $($Options[$i]) (default)" -ForegroundColor Green
        } else {
            Write-Host "    [$($i+1)] $($Options[$i])" -ForegroundColor White
        }
    }

    Write-Host ""
    $selection = Read-Host "Enter choice (1-$($Options.Length)) or press Enter for default"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        return $DefaultChoice
    }

    $choice = [int]$selection - 1
    if ($choice -ge 0 -and $choice -lt $Options.Length) {
        return $choice
    }

    return $DefaultChoice
}

# Animated Banner
function Show-AnimatedBanner {
    param(
        [string[]]$Lines,
        [int]$DelayMs = 50
    )

    Clear-Host

    foreach ($line in $Lines) {
        foreach ($char in $line.ToCharArray()) {
            Write-Host $char -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds $DelayMs
        }
        Write-Host ""
    }

    Start-Sleep -Milliseconds 500
}

# Success Animation
function Show-Success {
    param(
        [string]$Message
    )

    $frames = @(
        "   ✨",
        "  ✨✨",
        " ✨✅✨",
        "  ✅",
        "  ✅ $Message"
    )

    foreach ($frame in $frames) {
        Write-Host "`r$frame" -NoNewline -ForegroundColor Green
        Start-Sleep -Milliseconds 200
    }
    Write-Host ""
}

# Confirmation Prompt
function Get-Confirmation {
    param(
        [string]$Question,
        [bool]$DefaultYes = $true
    )

    if ($DefaultYes) {
        $prompt = "$Question (Y/n)"
        $default = "Y"
    } else {
        $prompt = "$Question (y/N)"
        $default = "N"
    }

    Write-Host "$prompt " -NoNewline -ForegroundColor Yellow
    $response = Read-Host

    if ([string]::IsNullOrWhiteSpace($response)) {
        $response = $default
    }

    return ($response -eq 'Y' -or $response -eq 'y')
}

# Installation Profile Selection
function Select-InstallationProfile {
    $profiles = @{
        'Express' = @{
            Description = 'Quick installation with recommended settings (5 minutes)'
            Features = @('Automatic configuration', 'Default paths', 'Mobile support enabled')
        }
        'Custom' = @{
            Description = 'Choose your components and settings (10-15 minutes)'
            Features = @('Component selection', 'Custom paths', 'Advanced options')
        }
        'Developer' = @{
            Description = 'Full installation with development tools (15-20 minutes)'
            Features = @('All components', 'Debug tools', 'Log verbosity', 'API access')
        }
    }

    Write-Host ""
    Write-Host "📦 INSTALLATION PROFILES" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor DarkGray

    $i = 1
    foreach ($profile in $profiles.Keys) {
        Write-Host ""
        Write-Host "  [$i] $profile" -ForegroundColor Green
        Write-Host "      $($profiles[$profile].Description)" -ForegroundColor White
        Write-Host "      Features:" -ForegroundColor Gray
        foreach ($feature in $profiles[$profile].Features) {
            Write-Host "        • $feature" -ForegroundColor Gray
        }
        $i++
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor DarkGray
    $selection = Read-Host "Select profile (1-3) or press Enter for Express"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        return 'Express'
    }

    switch ($selection) {
        "1" { return 'Express' }
        "2" { return 'Custom' }
        "3" { return 'Developer' }
        default { return 'Express' }
    }
}

# System Check with Progress
function Test-SystemRequirements {
    $checks = @(
        @{Name = "Windows Version"; Check = { Test-WindowsVersion }},
        @{Name = "Administrator Rights"; Check = { Test-Administrator }},
        @{Name = "Available Disk Space"; Check = { Test-DiskSpace }},
        @{Name = "Memory Requirements"; Check = { Test-Memory }},
        @{Name = "Network Connectivity"; Check = { Test-NetworkConnection }},
        @{Name = "Virtualization Support"; Check = { Test-Virtualization }}
    )

    $total = $checks.Count
    $passed = 0

    Write-Host ""
    Write-Host "🔍 SYSTEM REQUIREMENTS CHECK" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $checks.Count; $i++) {
        $check = $checks[$i]
        $percent = [int](($i / $total) * 100)

        Write-Progress -Activity "Checking System Requirements" `
                      -Status "Checking: $($check.Name)" `
                      -PercentComplete $percent

        Write-Host "  Checking $($check.Name)..." -NoNewline

        $result = & $check.Check
        if ($result) {
            Write-Host " ✅" -ForegroundColor Green
            $passed++
        } else {
            Write-Host " ❌" -ForegroundColor Red
        }

        Start-Sleep -Milliseconds 300
    }

    Write-Progress -Activity "Checking System Requirements" -Completed

    Write-Host ""
    if ($passed -eq $total) {
        Write-Host "  All checks passed! ($passed/$total)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  Some checks failed ($passed/$total)" -ForegroundColor Yellow
        return $false
    }
}

# Helper test functions (stubs for actual implementation)
function Test-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    return ($version.Major -ge 10)
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-DiskSpace {
    $drive = (Get-Location).Drive.Name
    $disk = Get-PSDrive $drive
    $freeGB = [math]::Round($disk.Free / 1GB, 2)
    return ($freeGB -ge 4)
}

function Test-Memory {
    $totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $totalGB = [math]::Round($totalMemory / 1GB, 2)
    return ($totalGB -ge 2)
}

function Test-NetworkConnection {
    return (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)
}

function Test-Virtualization {
    try {
        $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
        return ($hyperv.State -eq "Enabled")
    } catch {
        return $false
    }
}

# Export functions
Export-ModuleMember -Function *