# scripts\build-and-run.ps1
# Docker Build and Run Script for ODIADEV TTS API

param(
    [string]$ImageName = "odiadev/tts:local",
    [string]$ComposeFile = "infra\docker-compose.yml",
    [switch]$SkipBuild = $false,
    [switch]$SkipRun = $false,
    [switch]$Rebuild = $false,
    [int]$HealthCheckTimeout = 60
)

$ErrorActionPreference = "Stop"

Write-Host "🐳 ODIADEV TTS API - Docker Build & Run" -ForegroundColor Cyan
Write-Host "Image: $ImageName" -ForegroundColor Yellow
Write-Host "Compose File: $ComposeFile" -ForegroundColor Yellow
Write-Host "=" * 50

# Check prerequisites
Write-Host "`n🔍 Checking prerequisites..." -ForegroundColor Cyan

# Check Docker
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
        
        # Check if Docker daemon is running
        $dockerInfo = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Docker daemon: Running" -ForegroundColor Green
        } else {
            Write-Host "❌ Docker daemon: Not running" -ForegroundColor Red
            Write-Host "   Please start Docker Desktop" -ForegroundColor Yellow
            exit 1
        }
    } else {
        throw "Docker not found"
    }
} catch {
    Write-Host "❌ Docker not available" -ForegroundColor Red
    Write-Host "   Please install Docker Desktop:" -ForegroundColor Yellow
    Write-Host "   https://www.docker.com/products/docker-desktop/" -ForegroundColor Gray
    Write-Host "   Or run: choco install docker-desktop" -ForegroundColor Gray
    exit 1
}

# Check required files
$requiredFiles = @(
    "server\Dockerfile",
    "server\app.py", 
    "server\requirements.txt",
    "infra\docker-compose.yml",
    "config\.env"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ Found: $file" -ForegroundColor Green
    } else {
        Write-Host "❌ Missing: $file" -ForegroundColor Red
        exit 1
    }
}

# Build phase
if (-not $SkipBuild) {
    Write-Host "`n🔨 Building Docker image..." -ForegroundColor Cyan
    
    # Check if image exists and handle rebuild
    $imageExists = $false
    try {
        docker image inspect $ImageName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $imageExists = $true
            Write-Host "⚠️  Image already exists: $ImageName" -ForegroundColor Yellow
            
            if ($Rebuild) {
                Write-Host "🗑️ Removing existing image..." -ForegroundColor Yellow
                docker rmi $ImageName
            } else {
                Write-Host "⏭️ Skipping build (use -Rebuild to force rebuild)" -ForegroundColor Yellow
                $SkipBuild = $true
            }
        }
    } catch {
        # Image doesn't exist, proceed with build
    }
    
    if (-not $SkipBuild) {
        Write-Host "📦 Building image: $ImageName" -ForegroundColor Cyan
        $buildStart = Get-Date
        
        try {
            # Build the Docker image
            docker build -t $ImageName -f server/Dockerfile . --progress=plain
            
            if ($LASTEXITCODE -eq 0) {
                $buildDuration = ((Get-Date) - $buildStart).TotalSeconds
                Write-Host "✅ Build completed in $([math]::Round($buildDuration, 1)) seconds" -ForegroundColor Green
                
                # Get image size
                $imageInfo = docker image inspect $ImageName | ConvertFrom-Json
                $imageSizeMB = [math]::Round($imageInfo[0].Size / 1MB, 1)
                Write-Host "📏 Image size: ${imageSizeMB}MB" -ForegroundColor White
            } else {
                throw "Docker build failed"
            }
        } catch {
            Write-Host "❌ Build failed" -ForegroundColor Red
            Write-Host "   Check Dockerfile and dependencies" -ForegroundColor Yellow
            exit 1
        }
    }
} else {
    Write-Host "⏭️ Skipping build phase" -ForegroundColor Yellow
}

