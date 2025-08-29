# scripts\health-check.ps1
# Health Check Script for ODIADEV TTS API (Local & Remote)

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$DeploymentFile = "ec2-deployment.json",
    [switch]$CheckLocal = $true,
    [switch]$CheckRemote = $false,
    [switch]$Detailed = $false,
    [int]$Timeout = 10,
    [int]$Retries = 3
)

$ErrorActionPreference = "Continue"

Write-Host "🔍 ODIADEV TTS API - Health Check" -ForegroundColor Cyan
Write-Host "Target: $BaseUrl" -ForegroundColor Yellow
Write-Host "Timeout: ${Timeout}s, Retries: $Retries" -ForegroundColor Yellow
Write-Host "=" * 50

# Health check function
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Name,
        [int]$TimeoutSec = 10,
        [int]$MaxRetries = 3
    )
    
    Write-Host "`n🔍 Testing: $Name" -ForegroundColor Cyan
    Write-Host "   URL: $Url" -ForegroundColor Gray
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $startTime = Get-Date
            $response = Invoke-RestMethod -Uri $Url -TimeoutSec $TimeoutSec -ErrorAction Stop
            $endTime = Get-Date
            $responseTime = ($endTime - $startTime).TotalMilliseconds
            
            Write-Host "   ✅ Success (attempt $attempt)" -ForegroundColor Green
            Write-Host "   ⏱️  Response time: $([math]::Round($responseTime, 1))ms" -ForegroundColor White
            
            if ($Detailed) {
                Write-Host "   📄 Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
            }
            
            return @{
                success = $true
                responseTime = $responseTime
                response = $response
                attempt = $attempt
            }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Host "   ❌ Attempt $attempt failed: $errorMsg" -ForegroundColor Red
            
            if ($attempt -lt $MaxRetries) {
                Write-Host "   ⏳ Retrying in 3 seconds..." -ForegroundColor Yellow
                Start-Sleep 3
            }
        }
    }
    
    return @{
        success = $false
        responseTime = $null
        response = $null
        attempt = $MaxRetries
        error = $errorMsg
    }
}

# Results tracking
$healthResults = @{
    timestamp = Get-Date
    checks = @()
    summary = @{
        total = 0
        passed = 0
        failed = 0
        avgResponseTime = 0
    }
}

