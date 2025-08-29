# scripts\master-deploy.ps1
# Master Deployment Script for ODIADEV TTS API
# Orchestrates the complete deployment process from local build to production verification

param(
    [string]$Domain = "",
    [string]$SupabaseUrl = "",
    [string]$SupabaseServiceKey = "",
    [string]$Region = "af-south-1",
    [string]$ProfileName = "odiadev",
    [switch]$SkipLocal = $false,
    [switch]$SkipAWS = $false,
    [switch]$SkipVerification = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 ODIADEV TTS API - Master Deployment Orchestrator" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Domain: $(if($Domain) { $Domain } else { 'Not specified (will use IP)' })" -ForegroundColor Yellow
Write-Host "Profile: $ProfileName" -ForegroundColor Yellow

if (-not $Force) {
    Write-Host "`n⚠️  This will deploy the TTS API to production. Continue? (y/N)" -ForegroundColor Yellow
    $confirmation = Read-Host
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "Deployment cancelled." -ForegroundColor Gray
        exit 0
    }
}

# Initialize deployment tracking
$deploymentLog = @{
    startTime = Get-Date
    steps = @()
    errors = @()
    warnings = @()
}

function Log-Step {
    param($StepName, $Status, $Message = "", $Duration = 0)
    
    $step = @{
        name = $StepName
        status = $Status
        message = $Message
        duration = $Duration
        timestamp = Get-Date
    }
    
    $deploymentLog.steps += $step
    
    $color = switch ($Status) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "[$Status] $StepName$(if($Message) { ": $Message" })" -ForegroundColor $color
}

function Execute-Script {
    param($ScriptPath, $Arguments = @(), $StepName)
    
    $stepStart = Get-Date
    try {
        Write-Host "`n🔄 Executing: $StepName" -ForegroundColor Cyan
        $result = & $ScriptPath @Arguments
        $duration = ((Get-Date) - $stepStart).TotalSeconds
        Log-Step $StepName "SUCCESS" "Completed in $([math]::Round($duration, 1))s" $duration
        return $result
    } catch {
        $duration = ((Get-Date) - $stepStart).TotalSeconds
        Log-Step $StepName "ERROR" $_.Exception.Message $duration
        $deploymentLog.errors += @{
            step = $StepName
            error = $_.Exception.Message
            timestamp = Get-Date
        }
        throw
    }
}

# Check prerequisites
Write-Host "`n📋 PHASE 1: Prerequisites Check" -ForegroundColor Magenta
Write-Host "=" * 40

Log-Step "Prerequisites" "INFO" "Checking system requirements"

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Log-Step "PowerShell Version" "ERROR" "PowerShell 5.0 or later required"
    exit 1
} else {
    Log-Step "PowerShell Version" "SUCCESS" "v$($PSVersionTable.PSVersion)"
}

# Check if scripts exist
$requiredScripts = @(
    "scripts\setup-env.ps1",
    "scripts\setup-supabase.ps1",
    "scripts\setup-aws.ps1",
    "scripts\deploy-ecr.ps1",
    "scripts\deploy-ec2.ps1",
    "scripts\verify-deployment.ps1"
)

foreach ($script in $requiredScripts) {
    if (Test-Path $script) {
        Log-Step "Script Check" "SUCCESS" "$script found"
    } else {
        Log-Step "Script Check" "ERROR" "$script missing"
        exit 1
    }
}

