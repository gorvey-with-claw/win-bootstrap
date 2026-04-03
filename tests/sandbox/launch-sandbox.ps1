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
    
    # 检测 PowerShell 版本
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "      PowerShell Version: $psVersion" -ForegroundColor Gray
    
    # 方法1: 使用 dism.exe（适用于所有 PowerShell 版本）
    Write-Host "      Checking with dism.exe..." -ForegroundColor Gray
    
    $dismOutput = & dism.exe /Online /Get-FeatureInfo /FeatureName:Containers-DisposableClient 2>&1
    
    # 调试输出（显示前3行）
    Write-Host "      dism output (first 3 lines):" -ForegroundColor Gray
    $dismOutput | Select-Object -First 3 | ForEach-Object { Write-Host "        $_" -ForegroundColor Gray }
    
    if ($dismOutput -match "State : Enabled") {
        Write-Host "      OK: Windows Sandbox enabled" -ForegroundColor Green
        return
    }
    
    if ($dismOutput -match "State : Disabled") {
        Write-Host "      Windows Sandbox is disabled" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "      To enable, run as Administrator:" -ForegroundColor Yellow
        Write-Host "        dism.exe /Online /Enable-Feature /FeatureName:Containers-DisposableClient /All" -ForegroundColor White
        exit 1
    }
    
    # 检查是否有错误信息
    if ($dismOutput -match "Error|error|Fail|fail") {
        Write-Host "      dism.exe returned error" -ForegroundColor Yellow
        Write-Host "      Full output:" -ForegroundColor Gray
        $dismOutput | ForEach-Object { Write-Host "        $_" -ForegroundColor Gray }
    }
    
    # dism 没有返回有效状态
    Write-Host "      Unable to determine Windows Sandbox status" -ForegroundColor Red
    Write-Host "" -ForegroundColor Yellow
    Write-Host "      Common reasons:" -ForegroundColor Yellow
    Write-Host "        - Windows Sandbox feature not installed" -ForegroundColor White
    Write-Host "        - Not running as Administrator" -ForegroundColor White
    Write-Host "        - Windows version doesn't support Sandbox (requires Pro/Enterprise)" -ForegroundColor White
    Write-Host "" -ForegroundColor Yellow
    Write-Host "      To enable Windows Sandbox:" -ForegroundColor Yellow
    Write-Host "        1. Run: optionalfeatures.exe" -ForegroundColor White
    Write-Host "        2. Check 'Windows Sandbox'" -ForegroundColor White
    Write-Host "        3. Restart computer" -ForegroundColor White
    exit 1
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
    
    # 构建命令 - 不使用 XML 转义，直接使用原始字符串
    $commandText = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command `"Set-Location '$sandboxRepoPath'; Write-Host 'Mapped Mode: Testing local code...' -ForegroundColor Green; Write-Host 'Running: .\bootstrap.ps1' -ForegroundColor Gray; .\bootstrap.ps1`""

    $wsbContent = @"
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$RepoRoot</HostFolder>
      <SandboxFolder>$sandboxRepoPath</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command><![CDATA[$commandText]]></Command>
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
    
    # 构建命令 - 使用 CDATA 避免 XML 转义问题
    $commandText = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command `"Write-Host 'Clean Clone Mode: Cloning from GitHub...' -ForegroundColor Green; git clone https://github.com/gorvey-with-claw/win-bootstrap.git '$sandboxRepoPath'; if (Test-Path '$sandboxRepoPath\bootstrap.ps1') { Set-Location '$sandboxRepoPath'; Write-Host 'Running bootstrap.ps1...' -ForegroundColor Green; .\bootstrap.ps1 } else { Write-Error 'Clone failed or bootstrap.ps1 not found' }`""

    $wsbContent = @"
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
  </MappedFolders>
  <LogonCommand>
    <Command><![CDATA[$commandText]]></Command>
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