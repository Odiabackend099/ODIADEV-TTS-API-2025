# tests\test-endpoints.ps1
# Simple PowerShell test script for ODIADEV TTS API endpoints

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$AdminTokenFile = "secrets\ADMIN_TOKEN.txt"
)

$ErrorActionPreference = "Continue"

Write-Host "🚀 ODIADEV TTS API Endpoint Tests" -ForegroundColor Cyan
Write-Host "Testing against: $BaseUrl" -ForegroundColor Yellow
Write-Host "=" * 50

# Load admin token
$adminToken = $null
if (Test-Path $AdminTokenFile) {
    $adminToken = Get-Content $AdminTokenFile -Raw
    Write-Host "✅ Admin token loaded" -ForegroundColor Green
} else {
    Write-Host "⚠️  Admin token not found at $AdminTokenFile" -ForegroundColor Yellow
}

# Test 1: Health endpoint
Write-Host "`n🔍 Test 1: Health Endpoint" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET -TimeoutSec 10
    Write-Host "✅ Health endpoint: PASSED" -ForegroundColor Green
    Write-Host "   Status: $($response.status)" -ForegroundColor White
    Write-Host "   Engine: $($response.engine)" -ForegroundColor White
} catch {
    Write-Host "❌ Health endpoint: FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Voices endpoint
Write-Host "`n🔍 Test 2: Voices Endpoint" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/v1/voices" -Method GET -TimeoutSec 10
    Write-Host "✅ Voices endpoint: PASSED" -ForegroundColor Green
    Write-Host "   Available voices: $($response.voices -join ', ')" -ForegroundColor White
    Write-Host "   Engine: $($response.engine)" -ForegroundColor White
} catch {
    Write-Host "❌ Voices endpoint: FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Admin key issuance (if token available)
$testApiKey = $null
if ($adminToken) {
    Write-Host "`n🔍 Test 3: Admin Key Issuance" -ForegroundColor Cyan
    try {
        $headers = @{
            "x-admin-token" = $adminToken
            "Content-Type" = "application/json"
        }
        $body = @{
            label = "test-key-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            rate_limit_per_min = 10
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/admin/keys/issue" -Method POST -Headers $headers -Body $body -TimeoutSec 15
        $testApiKey = $response.plaintext_key
        Write-Host "✅ Admin key issuance: PASSED" -ForegroundColor Green
        Write-Host "   Key ID: $($response.record.id)" -ForegroundColor White
        Write-Host "   Label: $($response.record.label)" -ForegroundColor White
    } catch {
        Write-Host "❌ Admin key issuance: FAILED" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n⚠️  Test 3: Admin Key Issuance SKIPPED (no admin token)" -ForegroundColor Yellow
}

# Test 4: TTS endpoint (if API key available)
if ($testApiKey) {
    Write-Host "`n🔍 Test 4: TTS Generation" -ForegroundColor Cyan
    try {
        $headers = @{
            "x-api-key" = $testApiKey
            "Content-Type" = "application/json"
        }
        $body = @{
            text = "Hello from ODIADEV TTS API test!"
            voice = "naija_female"
            format = "mp3"
            speed = 1.0
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/v1/tts" -Method POST -Headers $headers -Body $body -TimeoutSec 30
        
        if ($response.url) {
            Write-Host "✅ TTS generation: PASSED (S3 URL)" -ForegroundColor Green
            Write-Host "   Format: $($response.format)" -ForegroundColor White
            Write-Host "   Cache hit: $($response.cache_hit)" -ForegroundColor White
            Write-Host "   Duration: $($response.ms)ms" -ForegroundColor White
        } else {
            Write-Host "✅ TTS generation: PASSED (binary response)" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ TTS generation: FAILED" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n⚠️  Test 4: TTS Generation SKIPPED (no API key)" -ForegroundColor Yellow
}

Write-Host "`n" + "=" * 50
Write-Host "🎯 Test suite completed!" -ForegroundColor Cyan
Write-Host "For full testing, ensure Supabase is configured and Docker is running." -ForegroundColor Yellow