# Local Setup Phase
if (-not $SkipLocal) {
    Write-Host "`n🏠 PHASE 2: Local Environment Setup" -ForegroundColor Magenta
    Write-Host "=" * 40
    
    try {
        Execute-Script "scripts\setup-env.ps1" @{} "Environment Configuration"
        
        if ($SupabaseUrl -and $SupabaseServiceKey) {
            Execute-Script "scripts\setup-supabase.ps1" @{
                SupabaseUrl = $SupabaseUrl
                ServiceRoleKey = $SupabaseServiceKey
                ApplySchema = $true
            } "Supabase Configuration"
        } else {
            Log-Step "Supabase Configuration" "WARNING" "Skipped - credentials not provided"
            $deploymentLog.warnings += "Supabase configuration skipped - manual setup required"
        }
        
        # Check Docker
        try {
            docker --version | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Log-Step "Docker Check" "SUCCESS" "Docker available"
                
                # Build Docker image if not exists
                $imageCheck = docker image inspect "odiadev/tts:local" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "`n🐳 Building Docker image..." -ForegroundColor Cyan
                    $buildStart = Get-Date
                    docker build -t odiadev/tts:local -f server/Dockerfile .
                    if ($LASTEXITCODE -eq 0) {
                        $buildDuration = ((Get-Date) - $buildStart).TotalSeconds
                        Log-Step "Docker Build" "SUCCESS" "Completed in $([math]::Round($buildDuration, 1))s"
                    } else {
                        Log-Step "Docker Build" "ERROR" "Build failed"
                        throw "Docker build failed"
                    }
                } else {
                    Log-Step "Docker Image" "SUCCESS" "Local image already exists"
                }
                
                # Test local deployment
                Write-Host "`n🧪 Testing local deployment..." -ForegroundColor Cyan
                docker compose -f infra/docker-compose.yml up -d
                if ($LASTEXITCODE -eq 0) {
                    Start-Sleep 10
                    try {
                        $healthCheck = Invoke-RestMethod -Uri "http://localhost:8080/health" -TimeoutSec 15
                        if ($healthCheck.status -eq "ok") {
                            Log-Step "Local Health Check" "SUCCESS" "API responding correctly"
                        } else {
                            Log-Step "Local Health Check" "WARNING" "Unexpected health status"
                        }
                    } catch {
                        Log-Step "Local Health Check" "WARNING" "Health check failed - container may still be starting"
                    }
                    
                    # Stop local for deployment
                    docker compose -f infra/docker-compose.yml down
                    Log-Step "Local Cleanup" "SUCCESS" "Local containers stopped"
                } else {
                    Log-Step "Local Deployment" "ERROR" "Docker compose failed"
                }
            }
        } catch {
            Log-Step "Docker Check" "ERROR" "Docker not available - install Docker Desktop"
            if (-not $Force) {
                throw "Docker required for deployment"
            }
        }
        
    } catch {
        Log-Step "Local Setup" "ERROR" $_.Exception.Message
        if (-not $Force) {
            throw
        }
    }
} else {
    Log-Step "Local Setup" "INFO" "Skipped per user request"
}

# AWS Deployment Phase
if (-not $SkipAWS) {
    Write-Host "`n☁️ PHASE 3: AWS Deployment" -ForegroundColor Magenta
    Write-Host "=" * 40
    
    try {
        # Check AWS CLI
        try {
            aws --version | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Log-Step "AWS CLI Check" "SUCCESS" "AWS CLI available"
            } else {
                throw "AWS CLI not found"
            }
        } catch {
            Log-Step "AWS CLI Check" "ERROR" "AWS CLI not installed"
            Execute-Script "scripts\setup-aws.ps1" @{} "AWS CLI Setup Guide"
            throw "Please install AWS CLI and configure credentials"
        }
        
        # ECR Deployment
        Execute-Script "scripts\deploy-ecr.ps1" @{
            Region = $Region
            ProfileName = $ProfileName
            ImageTag = "v0.1.0"
            CreateRepo = $true
            PushImage = $true
        } "ECR Image Push"
        
        # Load deployment info for EC2
        if (Test-Path "deployment-info.json") {
            $deploymentInfo = Get-Content "deployment-info.json" | ConvertFrom-Json
            $imageUri = $deploymentInfo.imageUri
            
            # EC2 Deployment
            Execute-Script "scripts\deploy-ec2.ps1" @{
                ImageUri = $imageUri
                Region = $Region
                ProfileName = $ProfileName
                Domain = $Domain
                CreateKeyPair = $true
                CreateSecurityGroup = $true
            } "EC2 Instance Deployment"
            
        } else {
            Log-Step "EC2 Deployment" "ERROR" "ECR deployment info not found"
            throw "ECR deployment must complete successfully before EC2 deployment"
        }
        
    } catch {
        Log-Step "AWS Deployment" "ERROR" $_.Exception.Message
        if (-not $Force) {
            throw
        }
    }
} else {
    Log-Step "AWS Deployment" "INFO" "Skipped per user request"
}

