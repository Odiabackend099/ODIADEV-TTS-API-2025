# ODIADEV TTS API Test Script
# Run this after fixing the backend 502 error

param(
    [string]$ServerUrl = "http://13.247.217.147",
    [string]$ApiKey = "sk-user-0cze1Y-8gbUpRXGmbEs5-0ScoTrw5LaGOuBGuJzu7zucKLQi1S1J-YQPCFsIUQ16QYDbj9obOOb6Uy3OaHHgu1-a-T0-8UHsY4q3mUE2Z43ksDlgO4Kqdqn1htMrLNh0GA8"
)

Write-Host "🧪 ODIADEV TTS API Test Suite" -ForegroundColor Cyan
Write-Host "Target: $ServerUrl" -ForegroundColor Yellow
Write-Host "=" * 50

$results = @{
    passed = 0
    failed = 0
    tests = @()
}

function Test-Endpoint {
    param($Name, $TestFunction)
    
    Write-Host "`n🔄 Testing: $Name" -ForegroundColor Cyan
    try {
        $result = & $TestFunction
        if ($result.success) {
            Write-Host "✅ PASS: $($result.message)" -ForegroundColor Green
            $results.passed++
        } else {
            Write-Host "❌ FAIL: $($result.message)" -ForegroundColor Red
            $results.failed++
        }
        $results.tests += @{ name = $Name; result = $result }
    } catch {
        Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $results.failed++
        $results.tests += @{ name = $Name; result = @{ success = $false; message = $_.Exception.Message } }
    }
}

# Test 1: Health Check
Test-Endpoint "Health Check" {
    try {
        $response = Invoke-WebRequest "$ServerUrl/health" -UseBasicParsing -TimeoutSec 10
        $content = $response.Content | ConvertFrom-Json
        
        if ($response.StatusCode -eq 200 -and $content.service -like "*TTS*") {
            return @{ success = $true; message = "Health check passed: $($content.status)" }
        } else {
            return @{ success = $false; message = "Unexpected health response" }
        }
    } catch {
        return @{ success = $false; message = "Health check failed: $($_.Exception.Message)" }
    }
}

# Test 2: TTS with Valid API Key
Test-Endpoint "TTS with Valid API Key" {
    try {
        $headers = @{ "x-api-key" = $ApiKey }
        $body = @{ 
            text = "Hello from ODIADEV!"
            voice = "alloy"
            format = "mp3"
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri "$ServerUrl/v1/tts" -Method POST -Body $body -Headers $headers -ContentType "application/json" -TimeoutSec 30
        
        if ($response.StatusCode -eq 200) {
            return @{ success = $true; message = "TTS generation successful" }
        } else {
            return @{ success = $false; message = "Unexpected status: $($response.StatusCode)" }
        }
    } catch {
        return @{ success = $false; message = "TTS failed: $($_.Exception.Message)" }
    }
}

# Test 3: TTS without API Key (should fail)
Test-Endpoint "TTS without API Key (Auth Test)" {
    try {
        $body = @{ 
            text = "This should fail"
            voice = "alloy"
            format = "mp3"
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri "$ServerUrl/v1/tts" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10
        return @{ success = $false; message = "Should have failed auth but got: $($response.StatusCode)" }
    } catch {
        if ($_.Exception.Response.StatusCode -in @(401, 403)) {
            return @{ success = $true; message = "Correctly rejected unauthorized request: $($_.Exception.Response.StatusCode)" }
        } else {
            return @{ success = $false; message = "Wrong error type: $($_.Exception.Message)" }
        }
    }
}

# Test 4: TTS with Bad Body (should fail)
Test-Endpoint "TTS with Malformed Body" {
    try {
        $headers = @{ "x-api-key" = $ApiKey }
        $body = '{"invalid": "json structure"}'
        
        $response = Invoke-WebRequest -Uri "$ServerUrl/v1/tts" -Method POST -Body $body -Headers $headers -ContentType "application/json" -TimeoutSec 10
        return @{ success = $false; message = "Should have failed validation but got: $($response.StatusCode)" }
    } catch {
        if ($_.Exception.Response.StatusCode -in @(400, 422)) {
            return @{ success = $true; message = "Correctly rejected bad request: $($_.Exception.Response.StatusCode)" }
        } else {
            return @{ success = $false; message = "Wrong error type: $($_.Exception.Message)" }
        }
    }
}

# Test 5: Response Time Test
Test-Endpoint "Response Time Check" {
    try {
        $headers = @{ "x-api-key" = $ApiKey }
        $body = @{ 
            text = "Quick test"
            voice = "alloy"
            format = "mp3"
        } | ConvertTo-Json
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri "$ServerUrl/v1/tts" -Method POST -Body $body -Headers $headers -ContentType "application/json" -TimeoutSec 30
        $stopwatch.Stop()
        
        $responseTime = $stopwatch.ElapsedMilliseconds / 1000.0
        
        if ($responseTime -lt 3.0) {
            return @{ success = $true; message = "Response time OK: $([math]::Round($responseTime, 2))s" }
        } else {
            return @{ success = $false; message = "Response too slow: $([math]::Round($responseTime, 2))s" }
        }
    } catch {
        return @{ success = $false; message = "Response time test failed: $($_.Exception.Message)" }
    }
}

# Summary
Write-Host "`n" + "=" * 50
Write-Host "🎯 TEST SUMMARY" -ForegroundColor Magenta
Write-Host "✅ Passed: $($results.passed)" -ForegroundColor Green
Write-Host "❌ Failed: $($results.failed)" -ForegroundColor Red
Write-Host "📊 Success Rate: $([math]::Round(($results.passed / ($results.passed + $results.failed)) * 100, 1))%" -ForegroundColor Yellow

if ($results.failed -eq 0) {
    Write-Host "`n🎉 All tests passed! Your API is working correctly." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed. Review the output above." -ForegroundColor Yellow
}

Write-Host "`n📄 Test completed at: $(Get-Date)" -ForegroundColor Cyan