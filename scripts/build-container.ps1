# scripts\build-container.ps1
# Enhanced Container Build Script for ODIADEV TTS API

param(
    [string]$ImageName = "odiadev-tts-api",
    [string]$Tag = "v1.0.0",
    [switch]$NoBuild,
    [switch]$Validate,
    [switch]$TestRun
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Enhanced Container Build" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

function Test-DockerAvailable {
    try {
        $version = docker --version 2>$null
        if ($version) {
            docker info 2>$null | Out-Null
            return $true
        }
    } catch {}
    return $false
}

function Validate-BuildContext {
    Write-Host "`nValidating build context..." -ForegroundColor Yellow
    
    $required = @(
        "Dockerfile",
        "server/requirements.txt", 
        "server/app.py",
        "config/.env",
        "voices/voice_config.json"
    )
    
    $missing = @()
    foreach ($file in $required) {
        if (-not (Test-Path $file)) {
            $missing += $file
        } else {
            Write-Host "OK $file" -ForegroundColor Green
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "`nMissing required files:" -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "  X $_" -ForegroundColor Red }
        return $false
    }
    
    Write-Host "`nBuild context validation: PASSED" -ForegroundColor Green
    return $true
}

function Show-BuildInfo {
    Write-Host "`nBuild Configuration:" -ForegroundColor Cyan
    Write-Host "Image Name: $ImageName" -ForegroundColor White
    Write-Host "Tag: $Tag" -ForegroundColor White
    Write-Host "Full Image: ${ImageName}:${Tag}" -ForegroundColor White
    
    if (Test-Path "voices/voice_config.json") {
        $voiceConfig = Get-Content "voices/voice_config.json" | ConvertFrom-Json
        Write-Host "Nigerian Voices: $($voiceConfig.voices.Keys -join ', ')" -ForegroundColor White
        Write-Host "Default Voice: $($voiceConfig.default_voice)" -ForegroundColor White
    }
}

if ($Validate -or $NoBuild) {
    Show-BuildInfo
    $valid = Validate-BuildContext
    
    if ($NoBuild) {
        if ($valid) {
            Write-Host "`nValidation complete - ready for build!" -ForegroundColor Green
        } else {
            Write-Host "`nValidation failed - fix issues before building" -ForegroundColor Red
        }
        return
    }
}

# Check Docker availability
if (-not (Test-DockerAvailable)) {
    Write-Host "`nDocker is not available!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop and ensure it's running." -ForegroundColor Yellow
    Write-Host "Run: .\scripts\install-docker.ps1" -ForegroundColor White
    exit 1
}

Write-Host "`nDocker is available and running" -ForegroundColor Green

# Validate build context
if (-not (Validate-BuildContext)) {
    Write-Host "`nBuild context validation failed!" -ForegroundColor Red
    exit 1
}

Show-BuildInfo

# Build the container
Write-Host "`nBuilding container..." -ForegroundColor Yellow
Write-Host "Command: docker build -t ${ImageName}:${Tag} ." -ForegroundColor Gray

try {
    $buildOutput = docker build -t "${ImageName}:${Tag}" . 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nContainer build: SUCCESS" -ForegroundColor Green
        
        # Show image info
        $imageInfo = docker images "${ImageName}:${Tag}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        Write-Host "`nBuilt Image:" -ForegroundColor Cyan
        Write-Host $imageInfo -ForegroundColor White
        
    } else {
        Write-Host "`nContainer build: FAILED" -ForegroundColor Red
        Write-Host "Build output:" -ForegroundColor Yellow
        $buildOutput | Write-Host -ForegroundColor Gray
        exit 1
    }
    
} catch {
    Write-Host "`nBuild failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($TestRun) {
    Write-Host "`nRunning test container..." -ForegroundColor Yellow
    
    try {
        # Run container in background for testing
        $containerId = docker run -d -p 3000:3000 --name "${ImageName}-test" "${ImageName}:${Tag}"
        
        Write-Host "Container started: $containerId" -ForegroundColor Green
        Write-Host "Waiting for startup..." -ForegroundColor Yellow
        
        # Wait for container to be ready
        Start-Sleep 10
        
        # Test health endpoint
        try {
            $health = Invoke-RestMethod -Uri "http://localhost:3000/health" -TimeoutSec 10
            Write-Host "Health check: SUCCESS" -ForegroundColor Green
            Write-Host "Status: $($health.status)" -ForegroundColor White
            Write-Host "Engine: $($health.engine)" -ForegroundColor White
        } catch {
            Write-Host "Health check: FAILED" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Test voices endpoint
        try {
            $voices = Invoke-RestMethod -Uri "http://localhost:3000/v1/voices" -TimeoutSec 10
            Write-Host "Voices check: SUCCESS" -ForegroundColor Green
            Write-Host "Available voices: $($voices.voices -join ', ')" -ForegroundColor White
        } catch {
            Write-Host "Voices check: FAILED" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Clean up test container
        Write-Host "`nCleaning up test container..." -ForegroundColor Yellow
        docker stop "${ImageName}-test" | Out-Null
        docker rm "${ImageName}-test" | Out-Null
        Write-Host "Test container removed" -ForegroundColor Green
        
    } catch {
        Write-Host "Test run failed: $($_.Exception.Message)" -ForegroundColor Red
        # Try to clean up anyway
        docker stop "${ImageName}-test" 2>$null | Out-Null
        docker rm "${ImageName}-test" 2>$null | Out-Null
    }
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Test locally: docker run -p 3000:3000 ${ImageName}:${Tag}" -ForegroundColor White
Write-Host "2. Push to ECR: .\scripts\deploy-ecr.ps1" -ForegroundColor White
Write-Host "3. Deploy to EC2: .\scripts\deploy-ec2.ps1" -ForegroundColor White

Write-Host "`nContainer build completed successfully!" -ForegroundColor Green