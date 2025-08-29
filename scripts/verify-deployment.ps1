# scripts\verify-deployment.ps1
# Deployment Verification Script for ODIADEV TTS API

param(
    [string]$Domain = "",
    [string]$PublicIP = "",
    [string]$DeploymentFile = "ec2-deployment.json",
    [switch]$SkipDNS = $false,
    [switch]$TestSSL = $true,
    [string]$AdminToken = ""
)

$ErrorActionPreference = "Continue"

Write-Host "🔍 ODIADEV TTS API - Deployment Verification" -ForegroundColor Cyan
Write-Host "=" * 50

# Load deployment info if available
if (Test-Path $DeploymentFile) {
    try {
        $deploymentInfo = Get-Content $DeploymentFile | ConvertFrom-Json
        if (-not $PublicIP) { $PublicIP = $deploymentInfo.publicIp }
        if (-not $Domain) { $Domain = $deploymentInfo.domain }
        Write-Host "✅ Loaded deployment info from: $DeploymentFile" -ForegroundColor Green
        Write-Host "   Instance ID: $($deploymentInfo.instanceId)" -ForegroundColor White
        Write-Host "   Public IP: $PublicIP" -ForegroundColor White
        if ($Domain) {
            Write-Host "   Domain: $Domain" -ForegroundColor White
        }
    } catch {
        Write-Host "⚠️  Could not load deployment file: $DeploymentFile" -ForegroundColor Yellow
    }
}

