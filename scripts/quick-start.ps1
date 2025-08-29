# scripts\quick-start.ps1
# ODIADEV TTS API - Quick Start Guide
# Guides you through the exact steps to reach full deployment

param(
    [switch]$CheckPrerequisites,
    [switch]$ShowNextSteps
)

$ErrorActionPreference = "Continue"

function Write-Section($title) {
    Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
}

function Test-Docker {
    try {
        $version = docker --version 2>$null
        if ($version) {
            try {
                docker info 2>$null | Out-Null
        Write-Host "Docker is installed and running" -ForegroundColor Green
                return "ready"
            } catch {
        Write-Host "Docker installed but not running" -ForegroundColor Yellow
                return "installed"
            }
        }
    } catch {}
    Write-Host "Docker not installed" -ForegroundColor Red
    return "missing"
}

function Test-AWS {
    try {
        $version = aws --version 2>$null
        if ($version) {
        Write-Host "AWS CLI is installed" -ForegroundColor Green
            return "ready"
        }
    } catch {}
    Write-Host "AWS CLI not installed" -ForegroundColor Red
    return "missing"
}

Write-Section "ODIADEV TTS API - Quick Start"

if ($CheckPrerequisites) {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    $dockerStatus = Test-Docker
    $awsStatus = Test-AWS
    
    Write-Host "`nPrerequisite Status:" -ForegroundColor Cyan
    Write-Host "Docker: $dockerStatus" -ForegroundColor White
    Write-Host "AWS CLI: $awsStatus" -ForegroundColor White
    
    if ($dockerStatus -eq "ready" -and $awsStatus -eq "ready") {
    Write-Host "All prerequisites met! Ready for deployment." -ForegroundColor Green
        Write-Host "Run: .\scripts\quick-start.ps1 -ShowNextSteps" -ForegroundColor White
    } else {
    Write-Host "Prerequisites need to be installed." -ForegroundColor Yellow
        Write-Host "Continue reading for installation steps." -ForegroundColor White
    }
    return
}

if ($ShowNextSteps) {
    Write-Section "READY FOR DEPLOYMENT"
    
    Write-Host "Prerequisites are installed. Execute in this order:" -ForegroundColor Green
    
    Write-Host "`n1. LOCAL DEVELOPMENT:" -ForegroundColor Yellow
    Write-Host "   .\scripts\build-and-run.ps1" -ForegroundColor White
    Write-Host "   .\scripts\health-check.ps1 -Local" -ForegroundColor White
    Write-Host "   .\scripts\issue-api-key.ps1" -ForegroundColor White
    Write-Host "   .\scripts\test-tts.ps1" -ForegroundColor White
    
    Write-Host "`n2. SUPABASE SETUP:" -ForegroundColor Yellow
    Write-Host "   • Go to https://app.supabase.com" -ForegroundColor White
    Write-Host "   • Create project: odiadev-tts-api" -ForegroundColor White
    Write-Host "   • Apply SQL from SUPABASE_SETUP_GUIDE.md" -ForegroundColor White
    Write-Host "   • Update .env with connection details" -ForegroundColor White
    
    Write-Host "`n3. AWS CONFIGURATION:" -ForegroundColor Yellow
    Write-Host "   aws configure" -ForegroundColor White
    Write-Host "   # Set region: af-south-1" -ForegroundColor Gray
    
    Write-Host "`n4. CLOUD DEPLOYMENT:" -ForegroundColor Yellow
    Write-Host "   .\scripts\deploy-ecr.ps1" -ForegroundColor White
    Write-Host "   .\scripts\deploy-ec2.ps1" -ForegroundColor White
    Write-Host "   .\scripts\health-check.ps1 -Remote -Url https://yourdomain.com" -ForegroundColor White
    
Write-Host "Total deployment time: 15-30 minutes" -ForegroundColor Green
    return
}

# Main installation guide
Write-Host "Current Status: Scripts ready, infrastructure setup required" -ForegroundColor Yellow

$dockerStatus = Test-Docker
$awsStatus = Test-AWS

Write-Section "STEP 1: INSTALL DOCKER DESKTOP"