# Verification Phase
if (-not $SkipVerification) {
    Write-Host "`n✅ PHASE 4: Deployment Verification" -ForegroundColor Magenta
    Write-Host "=" * 40
    
    try {
        # Wait for deployment to stabilize
        Write-Host "`n⏳ Waiting for deployment to stabilize..." -ForegroundColor Cyan
        Start-Sleep 30
        
        Execute-Script "scripts\verify-deployment.ps1" @{
            Domain = $Domain
            TestSSL = $true
        } "Production Verification"
        
    } catch {
        Log-Step "Verification" "WARNING" $_.Exception.Message
        $deploymentLog.warnings += "Verification failed - manual check recommended"
    }
} else {
    Log-Step "Verification" "INFO" "Skipped per user request"
}

# Generate Final Report
Write-Host "`n📊 PHASE 5: Deployment Summary" -ForegroundColor Magenta
Write-Host "=" * 40

$deploymentLog.endTime = Get-Date
$deploymentLog.totalDuration = ($deploymentLog.endTime - $deploymentLog.startTime).TotalMinutes

# Count results
$successCount = ($deploymentLog.steps | Where-Object { $_.status -eq "SUCCESS" }).Count
$errorCount = ($deploymentLog.steps | Where-Object { $_.status -eq "ERROR" }).Count
$warningCount = ($deploymentLog.steps | Where-Object { $_.status -eq "WARNING" }).Count
$totalSteps = $deploymentLog.steps.Count

Write-Host "`n🎯 Deployment Results:" -ForegroundColor Cyan
Write-Host "   Total Steps: $totalSteps" -ForegroundColor White
Write-Host "   Successful: $successCount" -ForegroundColor Green
Write-Host "   Warnings: $warningCount" -ForegroundColor Yellow
Write-Host "   Errors: $errorCount" -ForegroundColor Red
Write-Host "   Duration: $([math]::Round($deploymentLog.totalDuration, 1)) minutes" -ForegroundColor White

# Show errors if any
if ($errorCount -gt 0) {
    Write-Host "`n❌ Errors Encountered:" -ForegroundColor Red
    foreach ($error in $deploymentLog.errors) {
        Write-Host "   • $($error.step): $($error.error)" -ForegroundColor Red
    }
}

# Show warnings if any
if ($warningCount -gt 0) {
    Write-Host "`n⚠️ Warnings:" -ForegroundColor Yellow
    foreach ($warning in $deploymentLog.warnings) {
        Write-Host "   • $warning" -ForegroundColor Yellow
    }
}

# Save full deployment log
$deploymentLog | ConvertTo-Json -Depth 5 | Out-File -FilePath "master-deployment-log.json" -Encoding utf8
Log-Step "Report Generation" "SUCCESS" "Saved to master-deployment-log.json"

# Final status
if ($errorCount -eq 0) {
    Write-Host "`n🎉 Deployment completed successfully!" -ForegroundColor Green
    
    if (Test-Path "ec2-deployment.json") {
        $ec2Info = Get-Content "ec2-deployment.json" | ConvertFrom-Json
        Write-Host "`n🌐 Production Endpoints:" -ForegroundColor Cyan
        Write-Host "   Health Check: $($ec2Info.healthEndpoint)" -ForegroundColor White
        Write-Host "   HTTPS: $($ec2Info.httpsEndpoint)" -ForegroundColor White
        if ($ec2Info.domain) {
            Write-Host "   Domain: https://$($ec2Info.domain)" -ForegroundColor White
        }
        Write-Host "   SSH: ssh -i $($ec2Info.keyPair).pem ubuntu@$($ec2Info.publicIp)" -ForegroundColor White
    }
    
    Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Configure DNS A record (if using domain)" -ForegroundColor White
    Write-Host "   2. Update Supabase configuration (if needed)" -ForegroundColor White  
    Write-Host "   3. Issue production API keys" -ForegroundColor White
    Write-Host "   4. Monitor deployment via logs and health checks" -ForegroundColor White
    Write-Host "   5. Set up monitoring and alerting (n8n workflows)" -ForegroundColor White
    
} elseif ($errorCount -eq 1 -and $successCount -gt ($totalSteps * 0.7)) {
    Write-Host "`n⚠️ Deployment mostly successful with minor issues." -ForegroundColor Yellow
    Write-Host "Review the errors above and complete any manual steps." -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Deployment encountered significant issues." -ForegroundColor Red
    Write-Host "Please review the errors and warnings, then retry the deployment." -ForegroundColor Red
    exit 1
}

Write-Host "`n📄 Full deployment log saved to: master-deployment-log.json" -ForegroundColor Cyan
Write-Host "📄 Individual step logs available in respective script outputs" -ForegroundColor Cyan