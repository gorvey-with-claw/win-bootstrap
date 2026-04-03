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