# Run phase
if (-not $SkipRun) {
    Write-Host "`n🚀 Starting application..." -ForegroundColor Cyan
    
    # Check if containers are already running
    $runningContainers = docker ps --filter "name=odiadev-tts" --format "{{.Names}}"
    if ($runningContainers) {
        Write-Host "⚠️  Container already running: $runningContainers" -ForegroundColor Yellow
        Write-Host "🛑 Stopping existing containers..." -ForegroundColor Yellow
        docker compose -f $ComposeFile down
    }
    
    # Start with docker-compose
    Write-Host "🚀 Starting containers with docker-compose..." -ForegroundColor Cyan
    try {
        docker compose -f $ComposeFile up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Containers started successfully" -ForegroundColor Green
            
            # Show running containers
            Write-Host "`n📋 Running containers:" -ForegroundColor Cyan
            docker ps --filter "name=odiadev" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            
        } else {
            throw "Docker compose failed"
        }
    } catch {
        Write-Host "❌ Failed to start containers" -ForegroundColor Red
        Write-Host "   Check docker-compose.yml and environment variables" -ForegroundColor Yellow
        exit 1
    }
    
    # Wait for application to be ready
    Write-Host "`n⏳ Waiting for application to be ready..." -ForegroundColor Cyan
    $healthCheckStart = Get-Date
    $isHealthy = $false
    $attempt = 1
    $maxAttempts = $HealthCheckTimeout / 5
    
    while (-not $isHealthy -and $attempt -le $maxAttempts) {
        try {
            Start-Sleep 5
            $health = Invoke-RestMethod -Uri "http://localhost:8080/health" -TimeoutSec 5
            if ($health.status -eq "ok") {
                $isHealthy = $true
                $readyTime = ((Get-Date) - $healthCheckStart).TotalSeconds
                Write-Host "✅ Application ready in $([math]::Round($readyTime, 1)) seconds" -ForegroundColor Green
                Write-Host "   Status: $($health.status)" -ForegroundColor White
                Write-Host "   Engine: $($health.engine)" -ForegroundColor White
            }
        } catch {
            Write-Host "   Attempt $attempt/$maxAttempts - Application starting..." -ForegroundColor Gray
            $attempt++
        }
    }
    
    if (-not $isHealthy) {
        Write-Host "⚠️  Application may still be starting" -ForegroundColor Yellow
        Write-Host "   Check manually: http://localhost:8080/health" -ForegroundColor White
        Write-Host "   View logs: docker logs odiadev-tts" -ForegroundColor White
    }
    
} else {
    Write-Host "⏭️ Skipping run phase" -ForegroundColor Yellow
}

# Display endpoints and next steps
Write-Host "`n🎯 Application Endpoints:" -ForegroundColor Cyan
Write-Host "   Health Check: http://localhost:8080/health" -ForegroundColor White
Write-Host "   Voices List: http://localhost:8080/v1/voices" -ForegroundColor White
Write-Host "   TTS Endpoint: http://localhost:8080/v1/tts" -ForegroundColor White
Write-Host "   Admin Keys: http://localhost:8080/admin/keys/issue" -ForegroundColor White

Write-Host "`n🔧 Management Commands:" -ForegroundColor Cyan
Write-Host "   View logs: docker logs odiadev-tts -f" -ForegroundColor White
Write-Host "   Stop app: docker compose -f $ComposeFile down" -ForegroundColor White
Write-Host "   Restart: docker compose -f $ComposeFile restart" -ForegroundColor White
Write-Host "   Shell access: docker exec -it odiadev-tts /bin/bash" -ForegroundColor White

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Test the health endpoint: curl http://localhost:8080/health" -ForegroundColor White
Write-Host "   2. Run test suite: .\tests\test-endpoints.ps1" -ForegroundColor White
Write-Host "   3. Configure Supabase connection" -ForegroundColor White
Write-Host "   4. Issue test API keys" -ForegroundColor White
Write-Host "   5. Test TTS generation" -ForegroundColor White

Write-Host "`n🎉 Local development environment ready!" -ForegroundColor Green