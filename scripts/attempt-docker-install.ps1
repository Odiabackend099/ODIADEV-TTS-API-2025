# scripts\attempt-docker-install.ps1
# Comprehensive Docker Installation Attempt

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Docker Installation Attempt" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WSLAvailable {
    try {
        $wslVersion = wsl --version 2>$null
        return $wslVersion -ne $null
    } catch {
        return $false
    }
}

function Test-HyperVCapable {
    try {
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All 2>$null
        return $hyperv -ne $null
    } catch {
        return $false
    }
}

Write-Host "`nSystem Capability Check:" -ForegroundColor Yellow

$isAdmin = Test-AdminRights
$hasWSL = Test-WSLAvailable
$canCheckHyperV = Test-HyperVCapable

Write-Host "Administrator Rights: $(if ($isAdmin) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Red' })
Write-Host "WSL Available: $(if ($hasWSL) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($hasWSL) { 'Green' } else { 'Red' })

if ($hasWSL) {
    try {
        $wslVersion = wsl --version
        Write-Host "WSL Version: $($wslVersion.Split([Environment]::NewLine)[0])" -ForegroundColor Green
    } catch {}
}

Write-Host "`nAttempting Docker Installation Methods:" -ForegroundColor Yellow

# Method 1: Check if Docker is already installed but not in PATH
Write-Host "`n1. Checking for existing Docker installations..." -ForegroundColor Cyan
$possiblePaths = @(
    "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
    "${env:LOCALAPPDATA}\Programs\Docker\Docker Desktop.exe"
)

$dockerFound = $false
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        Write-Host "Found Docker Desktop at: $path" -ForegroundColor Green
        $dockerFound = $true
        
        # Try to start it
        Write-Host "Attempting to start Docker Desktop..." -ForegroundColor Yellow
        try {
            Start-Process -FilePath $path -WindowStyle Hidden
            Write-Host "Docker Desktop start command executed" -ForegroundColor Green
            Write-Host "Please wait for Docker to initialize (2-3 minutes)" -ForegroundColor Yellow
            Write-Host "Check system tray for Docker whale icon" -ForegroundColor White
        } catch {
            Write-Host "Failed to start Docker Desktop: $($_.Exception.Message)" -ForegroundColor Red
        }
        break
    }
}

if (-not $dockerFound) {
    Write-Host "No existing Docker installation found" -ForegroundColor Red
}

# Method 2: Try winget (even though it wasn't available before)
Write-Host "`n2. Checking winget availability..." -ForegroundColor Cyan
try {
    $wingetVersion = winget --version 2>$null
    if ($wingetVersion) {
        Write-Host "winget available: $wingetVersion" -ForegroundColor Green
        
        if ($isAdmin) {
            Write-Host "Attempting Docker Desktop installation via winget..." -ForegroundColor Yellow
            try {
                winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Docker Desktop installation via winget: SUCCESS" -ForegroundColor Green
                    Write-Host "Please restart your computer to complete installation" -ForegroundColor Yellow
                } else {
                    Write-Host "Docker Desktop installation via winget: FAILED (Exit code: $LASTEXITCODE)" -ForegroundColor Red
                }
            } catch {
                Write-Host "winget installation failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "winget available but requires Administrator privileges" -ForegroundColor Yellow
        }
    } else {
        Write-Host "winget not available" -ForegroundColor Red
    }
} catch {
    Write-Host "winget not available" -ForegroundColor Red
}

# Method 3: Check for Chocolatey
Write-Host "`n3. Checking Chocolatey availability..." -ForegroundColor Cyan
try {
    $chocoVersion = choco --version 2>$null
    if ($chocoVersion) {
        Write-Host "Chocolatey available: $chocoVersion" -ForegroundColor Green
        
        if ($isAdmin) {
            Write-Host "Attempting Docker Desktop installation via Chocolatey..." -ForegroundColor Yellow
            try {
                choco install docker-desktop -y
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Docker Desktop installation via Chocolatey: SUCCESS" -ForegroundColor Green
                } else {
                    Write-Host "Docker Desktop installation via Chocolatey: FAILED" -ForegroundColor Red
                }
            } catch {
                Write-Host "Chocolatey installation failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Chocolatey available but requires Administrator privileges" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Chocolatey not available" -ForegroundColor Red
    }
} catch {
    Write-Host "Chocolatey not available" -ForegroundColor Red
}

# Method 4: Download and install manually (if admin)
Write-Host "`n4. Manual download attempt..." -ForegroundColor Cyan
if ($isAdmin) {
    Write-Host "Attempting to download Docker Desktop installer..." -ForegroundColor Yellow
    try {
        $downloadUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
        
        Write-Host "Downloading from: $downloadUrl" -ForegroundColor White
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -TimeoutSec 60
        
        if (Test-Path $installerPath) {
            Write-Host "Download successful: $installerPath" -ForegroundColor Green
            Write-Host "Attempting installation..." -ForegroundColor Yellow
            
            Start-Process -FilePath $installerPath -ArgumentList "--quiet", "--accept-license" -Wait
            
            Write-Host "Installation process completed" -ForegroundColor Green
            Write-Host "Please restart your computer to complete setup" -ForegroundColor Yellow
        } else {
            Write-Host "Download failed - file not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "Manual download failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Manual installation requires Administrator privileges" -ForegroundColor Yellow
}

# Final verification
Write-Host "`n5. Final Docker verification..." -ForegroundColor Cyan
try {
    $dockerCheck = docker --version 2>$null
    if ($dockerCheck) {
        Write-Host "SUCCESS: Docker is now available!" -ForegroundColor Green
        Write-Host "Version: $dockerCheck" -ForegroundColor White
        
        # Test docker info
        try {
            docker info 2>$null | Out-Null
            Write-Host "Docker daemon is running" -ForegroundColor Green
        } catch {
            Write-Host "Docker installed but daemon not running - start Docker Desktop" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Docker still not available in PATH" -ForegroundColor Red
    }
} catch {
    Write-Host "Docker still not available" -ForegroundColor Red
}

Write-Host "`nInstallation attempt summary:" -ForegroundColor Cyan
Write-Host "- Multiple installation methods tried" -ForegroundColor White
Write-Host "- Check results above for any successes" -ForegroundColor White
Write-Host "- If nothing worked, manual installation is required" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. If Docker was installed, restart your computer" -ForegroundColor White
Write-Host "2. Start Docker Desktop from Start Menu" -ForegroundColor White
Write-Host "3. Wait for initialization (whale icon in system tray)" -ForegroundColor White
Write-Host "4. Run: .\scripts\install-docker.ps1 -CheckOnly" -ForegroundColor White
Write-Host "5. If still not working, download manually from:" -ForegroundColor White
Write-Host "   https://www.docker.com/products/docker-desktop/" -ForegroundColor Blue

Write-Host "`nDocker installation attempt completed!" -ForegroundColor Green