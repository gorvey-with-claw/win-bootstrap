$ErrorActionPreference = "Stop"

function Step($Message) {
    Write-Host $Message -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Sandbox launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Step "[1/4] Checking Windows Sandbox feature..."
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

Step "[2/4] Resolving repository path..."
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
}
catch {
    Write-Error "Failed to resolve repository path: $_"
    exit 1
}

Step "[3/4] Generating .wsb file..."
try {
    $sandboxRepoPath = "C:\Users\WDAGUtilityAccount\Desktop\win-bootstrap"
    $sandboxBootstrapPath = "C:\Users\WDAGUtilityAccount\Desktop\win-bootstrap\bootstrap.ps1"
    $logonCommand = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command `"Set-Location '$sandboxRepoPath'; Write-Host 'Starting local bootstrap test...' -ForegroundColor Green; & '$sandboxBootstrapPath'`""

    $escapedRepoRoot = [System.Security.SecurityElement]::Escape($repoRoot)
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

    $wsbPath = Join-Path $env:TEMP "win-bootstrap-test.wsb"
    $wsbContent | Out-File -FilePath $wsbPath -Encoding utf8 -Force
    Write-Host "      OK: $wsbPath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to generate .wsb file: $_"
    exit 1
}

Step "[4/4] Launching Windows Sandbox..."
try {
    Write-Host "Launching Sandbox. It will run the mapped local bootstrap.ps1." -ForegroundColor Gray
    Start-Process -FilePath $wsbPath
    Write-Host "Sandbox started." -ForegroundColor Green
}
catch {
    Write-Error "Failed to launch Windows Sandbox: $_"
    exit 1
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
