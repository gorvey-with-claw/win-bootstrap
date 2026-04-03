# Application Installation Script
# Reads apps.json and installs enabled applications using scoop or winget

param()
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

# Installation statistics
$script:Stats = @{
    Total = 0
    Installed = 0
    Skipped = 0
    Failed = 0
}

<#
.SYNOPSIS
    Test if an app is already installed
.DESCRIPTION
    Checks if the specified app is installed based on its installer type
.PARAMETER App
    App object from apps.json
.OUTPUTS
    System.Boolean - Returns $true if installed, $false otherwise
#>
function Test-AppInstalled {
    param($App)
    
    switch ($App.installer) {
        'scoop' {
            return Test-ScoopAppInstalled -Package $App.package
        }
        'winget' {
            return Test-WingetAppInstalled -Package $App.package
        }
        default {
            Write-Log "Unknown installer type: $($App.installer)" -Level "Warning"
            return $false
        }
    }
}

<#
.SYNOPSIS
    Install a single application
.DESCRIPTION
    Installs the specified app using its configured installer
.PARAMETER App
    App object from apps.json
#>
function Install-App {
    param($App)
    
    $success = $false
    
    switch ($App.installer) {
        'scoop' {
            $success = Install-ScoopApp -Package $App.package -AppName $App.name
        }
        'winget' {
            $success = Install-WingetApp -Package $App.package -AppName $App.name
        }
        default {
            Write-Log "Unknown installer type: $($App.installer) for app $($App.name)" -Level "Error"
            $success = $false
        }
    }
    
    if ($success) {
        $script:Stats.Installed++
    }
    else {
        $script:Stats.Failed++
    }
}

<#
.SYNOPSIS
    Display installation summary
.DESCRIPTION
    Outputs statistics about the installation process
#>
function Show-Summary {
    Write-Log "" -Level "Info"
    Write-Log "Installation Summary:" -Level "Info"
    Write-Log "====================" -Level "Info"
    Write-Log "Total: $($script:Stats.Total)" -Level "Info"
    Write-Log "Installed: $($script:Stats.Installed)" -Level "Success"
    Write-Log "Skipped (already installed): $($script:Stats.Skipped)" -Level "Info"
    Write-Log "Failed: $($script:Stats.Failed)" -Level "Error"
}

# Main execution flow
Write-Log "Starting application installation..." -Level "Info"

# Read and validate apps.json
$apps = Read-AppsJson
Validate-Apps -Apps $apps

# Filter enabled apps only
$enabledApps = $apps | Where-Object { $_.enabled -eq $true }
$script:Stats.Total = $enabledApps.Count

Write-Log "Found $($enabledApps.Count) enabled applications to process" -Level "Info"

# Process each enabled app
foreach ($app in $enabledApps) {
    Write-Log "Processing $($app.name) ($($app.id))..." -Level "Info"
    
    if (Test-AppInstalled $app) {
        Write-Log "Skipping $($app.name) - already installed" -Level "Success"
        $script:Stats.Skipped++
    }
    else {
        Install-App $app
    }
}

# Display final summary
Show-Summary

Write-Log "Application installation completed" -Level "Info"

# Exit with error code if any installations failed
if ($script:Stats.Failed -gt 0) {
    exit 1
}
