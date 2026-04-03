# Windows Software Recovery Tool - Entry Script
# Provides user interaction menu and dispatches to different installation scripts

param()
$ErrorActionPreference = "Stop"

# Import common functions
$commonScript = Join-Path $PSScriptRoot "scripts\common.ps1"
. $commonScript

<#
.SYNOPSIS
    Display main menu and get user input
.DESCRIPTION
    Displays the main menu of Windows Software Recovery Tool and prompts for user option
    Only accepts 0, 1, 2 as valid input
.OUTPUTS
    System.String - User input option (0, 1, or 2)
#>
function Show-Menu {
    Write-Host ""
    Write-Host "Windows Software Recovery Tool" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please select an option:"
    Write-Host "0 - Install All"
    Write-Host "1 - Install Scoop"
    Write-Host "2 - Install winget"
    Write-Host ""

    $choice = Read-Host "Enter option (0/1/2)"
    return $choice
}

<#
.SYNOPSIS
    Validate user input
.DESCRIPTION
    Checks if user input is 0, 1, or 2
    If not, displays error and exits script
.PARAMETER Choice
    User input option
#>
function Test-ValidChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Choice
    )

    # Check if empty
    if ([string]::IsNullOrWhiteSpace($Choice)) {
        Write-ErrorAndExit "Input cannot be empty. Only 0/1/2 are accepted."
    }

    # Check if valid option
    $validChoices = @('0', '1', '2')
    if ($Choice -notin $validChoices) {
        Write-ErrorAndExit "Invalid option: '$Choice'. Only 0/1/2 are accepted."
    }
}

<#
.SYNOPSIS
    Execute full installation process
.DESCRIPTION
    Sequentially calls Scoop installation, winget check, and app installation scripts
#>
function Invoke-FullInstallation {
    Write-Log "Executing full installation process..." -Level "Info"

    $scripts = @(
        "install-scoop.ps1",
        "install-winget.ps1",
        "install-apps.ps1"
    )

    foreach ($script in $scripts) {
        $scriptPath = Join-Path $PSScriptRoot "scripts\$script"
        Write-Log "Executing $script..." -Level "Info"

        if (Test-Path $scriptPath) {
            & $scriptPath
        }
        else {
            Write-Log "Script not found, skipping: $script" -Level "Warning"
        }
    }

    Write-Log "Full installation process completed" -Level "Success"
}

<#
.SYNOPSIS
    Execute Scoop installation
.DESCRIPTION
    Calls Scoop installation script
#>
function Invoke-ScoopInstallation {
    Write-Log "Executing Scoop installation..." -Level "Info"

    $scriptPath = Join-Path $PSScriptRoot "scripts\install-scoop.ps1"

    if (Test-Path $scriptPath) {
        & $scriptPath
        Write-Log "Scoop installation completed" -Level "Success"
    }
    else {
        Write-Log "Scoop installation script not found: $scriptPath" -Level "Warning"
    }
}

<#
.SYNOPSIS
    Execute winget check
.DESCRIPTION
    Calls winget check script
#>
function Invoke-WingetInstallation {
    Write-Log "Executing winget check..." -Level "Info"

    $scriptPath = Join-Path $PSScriptRoot "scripts\install-winget.ps1"

    if (Test-Path $scriptPath) {
        & $scriptPath
        Write-Log "winget check completed" -Level "Success"
    }
    else {
        Write-Log "winget check script not found: $scriptPath" -Level "Warning"
    }
}

# ==================== Main Program Entry ====================

Write-Log "Windows Software Recovery Tool started" -Level "Info"

# Display menu and get user input
$choice = Show-Menu

# Validate input
Test-ValidChoice -Choice $choice

# Dispatch based on input
switch ($choice) {
    '0' {
        Invoke-FullInstallation
    }
    '1' {
        Invoke-ScoopInstallation
    }
    '2' {
        Invoke-WingetInstallation
    }
}

Write-Log "All operations completed" -Level "Success"
