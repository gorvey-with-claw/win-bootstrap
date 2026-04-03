param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Mapped", "CleanClone")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Show-ModeMenu {
    Write-Host ""
    Write-Host "Windows Sandbox Test Modes" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1 - Mapped Mode: Test with local repository (fast, for development)" -ForegroundColor White
    Write-Host "    Maps current working directory into Sandbox and runs local code." -ForegroundColor Gray
    Write-Host ""
    Write-Host "2 - Clean Clone Mode: Test fresh GitHub clone (simulates real user)" -ForegroundColor White
    Write-Host "    Clones repository from GitHub inside Sandbox, then runs bootstrap." -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "Enter mode (1/2)"
    
    switch ($choice) {
        '1' { return "Mapped" }
        '2' { return "CleanClone" }
        default {
            Write-Error "Invalid choice: $choice. Please enter 1 or 2."
            exit 1
        }
    }
}

function Test-SandboxFeature {
    Write-Step "[1/4] Checking Windows Sandbox feature..."
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClient"
        if ($feature.State -ne "Enabled") {
            Write-Error "Windows Sandbox is not enabled."
            Write-Host "Enable it first from Windows Features or run:" -ForegroundColor Yellow
            Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClient' -All" -ForegroundColor White
            exit 1
        }
        Write-Host "      OK: Windows Sandbox enabled" -ForegroundColor Green
    }
    catch {
        Write-Host "      FAIL: Unable to query Windows Sandbox feature state." -ForegroundColor Red
        Write-Host "      This usually means the current PowerShell session does not have enough privileges." -ForegroundColor Yellow
        Write-Host "      Please rerun from an elevated PowerShell window and try again." -ForegroundColor Yellow
        exit 1
    }
}

function Get-RepositoryPath {
    Write-Step "[2/4] Resolving repository path..."
    try {
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
        $repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
        $bootstrapPath = Join-Path $repoRoot "bootstrap.ps1"

        if (-not (Test-Path $repoRoot)) {
            throw "Repository root not found: $repoRoot"
        }

        if (-not (Test-Path $bootstrapPath)) {
            throw "bootstrap.ps1 not found: $bootstrapPath"
        }

        Write-Host "      OK: $repoRoot" -ForegroundColor Green
        return $repoRoot
    }
    catch {
        Write-Error "Failed to resolve repository path: $_"
        exit 1
    }
}

function New-MappedWSB {
    param([string]$RepoRoot)
    
    Write-Step "[3/4] Generating Mapped Mode .wsb file..."
    
    $sandboxRepoPath = "C:\Users\WDAGUtilityAccount\Desktop\win-bootstrap"
    $logonCommand = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command `"Set-Location '$sandboxRepoPath'; Write-Host 'Mapped Mode: Testing local code...' -ForegroundColor Green; Write-Host 'Running: .\bootstrap.ps1' -ForegroundColor Gray; & '.\bootstrap.ps1'`""

    $escapedRepoRoot = [System.Security.SecurityElement]::Escape($RepoRoot)
    $escapedLogonCommand = [System.Security.SecurityElement]::Escape($logonCommand)

    $wsbContent = @"
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$escapedRepoRoot</HostFolder>
      <SandboxFolder>$sandboxRepoPath</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>$escapedLogonCommand</Command>
  </LogonCommand>
</Configuration>
"@

    $wsbPath = Join-Path $env:TEMP "win-bootstrap-mapped.wsb"
    $wsbContent | Out-File -FilePath $wsbPath -Encoding utf8 -Force
    
    Write-Host "      OK: $wsbPath" -ForegroundColor Green
    return $wsbPath
}

function New-CleanCloneWSB {
    Write-Step "[3/4] Generating Clean Clone Mode .wsb file..."
    
    $sandboxRepoPath = "C:\Users\WDAGUtilityAccount\Desktop\win-bootstrap"
    
    # Command to clone from GitHub and run bootstrap
    $cloneAndRunCommand = @"
powershell.exe -NoExit -ExecutionPolicy Bypass -Command "Write-Host 'Clean Clone Mode: Cloning from GitHub...' -ForegroundColor Green; git clone https://github.com/gorvey-with-claw/win-bootstrap.git '$sandboxRepoPath'; if (Test-Path '$sandboxRepoPath\bootstrap.ps1') { Set-Location '$sandboxRepoPath'; Write-Host 'Running bootstrap.ps1...' -ForegroundColor Green; .\bootstrap.ps1 } else { Write-Error 'Clone failed or bootstrap.ps1 not found' }"
"@

    $escapedLogonCommand = [System.Security.SecurityElement]::Escape($cloneAndRunCommand.Trim())

    $wsbContent = @"
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
  </MappedFolders>
  <LogonCommand>
    <Command>$escapedLogonCommand</Command>
  </LogonCommand>
</Configuration>
"@

    $wsbPath = Join-Path $env:TEMP "win-bootstrap-clean-clone.wsb"
    $wsbContent | Out-File -FilePath $wsbPath -Encoding utf8 -Force
    
    Write-Host "      OK: $wsbPath" -ForegroundColor Green
    return $wsbPath
}

function Start-SandboxTest {
    param(
        [string]$WsbPath,
        [string]$Mode
    )
    
    Write-Step "[4/4] Launching Windows Sandbox..."
    
    try {
        if ($Mode -eq "Mapped") {
            Write-Host "Launching Sandbox in Mapped Mode. It will test your LOCAL code." -ForegroundColor Gray
        } else {
            Write-Host "Launching Sandbox in Clean Clone Mode. It will clone from GitHub and test." -ForegroundColor Gray
        }
        
        Start-Process -FilePath $WsbPath
        Write-Host "Sandbox started." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to launch Windows Sandbox: $_"
        exit 1
    }
}

# ==================== Main Entry ====================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Sandbox Test Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Determine mode
if (-not $Mode) {
    $Mode = Show-ModeMenu
}

Write-Host ""
Write-Host "Selected mode: $Mode" -ForegroundColor Cyan
Write-Host ""

# Execute mode-specific flow
Test-SandboxFeature

switch ($Mode) {
    "Mapped" {
        $repoRoot = Get-RepositoryPath
        $wsbPath = New-MappedWSB -RepoRoot $repoRoot
        Start-SandboxTest -WsbPath $wsbPath -Mode $Mode
        
        Write-Host ""
        Write-Host "Mapped Mode Complete" -ForegroundColor Cyan
        Write-Host "  Testing: Local working directory code" -ForegroundColor Gray
        Write-Host "  Changes in your working directory are immediately reflected." -ForegroundColor Gray
    }
    
    "CleanClone" {
        $wsbPath = New-CleanCloneWSB
        Start-SandboxTest -WsbPath $wsbPath -Mode $Mode
        
        Write-Host ""
        Write-Host "Clean Clone Mode Complete" -ForegroundColor Cyan
        Write-Host "  Testing: Fresh clone from GitHub (production-like)" -ForegroundColor Gray
        Write-Host "  Simulates real user experience from clean environment." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan