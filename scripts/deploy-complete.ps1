# scripts\deploy-complete.ps1
# ODIADEV TTS API - Complete Deployment Orchestration Script

param(
    [switch]$LocalOnly,
    [switch]$CloudOnly,
    [switch]$SkipValidation,
    [switch]$DryRun,
    [string]$Domain = ""
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Complete Deployment" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Deployment phases
$phases = @(
    @{
        Name = "Prerequisites Check"
        Script = "simple-status.ps1"
        Required = $true
        Description = "Verify Docker, AWS CLI, and Supabase are ready"
    },
    @{
        Name = "Local Container Build"
        Script = "build-container.ps1"
        Required = $true
        Description = "Build and test TTS container locally"
    },
    @{
        Name = "Local Health Check"
        Script = "health-check.ps1 -Local"
        Required = $true
        Description = "Verify local API is working"
    },
    @{
        Name = "API Key Generation"
        Script = "issue-api-key.ps1"
        Required = $true
        Description = "Generate admin and test API keys"
    },
    @{
        Name = "Local TTS Testing"
        Script = "test-tts.ps1"
        Required = $true
        Description = "Test Nigerian voices locally"
    },
    @{
        Name = "ECR Repository Setup"
        Script = "deploy-ecr.ps1"
        Required = $false
        CloudOnly = $true
        Description = "Create ECR repo and push container"
    },
    @{
        Name = "EC2 Instance Deployment"
        Script = "deploy-ec2.ps1"
        Required = $false
        CloudOnly = $true
        Description = "Deploy to EC2 with Caddy HTTPS"
    },
    @{
        Name = "Remote Health Check"
        Script = "health-check.ps1 -Remote"
        Required = $false
        CloudOnly = $true
        Description = "Verify cloud deployment"
    },
    @{
        Name = "End-to-End Testing"
        Script = "test-tts.ps1"
        Required = $false
        CloudOnly = $true
        Description = "Test live system with real API"
    }
)

function Test-Prerequisites {
    Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow
    
    $issues = @()
    
    # Check Docker
    try {
        docker --version | Out-Null
        docker info | Out-Null
        Write-Host "Docker: OK" -ForegroundColor Green
    } catch {
        $issues += "Docker not available"
        Write-Host "Docker: MISSING" -ForegroundColor Red
    }
    
    # Check AWS CLI
    if (-not $LocalOnly) {
        try {
            aws --version | Out-Null
            Write-Host "AWS CLI: OK" -ForegroundColor Green
        } catch {
            $issues += "AWS CLI not available"
            Write-Host "AWS CLI: MISSING" -ForegroundColor Red
        }
    }
    
    # Check Supabase config
    if (Test-Path "config\.env") {
        $envContent = Get-Content "config\.env" -Raw
        if ($envContent -match "SUPABASE_URL" -and $envContent -match "SUPABASE_ANON_KEY") {
            Write-Host "Supabase: OK" -ForegroundColor Green
        } else {
            $issues += "Supabase not configured in .env"
            Write-Host "Supabase: NOT CONFIGURED" -ForegroundColor Red
        }
    } else {
        $issues += "No .env file found"
        Write-Host "Environment: MISSING" -ForegroundColor Red
    }
    
    return $issues
}

function Execute-Phase($phase) {
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "PHASE: $($phase.Name)" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "Description: $($phase.Description)" -ForegroundColor White
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would execute - $($phase.Script)" -ForegroundColor Yellow
        return $true
    }
    
    if ($LocalOnly -and $phase.CloudOnly) {
        Write-Host "SKIPPED: Cloud-only phase in local mode" -ForegroundColor Gray
        return $true
    }
    
    if ($CloudOnly -and -not $phase.CloudOnly) {
        Write-Host "SKIPPED: Local-only phase in cloud mode" -ForegroundColor Gray
        return $true
    }
    
    Write-Host "Executing: $($phase.Script)" -ForegroundColor Yellow
    
    try {
        $scriptPath = "scripts\$($phase.Script.Split(' ')[0])"
        $scriptArgs = $phase.Script.Split(' ')[1..100] -join ' '
        
        if (Test-Path $scriptPath) {
            if ($scriptArgs) {
                $result = & powershell -ExecutionPolicy Bypass -File $scriptPath $scriptArgs.Split(' ')
            } else {
                $result = & powershell -ExecutionPolicy Bypass -File $scriptPath
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "PHASE SUCCESS: $($phase.Name)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "PHASE FAILED: $($phase.Name)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "PHASE ERROR: Script not found - $scriptPath" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "PHASE EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "Deployment Mode: $(if ($LocalOnly) { 'LOCAL ONLY' } elseif ($CloudOnly) { 'CLOUD ONLY' } else { 'FULL DEPLOYMENT' })" -ForegroundColor Yellow

if (-not $SkipValidation) {
    $prerequisiteIssues = Test-Prerequisites
    
    if ($prerequisiteIssues.Count -gt 0) {
        Write-Host "`nPREREQUITE ISSUES FOUND:" -ForegroundColor Red
        $prerequisiteIssues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        
        Write-Host "`nPlease resolve these issues before deployment:" -ForegroundColor Red
        Write-Host "1. Install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor White
        Write-Host "2. Install AWS CLI: https://aws.amazon.com/cli/" -ForegroundColor White
        Write-Host "3. Setup Supabase: See SUPABASE_SETUP_GUIDE.md" -ForegroundColor White
        
        exit 1
    }
}

Write-Host "`nAll prerequisites met! Starting deployment..." -ForegroundColor Green

# Execute phases
$successful = 0
$failed = 0

foreach ($phase in $phases) {
    $success = Execute-Phase $phase
    
    if ($success) {
        $successful++
    } else {
        $failed++
        
        if ($phase.Required) {
            Write-Host "`nDEPLOYMENT FAILED: Required phase failed - $($phase.Name)" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "`nWARNING: Optional phase failed - $($phase.Name)" -ForegroundColor Yellow
            Write-Host "Continuing with deployment..." -ForegroundColor White
        }
    }
}

# Final summary
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host "DEPLOYMENT COMPLETE" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

Write-Host "`nSummary:" -ForegroundColor Green
Write-Host "Successful phases: $successful" -ForegroundColor White
Write-Host "Failed phases: $failed" -ForegroundColor White

if ($failed -eq 0) {
    Write-Host "`nSTATUS: DEPLOYMENT SUCCESSFUL" -ForegroundColor Green
    
    if (-not $LocalOnly) {
        Write-Host "`nYour TTS API is now live!" -ForegroundColor Green
        if ($Domain) {
            Write-Host "API URL: https://$Domain" -ForegroundColor White
            Write-Host "Health Check: https://$Domain/health" -ForegroundColor White
            Write-Host "API Docs: https://$Domain/docs" -ForegroundColor White
        } else {
            Write-Host "Configure your domain DNS and update the health check" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nLocal TTS API is running!" -ForegroundColor Green
        Write-Host "API URL: http://localhost:3000" -ForegroundColor White
        Write-Host "Health Check: http://localhost:3000/health" -ForegroundColor White
        Write-Host "API Docs: http://localhost:3000/docs" -ForegroundColor White
    }
    
} else {
    Write-Host "`nSTATUS: DEPLOYMENT COMPLETED WITH ISSUES" -ForegroundColor Yellow
    Write-Host "Check the logs above for details on failed phases" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Test the API with the generated API keys" -ForegroundColor White
Write-Host "2. Monitor usage in Supabase dashboard" -ForegroundColor White
Write-Host "3. Set up domain DNS if deploying to cloud" -ForegroundColor White
Write-Host "4. Configure monitoring and alerts" -ForegroundColor White

Write-Host "`nDeployment orchestration completed!" -ForegroundColor Green