# scripts\install-docker.ps1
# Docker Desktop Installation Script for ODIADEV TTS API

param(
    [switch]$CheckOnly,
    [switch]$PostInstallCheck
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Docker Installation" -ForegroundColor Cyan
Write-Host "=" * 50

function Test-DockerInstalled {
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Host "Docker is installed: $dockerVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # Docker not found
    }
    Write-Host "Docker is NOT installed" -ForegroundColor Red
    return $false
}

function Test-DockerRunning {
    try {
        $dockerInfo = docker info 2>$null
        if ($dockerInfo) {
            Write-Host "Docker is running" -ForegroundColor Green
            return $true
        }
    } catch {
        # Docker not running
    }
    Write-Host "Docker is installed but NOT running" -ForegroundColor Yellow
    return $false
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Host "Running with Administrator privileges" -ForegroundColor Green
        return $true
    } else {
        Write-Host "NOT running with Administrator privileges" -ForegroundColor Yellow
        return $false
    }
}

if ($CheckOnly) {
    Write-Host "`nChecking Docker installation status..." -ForegroundColor Cyan
    $dockerInstalled = Test-DockerInstalled
    
    if ($dockerInstalled) {
        $dockerRunning = Test-DockerRunning
        if ($dockerRunning) {
            Write-Host "`nSTATUS: Docker is ready for use" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "`nSTATUS: Docker installed but needs to be started" -ForegroundColor Yellow
            Write-Host "Try starting Docker Desktop from Start Menu" -ForegroundColor White
            exit 1
        }
    } else {
        Write-Host "`nSTATUS: Docker needs to be installed" -ForegroundColor Red
        exit 2
    }
}

Write-Host "`nChecking current status..." -ForegroundColor Cyan
$dockerInstalled = Test-DockerInstalled
$isAdmin = Test-AdminPrivileges

if ($dockerInstalled) {
    $dockerRunning = Test-DockerRunning
    if ($dockerRunning) {
        Write-Host "`nDocker is already installed and running!" -ForegroundColor Green
        Write-Host "You can proceed with: .\scripts\build-and-run.ps1" -ForegroundColor White
        exit 0
    } else {
        Write-Host "`nDocker is installed but not running." -ForegroundColor Yellow
        Write-Host "Please start Docker Desktop from the Start Menu." -ForegroundColor White
        Write-Host "Then run: .\scripts\build-and-run.ps1" -ForegroundColor White
        exit 0
    }
}

Write-Host "`nDocker is not installed. Installation required." -ForegroundColor Red

# Check for winget
$wingetAvailable = $false
try {
    $wingetVersion = winget --version 2>$null
    if ($wingetVersion) {
        $wingetAvailable = $true
        Write-Host "winget is available: $wingetVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "winget is not available" -ForegroundColor Yellow
}

if ($wingetAvailable -and $isAdmin) {
    Write-Host "`nAttempting automatic installation with winget..." -ForegroundColor Cyan
    
    try {
        Write-Host "Installing Docker Desktop..." -ForegroundColor Yellow
        winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nDocker Desktop installation completed!" -ForegroundColor Green
            Write-Host "`nIMPORTANT: You may need to restart your computer for Docker to work properly." -ForegroundColor Yellow
            Write-Host "After restart, run this script again to verify installation." -ForegroundColor White
        } else {
            Write-Host "`nAutomatic installation failed. Please install manually." -ForegroundColor Red
        }
    } catch {
        Write-Host "`nAutomatic installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please install manually using the steps below." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nAutomatic installation not possible." -ForegroundColor Yellow
    if (-not $wingetAvailable) {
        Write-Host "Reason: winget not available" -ForegroundColor Gray
    }
    if (-not $isAdmin) {
        Write-Host "Reason: Not running as Administrator" -ForegroundColor Gray
    }
}

Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "MANUAL INSTALLATION INSTRUCTIONS" -ForegroundColor Cyan
Write-Host "=" * 50

Write-Host "`n1. Download Docker Desktop:" -ForegroundColor Yellow
Write-Host "   https://www.docker.com/products/docker-desktop/" -ForegroundColor White

Write-Host "`n2. Run the installer as Administrator" -ForegroundColor Yellow

Write-Host "`n3. During installation:" -ForegroundColor Yellow
Write-Host "   - Enable WSL 2 integration (recommended)" -ForegroundColor White
Write-Host "   - Allow the installer to enable required Windows features" -ForegroundColor White

Write-Host "`n4. After installation:" -ForegroundColor Yellow
Write-Host "   - Restart your computer if prompted" -ForegroundColor White
Write-Host "   - Start Docker Desktop from Start Menu" -ForegroundColor White
Write-Host "   - Wait for Docker to finish starting (may take a few minutes)" -ForegroundColor White

Write-Host "`n5. Verify installation:" -ForegroundColor Yellow
Write-Host "   powershell -Command `".\scripts\install-docker.ps1 -CheckOnly`"" -ForegroundColor White

Write-Host "`n6. Once Docker is running:" -ForegroundColor Yellow
Write-Host "   .\scripts\build-and-run.ps1" -ForegroundColor White

Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "TROUBLESHOOTING" -ForegroundColor Cyan
Write-Host "=" * 50

Write-Host "`nIf Docker Desktop won't start:" -ForegroundColor Yellow
Write-Host "• Check Windows version (Windows 10/11 required)" -ForegroundColor White
Write-Host "• Enable Hyper-V in Windows Features" -ForegroundColor White  
Write-Host "• Enable WSL 2 (Windows Subsystem for Linux)" -ForegroundColor White
Write-Host "• Restart computer after enabling features" -ForegroundColor White

Write-Host "`nIf you get 'Docker daemon not running':" -ForegroundColor Yellow
Write-Host "• Start Docker Desktop application" -ForegroundColor White
Write-Host "• Wait for it to complete initialization" -ForegroundColor White
Write-Host "• Look for Docker whale icon in system tray" -ForegroundColor White

Write-Host "`nFor WSL 2 issues:" -ForegroundColor Yellow
Write-Host "• Run: wsl --install" -ForegroundColor White
Write-Host "• Restart computer" -ForegroundColor White
Write-Host "• Try starting Docker Desktop again" -ForegroundColor White

Write-Host "`nNext Steps After Docker Installation:" -ForegroundColor Cyan
Write-Host "1. Verify: .\scripts\install-docker.ps1 -CheckOnly" -ForegroundColor White
Write-Host "2. Build: .\scripts\build-and-run.ps1" -ForegroundColor White
Write-Host "3. Test: .\scripts\health-check.ps1 -Local" -ForegroundColor White

Write-Host "`nDocker installation guide completed." -ForegroundColor Green