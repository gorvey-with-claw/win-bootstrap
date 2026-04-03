# Scoop Installation and Bucket Registration Script
# This script installs Scoop package manager and registers the custom bucket

param()
$ErrorActionPreference = "Stop"

# Import common functions
. "$PSScriptRoot\common.ps1"

<#
.SYNOPSIS
    Test if Scoop is already installed
.DESCRIPTION
    Uses Test-CommandExists to check if scoop command is available
.OUTPUTS
    System.Boolean - Returns $true if Scoop is installed, $false otherwise
#>
function Test-ScoopInstalled {
    return Test-CommandExists "scoop"
}

<#
.SYNOPSIS
    Install Scoop package manager
.DESCRIPTION
    Executes the official Scoop installation command, handles network errors,
    and verifies successful installation
#>
function Install-Scoop {
    Write-Log "Starting Scoop installation..." -Level "Info"
    
    try {
        # Set execution policy to allow script execution
        Write-Log "Setting execution policy to RemoteSigned..." -Level "Info"
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        # Download and install Scoop
        Write-Log "Downloading and installing Scoop from get.scoop.sh..." -Level "Info"
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        # Refresh environment variables to make scoop available in current session
        Write-Log "Refreshing environment variables..." -Level "Info"
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        
        # Verify installation
        Write-Log "Verifying Scoop installation..." -Level "Info"
        if (Test-ScoopInstalled) {
            $scoopVersion = scoop --version 2>$null | Select-Object -First 1
            Write-Log "Scoop installed successfully (Version: $scoopVersion)" -Level "Success"
        }
        else {
            Write-ErrorAndExit "Scoop installation verification failed. Please check your internet connection and try again."
        }
    }
    catch [System.Net.WebException] {
        Write-ErrorAndExit "Network error during Scoop installation. Please check your internet connection and try again. Error: $_"
    }
    catch {
        Write-ErrorAndExit "Failed to install Scoop. Error: $_"
    }
}

<#
.SYNOPSIS
    Register the custom Scoop bucket
.DESCRIPTION
    Checks if the custom bucket is already registered, and adds it if not present
.PARAMETER BucketName
    Name of the bucket to register (default: mybucket)
#>
function Register-CustomBucket {
    param(
        [Parameter(Mandatory = $false)]
        [string]$BucketName = "mybucket"
    )
    
    Write-Log "Checking custom bucket '$BucketName'..." -Level "Info"
    
    try {
        # Get list of registered buckets
        $buckets = scoop bucket list 2>$null
        
        # Check if our bucket is already registered
        $bucketExists = $buckets | Where-Object { $_.Name -eq $BucketName }
        
        if ($bucketExists) {
            Write-Log "Custom bucket '$BucketName' is already registered, skipping registration" -Level "Success"
            return
        }
        
        # Calculate bucket path (relative to script location)
        $bucketPath = Join-Path (Split-Path $PSScriptRoot -Parent) "bucket"
        
        # Verify bucket directory exists
        if (-not (Test-Path $bucketPath)) {
            Write-ErrorAndExit "Bucket directory not found at: $bucketPath"
        }
        
        # Get absolute path and convert to forward slashes for Git URL compatibility
        $bucketFullPath = Resolve-Path $bucketPath | Select-Object -ExpandProperty Path
        $bucketUrl = $bucketFullPath -replace '\\', '/'
        
        # Add the custom bucket
        Write-Log "Adding custom bucket '$BucketName' from $bucketUrl..." -Level "Info"
        scoop bucket add $BucketName $bucketUrl
        
        # Verify bucket was added
        $buckets = scoop bucket list 2>$null
        $bucketExists = $buckets | Where-Object { $_.Name -eq $BucketName }
        
        if ($bucketExists) {
            Write-Log "Custom bucket '$BucketName' registered successfully" -Level "Success"
        }
        else {
            Write-ErrorAndExit "Failed to verify bucket registration for '$BucketName'"
        }
    }
    catch {
        Write-ErrorAndExit "Failed to register custom bucket '$BucketName'. Error: $_"
    }
}

# Main execution flow
Write-Log "========================================" -Level "Info"
Write-Log "Starting Scoop Setup" -Level "Info"
Write-Log "========================================" -Level "Info"

# Step 1: Check if Scoop is already installed
Write-Log "Checking Scoop installation status..." -Level "Info"

if (Test-ScoopInstalled) {
    $scoopVersion = scoop --version 2>$null | Select-Object -First 1
    Write-Log "Scoop is already installed (Version: $scoopVersion), skipping installation" -Level "Success"
}
else {
    Write-Log "Scoop is not installed, proceeding with installation..." -Level "Warning"
    Install-Scoop
}

# Step 2: Register custom bucket
Register-CustomBucket

Write-Log "========================================" -Level "Info"
Write-Log "Scoop setup completed successfully" -Level "Success"
Write-Log "========================================" -Level "Info"
