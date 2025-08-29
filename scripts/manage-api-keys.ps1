# scripts\manage-api-keys.ps1
# API Key Management Script for ODIADEV TTS API

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Action = "issue", # issue, list, revoke, test
    [string]$Label = "",
    [int]$RateLimit = 60,
    [string]$ApiKey = "",
    [string]$KeyId = "",
    [string]$AdminTokenFile = "secrets\ADMIN_TOKEN.txt",
    [string]$OutputFile = "secrets\DEV_TTS_KEY.txt"
)

$ErrorActionPreference = "Continue"

Write-Host "🔑 ODIADEV TTS API - Key Management" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Yellow
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host "=" * 50

# Load admin token
function Get-AdminToken {
    if (Test-Path $AdminTokenFile) {
        try {
            $token = Get-Content $AdminTokenFile -Raw
            Write-Host "✅ Admin token loaded from: $AdminTokenFile" -ForegroundColor Green
            return $token.Trim()
        } catch {
            Write-Host "❌ Failed to load admin token: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "❌ Admin token file not found: $AdminTokenFile" -ForegroundColor Red
        Write-Host "   Run setup-env.ps1 to generate admin token" -ForegroundColor Yellow
        return $null
    }
}

# Issue new API key
function Issue-ApiKey {
    param($BaseUrl, $AdminToken, $Label, $RateLimit)
    
    Write-Host "`n🔐 Issuing new API key..." -ForegroundColor Cyan
    Write-Host "   Label: $Label" -ForegroundColor White
    Write-Host "   Rate limit: $RateLimit/min" -ForegroundColor White
    
    $headers = @{
        "x-admin-token" = $AdminToken
        "Content-Type" = "application/json"
    }
    
    $body = @{
        label = $Label
        rate_limit_per_min = $RateLimit
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/admin/keys/issue" -Method POST -Headers $headers -Body $body -TimeoutSec 15
        
        if ($response.plaintext_key) {
            Write-Host "✅ API key issued successfully!" -ForegroundColor Green
            Write-Host "   Key ID: $($response.record.id)" -ForegroundColor White
            Write-Host "   Label: $($response.record.label)" -ForegroundColor White
            Write-Host "   Status: $($response.record.status)" -ForegroundColor White
            Write-Host "   Rate Limit: $($response.record.rate_limit_per_min)/min" -ForegroundColor White
            Write-Host "   Created: $($response.record.created_at)" -ForegroundColor White
            
            # Save to file
            try {
                $response.plaintext_key | Out-File -FilePath $OutputFile -NoNewline -Encoding utf8
                Write-Host "🔐 API key saved securely to: $OutputFile" -ForegroundColor Green
                Write-Host "   Keep this file secure and never commit to git!" -ForegroundColor Yellow
            } catch {
                Write-Host "⚠️  Could not save API key to file: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "   Manual save required: $($response.plaintext_key)" -ForegroundColor Red
            }
            
            return $response
        } else {
            Write-Host "❌ API key issuance failed: No plaintext key in response" -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "❌ API key issuance failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`n💡 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   • Ensure the API is running at: $BaseUrl" -ForegroundColor White
        Write-Host "   • Check admin token is correct" -ForegroundColor White
        Write-Host "   • Verify Supabase connection" -ForegroundColor White
        return $null
    }
}

# Test API key functionality
function Test-ApiKey {
    param($BaseUrl, $ApiKey)
    
    Write-Host "`n🧪 Testing API key..." -ForegroundColor Cyan
    Write-Host "   Key: $($ApiKey.Substring(0, 8))..." -ForegroundColor White
    
    $headers = @{
        "x-api-key" = $ApiKey
        "Content-Type" = "application/json"
    }
    
    # Test voices endpoint first (simple test)
    try {
        Write-Host "`n🎵 Testing voices endpoint..." -ForegroundColor Cyan
        $voices = Invoke-RestMethod -Uri "$BaseUrl/v1/voices" -Headers $headers -TimeoutSec 10
        
        if ($voices.voices) {
            Write-Host "✅ Voices endpoint test passed" -ForegroundColor Green
            Write-Host "   Available voices: $($voices.voices -join ', ')" -ForegroundColor White
            Write-Host "   Engine: $($voices.engine)" -ForegroundColor White
        } else {
            Write-Host "⚠️  Voices endpoint returned unexpected response" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Voices endpoint test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test TTS endpoint (more complex test)
    try {
        Write-Host "`n🎤 Testing TTS endpoint..." -ForegroundColor Cyan
        $ttsRequest = @{
            text = "Hello from ODIADEV TTS API key test!"
            voice = "naija_female"
            format = "mp3"
            speed = 1.0
        } | ConvertTo-Json
        
        $ttsResponse = Invoke-RestMethod -Uri "$BaseUrl/v1/tts" -Method POST -Headers $headers -Body $ttsRequest -TimeoutSec 30
        
        if ($ttsResponse.url -or $ttsResponse.format) {
            Write-Host "✅ TTS endpoint test passed" -ForegroundColor Green
            if ($ttsResponse.url) {
                Write-Host "   Audio URL: $($ttsResponse.url)" -ForegroundColor White
                Write-Host "   Cache hit: $($ttsResponse.cache_hit)" -ForegroundColor White
                Write-Host "   Generation time: $($ttsResponse.ms)ms" -ForegroundColor White
            } else {
                Write-Host "   Binary audio response received" -ForegroundColor White
            }
            return $true
        } else {
            Write-Host "⚠️  TTS endpoint returned unexpected response" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ TTS endpoint test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Simulate key issuance (when API not available)
function Simulate-KeyIssuance {
    param($Label, $RateLimit)
    
    Write-Host "`n🎭 SIMULATION MODE: API Key Issuance" -ForegroundColor Magenta
    Write-Host "   (API not available - showing expected behavior)" -ForegroundColor Gray
    Write-Host ""
    
    # Generate mock API key
    $mockApiKey = -join ((1..32) | ForEach {[char][int]((65..90)+(97..122)+(48..57) | Get-Random)})
    $mockKeyId = [System.Guid]::NewGuid().ToString()
    
    Write-Host "📝 Expected API Call:" -ForegroundColor Cyan
    Write-Host "   POST $BaseUrl/admin/keys/issue" -ForegroundColor White
    Write-Host "   Headers: x-admin-token: <ADMIN_TOKEN>" -ForegroundColor White
    Write-Host "   Body: {" -ForegroundColor White
    Write-Host "     \"label\": \"$Label\"," -ForegroundColor White  
    Write-Host "     \"rate_limit_per_min\": $RateLimit" -ForegroundColor White
    Write-Host "   }" -ForegroundColor White
    
    Write-Host "`n📤 Expected Response:" -ForegroundColor Cyan
    $mockResponse = @{
        plaintext_key = $mockApiKey
        record = @{
            id = $mockKeyId
            label = $Label
            status = "active"
            rate_limit_per_min = $RateLimit
            created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
    }
    
    Write-Host "   HTTP 200 OK" -ForegroundColor Green
    Write-Host "   Content-Type: application/json" -ForegroundColor White
    Write-Host "   Body:" -ForegroundColor White
    $mockResponse | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor Gray
    
    # Save mock key for testing
    try {
        $mockApiKey | Out-File -FilePath $OutputFile -NoNewline -Encoding utf8
        Write-Host "`n💾 Mock API key saved to: $OutputFile" -ForegroundColor Green
        Write-Host "   (For testing purposes when API becomes available)" -ForegroundColor Yellow
    } catch {
        Write-Host "`n⚠️  Could not save mock API key" -ForegroundColor Yellow
    }
    
    return $mockResponse
}

# Main execution
Write-Host "`n🔍 Checking API availability..." -ForegroundColor Cyan
$apiAvailable = $false

try {
    $healthCheck = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 5
    if ($healthCheck.status -eq "ok") {
        $apiAvailable = $true
        Write-Host "✅ API is available and healthy" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  API not available: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   Will run in simulation mode" -ForegroundColor Gray
}

# Execute requested action
switch ($Action.ToLower()) {
    "issue" {
        if (-not $Label) {
            $Label = "dev-key-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }
        
        if ($apiAvailable) {
            $adminToken = Get-AdminToken
            if ($adminToken) {
                $result = Issue-ApiKey -BaseUrl $BaseUrl -AdminToken $adminToken -Label $Label -RateLimit $RateLimit
                if ($result -and $result.plaintext_key) {
                    Write-Host "`n🧪 Testing issued key..." -ForegroundColor Cyan
                    Test-ApiKey -BaseUrl $BaseUrl -ApiKey $result.plaintext_key
                }
            }
        } else {
            Simulate-KeyIssuance -Label $Label -RateLimit $RateLimit
        }
    }
    
    "test" {
        if (-not $ApiKey -and (Test-Path $OutputFile)) {
            try {
                $ApiKey = Get-Content $OutputFile -Raw
                Write-Host "✅ API key loaded from: $OutputFile" -ForegroundColor Green
            } catch {
                Write-Host "❌ Could not load API key from: $OutputFile" -ForegroundColor Red
                exit 1
            }
        }
        
        if (-not $ApiKey) {
            Write-Host "❌ No API key provided. Use -ApiKey parameter or ensure key file exists" -ForegroundColor Red
            exit 1
        }
        
        if ($apiAvailable) {
            Test-ApiKey -BaseUrl $BaseUrl -ApiKey $ApiKey.Trim()
        } else {
            Write-Host "❌ Cannot test API key - API not available" -ForegroundColor Red
        }
    }
    
    "list" {
        Write-Host "📋 API Key Listing" -ForegroundColor Cyan
        Write-Host "   This feature requires direct Supabase access" -ForegroundColor Yellow
        Write-Host "   Query: SELECT id, label, status, rate_limit_per_min, created_at FROM api_keys" -ForegroundColor Gray
    }
    
    "revoke" {
        Write-Host "🚫 API Key Revocation" -ForegroundColor Cyan
        if (-not $KeyId) {
            Write-Host "❌ Key ID required for revocation. Use -KeyId parameter" -ForegroundColor Red
            exit 1
        }
        Write-Host "   This feature requires implementation of revoke endpoint" -ForegroundColor Yellow
        Write-Host "   Expected endpoint: POST $BaseUrl/admin/keys/revoke" -ForegroundColor Gray
    }
    
    default {
        Write-Host "❌ Invalid action: $Action" -ForegroundColor Red
        Write-Host "   Valid actions: issue, test, list, revoke" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`n📝 Usage Examples:" -ForegroundColor Cyan
Write-Host "   Issue new key: .\scripts\manage-api-keys.ps1 -Action issue -Label 'mobile-app'" -ForegroundColor White
Write-Host "   Test existing key: .\scripts\manage-api-keys.ps1 -Action test" -ForegroundColor White
Write-Host "   Test specific key: .\scripts\manage-api-keys.ps1 -Action test -ApiKey 'your-key-here'" -ForegroundColor White
Write-Host "   Use remote API: .\scripts\manage-api-keys.ps1 -BaseUrl 'https://your-domain.com' -Action issue" -ForegroundColor White

Write-Host "`n🔧 Management Files:" -ForegroundColor Cyan
Write-Host "   Admin token: $AdminTokenFile" -ForegroundColor White
Write-Host "   API key storage: $OutputFile" -ForegroundColor White
Write-Host "   Keep these files secure and never commit to version control!" -ForegroundColor Yellow