if ($dockerStatus -eq "ready") {
    Write-Host "Docker is ready!" -ForegroundColor Green
} else {
    Write-Host "📥 MANUAL ACTION REQUIRED:" -ForegroundColor Red
    Write-Host "1. Download Docker Desktop:" -ForegroundColor Yellow
    Write-Host "   https://www.docker.com/products/docker-desktop/" -ForegroundColor Blue
    Write-Host "`n2. Run installer as Administrator" -ForegroundColor Yellow
    Write-Host "`n3. Enable WSL 2 integration (recommended)" -ForegroundColor Yellow
    Write-Host "`n4. Restart computer if prompted" -ForegroundColor Yellow
    Write-Host "`n5. Start Docker Desktop from Start Menu" -ForegroundColor Yellow
    Write-Host "`n6. Wait for Docker to start (green whale icon in tray)" -ForegroundColor Yellow
    Write-Host "`n7. Verify: .\scripts\install-docker.ps1 -CheckOnly" -ForegroundColor Yellow
}

Write-Section "STEP 2: INSTALL AWS CLI"

if ($awsStatus -eq "ready") {
    Write-Host "AWS CLI is ready!" -ForegroundColor Green
} else {
    Write-Host "📥 MANUAL ACTION REQUIRED:" -ForegroundColor Red
    Write-Host "1. Download AWS CLI:" -ForegroundColor Yellow
    Write-Host "   https://aws.amazon.com/cli/" -ForegroundColor Blue
    Write-Host "`n2. Run installer as Administrator" -ForegroundColor Yellow
    Write-Host "`n3. After installation, configure:" -ForegroundColor Yellow
    Write-Host "   aws configure" -ForegroundColor White
    Write-Host "   # AWS Access Key ID: [your-key]" -ForegroundColor Gray
    Write-Host "   # AWS Secret Access Key: [your-secret]" -ForegroundColor Gray
    Write-Host "   # Default region name: af-south-1" -ForegroundColor Gray
    Write-Host "   # Default output format: json" -ForegroundColor Gray
}

Write-Section "STEP 3: SETUP SUPABASE DATABASE"

Write-Host "📥 MANUAL ACTION REQUIRED:" -ForegroundColor Red
Write-Host "1. Go to https://app.supabase.com" -ForegroundColor Yellow
Write-Host "2. Click 'New Project'" -ForegroundColor Yellow
Write-Host "3. Project name: odiadev-tts-api" -ForegroundColor Yellow
Write-Host "4. Choose region (closest to af-south-1)" -ForegroundColor Yellow
Write-Host "5. Generate strong database password" -ForegroundColor Yellow
Write-Host "6. Wait for project creation (2-3 minutes)" -ForegroundColor Yellow
Write-Host "7. Go to SQL Editor and New Query" -ForegroundColor Yellow
Write-Host "8. Copy SQL from: SUPABASE_SETUP_GUIDE.md" -ForegroundColor Yellow
Write-Host "9. Execute SQL (click Run)" -ForegroundColor Yellow
Write-Host "10. Update .env with Supabase credentials" -ForegroundColor Yellow

Write-Section "VERIFICATION COMMANDS"

Write-Host "After installing prerequisites, run these to verify:" -ForegroundColor Green
Write-Host "`nDocker:" -ForegroundColor Yellow
Write-Host "docker --version" -ForegroundColor White
Write-Host "docker info" -ForegroundColor White

Write-Host "`nAWS CLI:" -ForegroundColor Yellow
Write-Host "aws --version" -ForegroundColor White
Write-Host "aws sts get-caller-identity" -ForegroundColor White

Write-Host "`nProject Status:" -ForegroundColor Yellow
Write-Host ".\scripts\quick-start.ps1 -CheckPrerequisites" -ForegroundColor White

Write-Section "NEXT STEPS"

Write-Host "Once prerequisites are installed:" -ForegroundColor Green
Write-Host ".\scripts\quick-start.ps1 -ShowNextSteps" -ForegroundColor White

Write-Host "`nQuick deployment (prerequisites installed):" -ForegroundColor Green
Write-Host ".\scripts\build-and-run.ps1" -ForegroundColor White

Write-Host "`nEstimated time:" -ForegroundColor Cyan
Write-Host "• Prerequisites: 15-20 minutes (one-time setup)" -ForegroundColor White
Write-Host "• Deployment: 15-30 minutes (automated)" -ForegroundColor White
Write-Host "• Total: 30-50 minutes to live system" -ForegroundColor White

Write-Host "You have a complete, production-ready TTS API system." -ForegroundColor Green
Write-Host "It just needs the standard tools installed to run!" -ForegroundColor White