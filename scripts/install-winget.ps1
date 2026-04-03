# Winget Availability Checker
# Checks if winget is available and outputs version information

param()
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

<#
.SYNOPSIS
    Test if winget command is available
.DESCRIPTION
    Uses Test-CommandExists to check if winget is installed and available in PATH
.OUTPUTS
    System.Boolean - Returns $true if winget exists, $false otherwise
#>
function Test-WingetAvailable {
    return Test-CommandExists "winget"
}

<#
.SYNOPSIS
    Get winget version information
.DESCRIPTION
    Executes winget --version and returns the version string
    Returns "Unknown" if version cannot be determined
.OUTPUTS
    System.String - Winget version string
#>
function Get-WingetVersion {
    try {
        $version = winget --version 2>$null
        if ($version) {
            return $version.Trim()
        }
        return "Unknown"
    }
    catch {
        return "Unknown"
    }
}

# Main execution flow
Write-Log "Checking winget availability..." -Level "Info"

if (Test-WingetAvailable) {
    $version = Get-WingetVersion
    Write-Log "winget is available (Version: $version)" -Level "Success"
}
else {
    Write-Log "winget is not available" -Level "Error"
    Write-Log "Please install winget manually:" -Level "Warning"
    Write-Log "  1. Open Microsoft Store" -Level "Warning"
    Write-Log "  2. Search for 'App Installer'" -Level "Warning"
    Write-Log "  3. Install or update App Installer" -Level "Warning"
    Write-Log "  Or download from: https://aka.ms/getwinget" -Level "Warning"
    exit 1
}