if (-not $PublicIP) {
    Write-Host "❌ Public IP is required" -ForegroundColor Red
    Write-Host "   Usage: .\scripts\verify-deployment.ps1 -PublicIP '1.2.3.4' [-Domain 'api.example.com']" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nTarget Configuration:" -ForegroundColor Cyan
Write-Host "   Public IP: $PublicIP" -ForegroundColor White
Write-Host "   Domain: $(if($Domain) { $Domain } else { 'Not specified' })" -ForegroundColor White

# Load admin token if available
if (-not $AdminToken -and (Test-Path "secrets\ADMIN_TOKEN.txt")) {
    try {
        $AdminToken = Get-Content "secrets\ADMIN_TOKEN.txt" -Raw
        Write-Host "✅ Admin token loaded from secrets" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not load admin token" -ForegroundColor Yellow
    }
}

# Test 1: DNS Resolution
if ($Domain -and -not $SkipDNS) {
    Write-Host "`n🌐 Testing DNS Resolution..." -ForegroundColor Cyan
    try {
        $dnsResult = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop
        $resolvedIP = $dnsResult[0].IPAddress
        
        if ($resolvedIP -eq $PublicIP) {
            Write-Host "✅ DNS resolution correct: $Domain -> $resolvedIP" -ForegroundColor Green
        } else {
            Write-Host "⚠️  DNS mismatch: $Domain -> $resolvedIP (expected: $PublicIP)" -ForegroundColor Yellow
            Write-Host "   Please update your DNS A record" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ DNS resolution failed for: $Domain" -ForegroundColor Red
        Write-Host "   Please configure DNS A record: $Domain -> $PublicIP" -ForegroundColor Yellow
    }
}

# Test 2: HTTP Health Check (IP)
Write-Host "`n🔍 Testing HTTP Health Check (IP)..." -ForegroundColor Cyan
try {
    $httpHealth = Invoke-RestMethod -Uri "http://${PublicIP}/health" -TimeoutSec 10
    if ($httpHealth.status -eq "ok") {
        Write-Host "✅ HTTP health check passed" -ForegroundColor Green
        Write-Host "   Status: $($httpHealth.status)" -ForegroundColor White
        Write-Host "   Engine: $($httpHealth.engine)" -ForegroundColor White
    } else {
        Write-Host "⚠️  HTTP health check returned unexpected status: $($httpHealth.status)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ HTTP health check failed" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Check if the instance is running and port 80 is accessible" -ForegroundColor Yellow
}

# Test 3: HTTPS Health Check (IP)
if ($TestSSL) {
    Write-Host "`n🔒 Testing HTTPS Health Check (IP)..." -ForegroundColor Cyan
    try {
        # Skip certificate validation for IP-based HTTPS
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        $httpsHealth = Invoke-RestMethod -Uri "https://${PublicIP}/health" -TimeoutSec 10
        if ($httpsHealth.status -eq "ok") {
            Write-Host "✅ HTTPS health check passed" -ForegroundColor Green
        } else {
            Write-Host "⚠️  HTTPS health check returned unexpected status" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  HTTPS health check failed (expected for IP-based access)" -ForegroundColor Yellow
        Write-Host "   This is normal if using IP instead of domain" -ForegroundColor Gray
    } finally {
        # Reset certificate validation
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }
}

# Test 4: Domain HTTPS Health Check
if ($Domain -and $TestSSL) {
    Write-Host "`n🔒 Testing HTTPS Health Check (Domain)..." -ForegroundColor Cyan
    try {
        $domainHttpsHealth = Invoke-RestMethod -Uri "https://${Domain}/health" -TimeoutSec 10
        if ($domainHttpsHealth.status -eq "ok") {
            Write-Host "✅ Domain HTTPS health check passed" -ForegroundColor Green
            Write-Host "   URL: https://$Domain/health" -ForegroundColor White
        } else {
            Write-Host "⚠️  Domain HTTPS health check returned unexpected status" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Domain HTTPS health check failed" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   This may be due to DNS propagation delay or SSL certificate issues" -ForegroundColor Yellow
    }
}

# Test 5: Voices Endpoint
Write-Host "`n🎵 Testing Voices Endpoint..." -ForegroundColor Cyan
$baseUrl = if ($Domain) { "https://$Domain" } else { "http://$PublicIP" }
try {
    $voices = Invoke-RestMethod -Uri "$baseUrl/v1/voices" -TimeoutSec 10
    if ($voices.voices -and $voices.voices.Count -gt 0) {
        Write-Host "✅ Voices endpoint working" -ForegroundColor Green
        Write-Host "   Available voices: $($voices.voices -join ', ')" -ForegroundColor White
        Write-Host "   Engine: $($voices.engine)" -ForegroundColor White
    } else {
        Write-Host "⚠️  Voices endpoint returned no voices" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Voices endpoint failed" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Admin Key Issuance (if admin token available)
if ($AdminToken) {
    Write-Host "`n🔑 Testing Admin Key Issuance..." -ForegroundColor Cyan
    try {
        $headers = @{
            "x-admin-token" = $AdminToken
            "Content-Type" = "application/json"
        }
        $keyRequest = @{
            label = "verification-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            rate_limit_per_min = 10
        } | ConvertTo-Json

        $keyResponse = Invoke-RestMethod -Uri "$baseUrl/admin/keys/issue" -Method POST -Headers $headers -Body $keyRequest -TimeoutSec 15
        
        if ($keyResponse.plaintext_key) {
            Write-Host "✅ Admin key issuance working" -ForegroundColor Green
            Write-Host "   Test key issued: $($keyResponse.record.id)" -ForegroundColor White
            $testApiKey = $keyResponse.plaintext_key
        } else {
            Write-Host "⚠️  Admin key issuance returned unexpected response" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Admin key issuance failed" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Check Supabase configuration and admin token" -ForegroundColor Yellow
    }
}

# Test 7: TTS Generation (if test API key available)
if ($testApiKey) {
    Write-Host "`n🎤 Testing TTS Generation..." -ForegroundColor Cyan
    try {
        $ttsHeaders = @{
            "x-api-key" = $testApiKey
            "Content-Type" = "application/json"
        }
        $ttsRequest = @{
            text = "Hello from ODIADEV TTS verification test!"
            voice = "naija_female"
            format = "mp3"
            speed = 1.0
        } | ConvertTo-Json

        $ttsResponse = Invoke-RestMethod -Uri "$baseUrl/v1/tts" -Method POST -Headers $ttsHeaders -Body $ttsRequest -TimeoutSec 30
        
        if ($ttsResponse.url -or $ttsResponse.format) {
            Write-Host "✅ TTS generation working" -ForegroundColor Green
            if ($ttsResponse.url) {
                Write-Host "   Audio URL: $($ttsResponse.url)" -ForegroundColor White
                Write-Host "   Cache hit: $($ttsResponse.cache_hit)" -ForegroundColor White
                Write-Host "   Generation time: $($ttsResponse.ms)ms" -ForegroundColor White
            } else {
                Write-Host "   Binary audio response received" -ForegroundColor White
            }
        } else {
            Write-Host "⚠️  TTS generation returned unexpected response" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ TTS generation failed" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Check TTS engine configuration and Coqui model downloads" -ForegroundColor Yellow
    }
}

# Test 8: Security Headers
Write-Host "`n🛡️ Testing Security Headers..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 10
    
    $securityHeaders = @{
        "Strict-Transport-Security" = "HSTS"
        "X-Content-Type-Options" = "Content Type Options"
        "X-Frame-Options" = "Frame Options"
        "X-XSS-Protection" = "XSS Protection"
    }
    
    $headerResults = @()
    foreach ($header in $securityHeaders.Keys) {
        if ($response.Headers[$header]) {
            Write-Host "   ✅ $($securityHeaders[$header]): $($response.Headers[$header])" -ForegroundColor Green
            $headerResults += $true
        } else {
            Write-Host "   ⚠️  Missing: $($securityHeaders[$header])" -ForegroundColor Yellow
            $headerResults += $false
        }
    }
    
    $securityScore = ($headerResults | Where-Object { $_ }).Count
    Write-Host "   Security Score: $securityScore/$($securityHeaders.Count)" -ForegroundColor $(if($securityScore -gt 2) { "Green" } else { "Yellow" })
} catch {
    Write-Host "⚠️  Could not test security headers" -ForegroundColor Yellow
}

# Test 9: Rate Limiting (if test API key available)
if ($testApiKey) {
    Write-Host "`n⏱️ Testing Rate Limiting..." -ForegroundColor Cyan
    try {
        $rateLimitTest = $true
        $requestCount = 0
        
        for ($i = 1; $i -le 15; $i++) {
            try {
                $ttsHeaders = @{ "x-api-key" = $testApiKey; "Content-Type" = "application/json" }
                $quickRequest = @{ text = "test"; voice = "naija_female" } | ConvertTo-Json
                
                Invoke-RestMethod -Uri "$baseUrl/v1/tts" -Method POST -Headers $ttsHeaders -Body $quickRequest -TimeoutSec 5 | Out-Null
                $requestCount++
            } catch {
                if ($_.Exception.Message -like "*429*" -or $_.Exception.Message -like "*rate*") {
                    Write-Host "✅ Rate limiting active (blocked after $requestCount requests)" -ForegroundColor Green
                    $rateLimitTest = $true
                    break
                }
            }
            Start-Sleep 1
        }
        
        if ($requestCount -ge 15) {
            Write-Host "⚠️  Rate limiting may not be configured (15 requests succeeded)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Could not test rate limiting" -ForegroundColor Yellow
    }
}

# Performance Benchmark
Write-Host "`n⚡ Performance Benchmark..." -ForegroundColor Cyan
$performanceResults = @()

for ($i = 1; $i -le 3; $i++) {
    try {
        $startTime = Get-Date
        $healthCheck = Invoke-RestMethod -Uri "$baseUrl/health" -TimeoutSec 10
        $endTime = Get-Date
        $responseTime = ($endTime - $startTime).TotalMilliseconds
        $performanceResults += $responseTime
        Write-Host "   Health check $i: ${responseTime}ms" -ForegroundColor Gray
    } catch {
        Write-Host "   Health check $i: Failed" -ForegroundColor Red
    }
}

if ($performanceResults.Count -gt 0) {
    $avgResponseTime = [math]::Round(($performanceResults | Measure-Object -Average).Average, 1)
    Write-Host "   Average response time: ${avgResponseTime}ms" -ForegroundColor $(if($avgResponseTime -lt 200) { "Green" } elseif($avgResponseTime -lt 500) { "Yellow" } else { "Red" })
}

# Generate Verification Report
Write-Host "`n📊 Generating Verification Report..." -ForegroundColor Cyan

$verificationReport = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    target = @{
        publicIP = $PublicIP
        domain = $Domain
        baseUrl = $baseUrl
    }
    tests = @{
        httpHealth = try { $httpHealth.status -eq "ok" } catch { $false }
        httpsHealth = try { $domainHttpsHealth.status -eq "ok" -or $httpsHealth.status -eq "ok" } catch { $false }
        voicesEndpoint = try { $voices.voices.Count -gt 0 } catch { $false }
        adminKeyIssuance = try { $keyResponse.plaintext_key -ne $null } catch { $false }
        ttsGeneration = try { $ttsResponse.url -ne $null -or $ttsResponse.format -ne $null } catch { $false }
        securityHeaders = try { $securityScore -gt 2 } catch { $false }
        averageResponseTime = if ($performanceResults.Count -gt 0) { $avgResponseTime } else { $null }
    }
    recommendations = @()
}

# Add recommendations
if (-not $verificationReport.tests.httpsHealth -and $Domain) {
    $verificationReport.recommendations += "Configure DNS A record: $Domain -> $PublicIP"
}
if (-not $verificationReport.tests.adminKeyIssuance) {
    $verificationReport.recommendations += "Check Supabase configuration and admin token"
}
if (-not $verificationReport.tests.ttsGeneration) {
    $verificationReport.recommendations += "Verify TTS engine and Coqui model downloads"
}
if (-not $verificationReport.tests.securityHeaders) {
    $verificationReport.recommendations += "Review Caddy security header configuration"
}

$verificationReport | ConvertTo-Json -Depth 3 | Out-File -FilePath "verification-report.json" -Encoding utf8

# Summary
Write-Host "`n🎯 Verification Summary:" -ForegroundColor Cyan
Write-Host "=" * 50

$passedTests = ($verificationReport.tests.PSObject.Properties | Where-Object { $_.Value -eq $true }).Count
$totalTests = ($verificationReport.tests.PSObject.Properties | Where-Object { $_.Name -ne "averageResponseTime" }).Count

Write-Host "Tests Passed: $passedTests/$totalTests" -ForegroundColor $(if($passedTests -eq $totalTests) { "Green" } elseif($passedTests -gt ($totalTests * 0.7)) { "Yellow" } else { "Red" })

if ($verificationReport.tests.httpHealth) { Write-Host "✅ HTTP Health Check" -ForegroundColor Green } else { Write-Host "❌ HTTP Health Check" -ForegroundColor Red }
if ($verificationReport.tests.httpsHealth) { Write-Host "✅ HTTPS Health Check" -ForegroundColor Green } else { Write-Host "❌ HTTPS Health Check" -ForegroundColor Red }
if ($verificationReport.tests.voicesEndpoint) { Write-Host "✅ Voices Endpoint" -ForegroundColor Green } else { Write-Host "❌ Voices Endpoint" -ForegroundColor Red }
if ($verificationReport.tests.adminKeyIssuance) { Write-Host "✅ Admin Key Issuance" -ForegroundColor Green } else { Write-Host "❌ Admin Key Issuance" -ForegroundColor Red }
if ($verificationReport.tests.ttsGeneration) { Write-Host "✅ TTS Generation" -ForegroundColor Green } else { Write-Host "❌ TTS Generation" -ForegroundColor Red }
if ($verificationReport.tests.securityHeaders) { Write-Host "✅ Security Headers" -ForegroundColor Green } else { Write-Host "❌ Security Headers" -ForegroundColor Red }

if ($avgResponseTime) {
    Write-Host "⚡ Average Response Time: ${avgResponseTime}ms" -ForegroundColor $(if($avgResponseTime -lt 200) { "Green" } elseif($avgResponseTime -lt 500) { "Yellow" } else { "Red" })
}

if ($verificationReport.recommendations.Count -gt 0) {
    Write-Host "`n📋 Recommendations:" -ForegroundColor Yellow
    foreach ($rec in $verificationReport.recommendations) {
        Write-Host "   • $rec" -ForegroundColor White
    }
}

Write-Host "`n📄 Full report saved to: verification-report.json" -ForegroundColor Cyan

if ($passedTests -eq $totalTests) {
    Write-Host "`n🎉 All tests passed! Deployment is ready for production." -ForegroundColor Green
} elseif ($passedTests -gt ($totalTests * 0.7)) {
    Write-Host "`n⚠️  Most tests passed. Address recommendations for production readiness." -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Several tests failed. Please review the configuration and try again." -ForegroundColor Red
}

# Cleanup test API key if created
if ($testApiKey -and $AdminToken) {
    Write-Host "`n🧹 Cleaning up test API key..." -ForegroundColor Gray
    try {
        # This would require implementing a revoke endpoint or direct database access
        Write-Host "   Test API key cleanup requires manual deletion from Supabase" -ForegroundColor Gray
    } catch {
        # Ignore cleanup errors
    }
}