# Common Functions Library
# Provides logging, error handling, JSON reading and other utilities

$ErrorActionPreference = "Stop"

# Log level color mapping
$script:LogColors = @{
    "Info"    = "White"
    "Success" = "Green"
    "Warning" = "Yellow"
    "Error"   = "Red"
}

<#
.SYNOPSIS
    Write timestamped log message
.DESCRIPTION
    Outputs formatted log message with specified level, using different colors
.PARAMETER Message
    The log message to output
.PARAMETER Level
    Log level: Info, Success, Warning, Error (default: Info)
.EXAMPLE
    Write-Log "Starting installation..." -Level "Info"
    Write-Log "Installation complete" -Level "Success"
#>
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = $script:LogColors[$Level]

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

<#
.SYNOPSIS
    Write error message and exit script
.DESCRIPTION
    Displays error message in red, then terminates script with exit code
.PARAMETER Message
    Error message
.PARAMETER ExitCode
    Exit code (default: 1)
.EXAMPLE
    Write-ErrorAndExit "Configuration file not found"
#>
function Write-ErrorAndExit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 1
    )

    Write-Log $Message -Level "Error"
    exit $ExitCode
}

<#
.SYNOPSIS
    Read and parse apps.json configuration file
.DESCRIPTION
    Reads apps.json and returns PowerShell object array
    Exits with error if file doesn't exist or JSON is invalid
.PARAMETER Path
    Path to apps.json (default: $PSScriptRoot\..\apps.json)
.OUTPUTS
    System.Object[] - Array of app configuration objects
.EXAMPLE
    $apps = Read-AppsJson
    $enabledApps = $apps | Where-Object { $_.enabled -eq $true }
#>
function Read-AppsJson {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = (Join-Path $PSScriptRoot "..\apps.json")
    )

    if (-not (Test-Path $Path)) {
        Write-ErrorAndExit "Configuration file not found: $Path"
    }

    try {
        $content = Get-Content $Path -Raw -ErrorAction Stop
        $apps = $content | ConvertFrom-Json -ErrorAction Stop

        # Validate that result is an array
        if ($apps -isnot [System.Array]) {
            Write-ErrorAndExit "Invalid apps.json format: root element must be an array"
        }

        return $apps
    }
    catch {
        Write-ErrorAndExit "Failed to parse apps.json: $_"
    }
}

<#
.SYNOPSIS
    Check if command exists
.DESCRIPTION
    Checks if specified command is available in system PATH
    Used to detect if software is already installed
.PARAMETER Command
    Command name to check
.OUTPUTS
    System.Boolean - Returns $true if command exists, $false otherwise
.EXAMPLE
    if (Test-CommandExists "git") {
        Write-Log "Git is installed"
    }
#>
function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $commandInfo = Get-Command $Command -ErrorAction SilentlyContinue
    return $null -ne $commandInfo
}

<#
.SYNOPSIS
    Validate apps.json data integrity
.DESCRIPTION
    Validates that all required fields exist, installer types are valid,
    and there are no duplicate IDs
.PARAMETER Apps
    Array of app objects from apps.json
.EXAMPLE
    $apps = Read-AppsJson
    Validate-Apps -Apps $apps
#>
function Validate-Apps {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Apps
    )

    Write-Log "Validating apps.json configuration..." -Level "Info"

    # Field validation
    foreach ($app in $Apps) {
        if (-not $app.id) { Write-ErrorAndExit "App missing 'id' field" }
        if (-not $app.name) { Write-ErrorAndExit "App missing 'name' field" }
        if (-not $app.installer) { Write-ErrorAndExit "App missing 'installer' field" }
        if ($app.installer -notin @('scoop', 'winget')) {
            Write-ErrorAndExit "Unknown installer: $($app.installer). Only 'scoop' or 'winget' are allowed."
        }
        if (-not $app.package) { Write-ErrorAndExit "App missing 'package' field" }
    }

    # ID duplicate detection
    $ids = $Apps | ForEach-Object { $_.id }
    $duplicates = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicates) {
        Write-ErrorAndExit "Duplicate app IDs found: $($duplicates.Name -join ', ')"
    }

    Write-Log "Validation passed: $($Apps.Count) apps, no duplicates found" -Level "Success"
}

<#
.SYNOPSIS
    Check if a Scoop app is installed
.DESCRIPTION
    Uses 'scoop list' to check if a package is already installed via Scoop
.PARAMETER Package
    Package name (can include bucket prefix like 'mybucket/package')
.OUTPUTS
    System.Boolean - Returns $true if installed, $false otherwise
.EXAMPLE
    if (Test-ScoopAppInstalled -Package "git") { ... }
    if (Test-ScoopAppInstalled -Package "mybucket/my-tool") { ... }
#>
function Test-ScoopAppInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package
    )

    try {
        # Extract just the package name if it includes bucket prefix
        $packageName = $Package.Split('/')[-1]

        if (-not (Test-CommandExists "scoop")) {
            return $false
        }

        $output = scoop list 2>$null | findstr $packageName
        return -not [string]::IsNullOrWhiteSpace($output)
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Check if a winget app is installed
.DESCRIPTION
    Uses 'winget list' to check if a package is already installed via winget
.PARAMETER Package
    Package ID (e.g., "Microsoft.PowerShell")
.OUTPUTS
    System.Boolean - Returns $true if installed, $false otherwise
.EXAMPLE
    if (Test-WingetAppInstalled -Package "Microsoft.PowerShell") { ... }
#>
function Test-WingetAppInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package
    )

    try {
        if (-not (Test-CommandExists "winget")) {
            return $false
        }

        $output = winget list --id $Package 2>$null
        return $output -match [regex]::Escape($Package)
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Install an app using Scoop
.DESCRIPTION
    Installs a package using Scoop package manager
.PARAMETER Package
    Package name (can include bucket prefix)
.PARAMETER AppName
    Human-readable app name for logging
.OUTPUTS
    System.Boolean - Returns $true if installation succeeded, $false otherwise
.EXAMPLE
    Install-ScoopApp -Package "git" -AppName "Git"
    Install-ScoopApp -Package "mybucket/my-tool" -AppName "My Tool"
#>
function Install-ScoopApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package,

        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    try {
        Write-Log "Installing $AppName via Scoop..." -Level "Info"

        scoop install $Package 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Log "$AppName installed successfully" -Level "Success"
            return $true
        }
        else {
            Write-Log "Failed to install $AppName" -Level "Error"
            return $false
        }
    }
    catch {
        Write-Log "Error installing $AppName via Scoop: $_" -Level "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Install an app using winget
.DESCRIPTION
    Installs a package using Windows Package Manager (winget)
.PARAMETER Package
    Package ID (e.g., "Microsoft.PowerShell")
.PARAMETER AppName
    Human-readable app name for logging
.OUTPUTS
    System.Boolean - Returns $true if installation succeeded, $false otherwise
.EXAMPLE
    Install-WingetApp -Package "Microsoft.PowerShell" -AppName "PowerShell"
#>
function Install-WingetApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package,

        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    try {
        Write-Log "Installing $AppName via winget..." -Level "Info"

        winget install --id $Package --silent 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Log "$AppName installed successfully" -Level "Success"
            return $false
        }
        else {
            Write-Log "Failed to install $AppName" -Level "Error"
            return $false
        }
    }
    catch {
        Write-Log "Error installing $AppName via winget: $_" -Level "Error"
        return $false
    }
}