# Local health check
if ($CheckLocal) {
    Write-Host "`n🏠 LOCAL HEALTH CHECKS" -ForegroundColor Magenta
    Write-Host "=" * 30
    
    # Check if local service is running
    Write-Host "`n🔍 Checking if local service is running..." -ForegroundColor Cyan
    try {
        $processes = Get-Process | Where-Object { $_.ProcessName -like "*uvicorn*" -or $_.ProcessName -like "*python*" }
        if ($processes) {
            Write-Host "   ✅ Found Python/Uvicorn processes running" -ForegroundColor Green
            foreach ($proc in $processes) {
                Write-Host "     PID $($proc.Id): $($proc.ProcessName)" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ⚠️  No Python/Uvicorn processes detected" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️  Could not check processes" -ForegroundColor Yellow
    }
    
    # Check Docker containers
    try {
        $dockerContainers = docker ps --filter "name=odiadev" --format "{{.Names}}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $dockerContainers) {
            Write-Host "   ✅ Docker containers running: $dockerContainers" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  No Docker containers running (or Docker not available)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️  Could not check Docker containers" -ForegroundColor Yellow
    }
    
    # Test local endpoints
    $localEndpoints = @(
        @{ url = "http://localhost:8080/health"; name = "Local Health" },
        @{ url = "http://localhost:8080/v1/voices"; name = "Local Voices" }
    )
    
    foreach ($endpoint in $localEndpoints) {
        $result = Test-Endpoint -Url $endpoint.url -Name $endpoint.name -TimeoutSec $Timeout -MaxRetries $Retries
        $healthResults.checks += @{
            name = $endpoint.name
            url = $endpoint.url
            success = $result.success
            responseTime = $result.responseTime
            attempt = $result.attempt
            error = $result.error
        }
        $healthResults.summary.total++
        if ($result.success) {
            $healthResults.summary.passed++
        } else {
            $healthResults.summary.failed++
        }
    }
}

# Remote health check (from deployment file)
if ($CheckRemote -or (Test-Path $DeploymentFile)) {
    Write-Host "`n☁️ REMOTE HEALTH CHECKS" -ForegroundColor Magenta
    Write-Host "=" * 30
    
    $remoteEndpoints = @()
    
    # Load deployment info if available
    if (Test-Path $DeploymentFile) {
        try {
            $deploymentInfo = Get-Content $DeploymentFile | ConvertFrom-Json
            Write-Host "✅ Loaded deployment info from: $DeploymentFile" -ForegroundColor Green
            Write-Host "   Instance ID: $($deploymentInfo.instanceId)" -ForegroundColor White
            Write-Host "   Public IP: $($deploymentInfo.publicIp)" -ForegroundColor White
            
            $remoteEndpoints += @(
                @{ url = $deploymentInfo.healthEndpoint; name = "Remote Health (HTTP)" },
                @{ url = "$($deploymentInfo.httpsEndpoint)/health"; name = "Remote Health (HTTPS)" },
                @{ url = "$($deploymentInfo.httpsEndpoint)/v1/voices"; name = "Remote Voices (HTTPS)" }
            )
            
            if ($deploymentInfo.domain) {
                Write-Host "   Domain: $($deploymentInfo.domain)" -ForegroundColor White
                $remoteEndpoints += @(
                    @{ url = "https://$($deploymentInfo.domain)/health"; name = "Domain Health" },
                    @{ url = "https://$($deploymentInfo.domain)/v1/voices"; name = "Domain Voices" }
                )
            }
        } catch {
            Write-Host "⚠️  Could not load deployment file: $DeploymentFile" -ForegroundColor Yellow
        }
    }
    
    # Add manual remote URL if specified
    if ($BaseUrl -ne "http://localhost:8080") {
        $remoteEndpoints += @(
            @{ url = "$BaseUrl/health"; name = "Custom Remote Health" },
            @{ url = "$BaseUrl/v1/voices"; name = "Custom Remote Voices" }
        )
    }
    
    # Test remote endpoints
    foreach ($endpoint in $remoteEndpoints) {
        $result = Test-Endpoint -Url $endpoint.url -Name $endpoint.name -TimeoutSec $Timeout -MaxRetries $Retries
        $healthResults.checks += @{
            name = $endpoint.name
            url = $endpoint.url
            success = $result.success
            responseTime = $result.responseTime
            attempt = $result.attempt
            error = $result.error
        }
        $healthResults.summary.total++
        if ($result.success) {
            $healthResults.summary.passed++
        } else {
            $healthResults.summary.failed++
        }
    }
}

# Calculate average response time
$successfulChecks = $healthResults.checks | Where-Object { $_.success -and $_.responseTime }
if ($successfulChecks.Count -gt 0) {
    $healthResults.summary.avgResponseTime = [math]::Round(($successfulChecks | Measure-Object -Property responseTime -Average).Average, 1)
}

# Summary Report
Write-Host "`n📊 HEALTH CHECK SUMMARY" -ForegroundColor Magenta
Write-Host "=" * 30

Write-Host "`n🎯 Results:" -ForegroundColor Cyan
Write-Host "   Total Checks: $($healthResults.summary.total)" -ForegroundColor White
Write-Host "   Passed: $($healthResults.summary.passed)" -ForegroundColor Green
Write-Host "   Failed: $($healthResults.summary.failed)" -ForegroundColor Red
Write-Host "   Success Rate: $([math]::Round($healthResults.summary.passed / $healthResults.summary.total * 100, 1))%" -ForegroundColor $(
    if ($healthResults.summary.passed -eq $healthResults.summary.total) { "Green" }
    elseif ($healthResults.summary.passed -ge ($healthResults.summary.total * 0.5)) { "Yellow" }
    else { "Red" }
)

if ($healthResults.summary.avgResponseTime -gt 0) {
    Write-Host "   Avg Response Time: $($healthResults.summary.avgResponseTime)ms" -ForegroundColor $(
        if ($healthResults.summary.avgResponseTime -lt 200) { "Green" }
        elseif ($healthResults.summary.avgResponseTime -lt 1000) { "Yellow" }
        else { "Red" }
    )
}

# Detailed results
Write-Host "`n📋 Detailed Results:" -ForegroundColor Cyan
foreach ($check in $healthResults.checks) {
    $status = if ($check.success) { "✅ PASS" } else { "❌ FAIL" }
    $responseInfo = if ($check.responseTime) { " ($([math]::Round($check.responseTime, 1))ms)" } else { "" }
    Write-Host "   $status $($check.name)$responseInfo" -ForegroundColor $(if ($check.success) { "Green" } else { "Red" })
    
    if (-not $check.success -and $check.error) {
        Write-Host "     Error: $($check.error)" -ForegroundColor Red
    }
}

# Recommendations
Write-Host "`n💡 Recommendations:" -ForegroundColor Cyan
$recommendations = @()

if ($healthResults.summary.failed -gt 0) {
    $recommendations += "Fix failed health checks before proceeding to production"
}

if ($healthResults.summary.avgResponseTime -gt 1000) {
    $recommendations += "Investigate high response times (>1000ms)"
}

$localPassed = ($healthResults.checks | Where-Object { $_.name -like "*Local*" -and $_.success }).Count
$remotePassed = ($healthResults.checks | Where-Object { $_.name -like "*Remote*" -and $_.success }).Count

if ($localPassed -eq 0 -and $CheckLocal) {
    $recommendations += "Start local development server: .\scripts\build-and-run.ps1"
}

if ($remotePassed -eq 0 -and $CheckRemote) {
    $recommendations += "Deploy to remote server or check remote configuration"
}

if ($recommendations.Count -eq 0) {
    Write-Host "   ✅ All health checks passing - system is healthy!" -ForegroundColor Green
} else {
    foreach ($rec in $recommendations) {
        Write-Host "   • $rec" -ForegroundColor Yellow
    }
}

# Save results
$healthResults | ConvertTo-Json -Depth 4 | Out-File -FilePath "health-check-results.json" -Encoding utf8
Write-Host "`n📄 Health check results saved to: health-check-results.json" -ForegroundColor Cyan

# Quick test commands
Write-Host "`n🔧 Quick Test Commands:" -ForegroundColor Cyan
Write-Host "   Test local: curl http://localhost:8080/health" -ForegroundColor White
if (Test-Path $DeploymentFile) {
    try {
        $deploymentInfo = Get-Content $DeploymentFile | ConvertFrom-Json
        Write-Host "   Test remote: curl $($deploymentInfo.healthEndpoint)" -ForegroundColor White
    } catch {
        # Ignore if can't read deployment file
    }
}
Write-Host "   Re-run health check: .\scripts\health-check.ps1" -ForegroundColor White
Write-Host "   Full verification: .\scripts\verify-deployment.ps1" -ForegroundColor White

# Exit with appropriate code
if ($healthResults.summary.failed -eq 0) {
    Write-Host "`n🎉 All health checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  Some health checks failed" -ForegroundColor Yellow
    exit 1
}