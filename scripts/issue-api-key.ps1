# scripts\issue-api-key.ps1
# Simple API Key Issuance Script for ODIADEV TTS API

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Label = "dev-key",
    [int]$RateLimit = 60,
    [string]$AdminTokenFile = "secrets\ADMIN_TOKEN.txt",
    [string]$OutputFile = "secrets\DEV_TTS_KEY.txt"
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Issue API Key" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host "Label: $Label" -ForegroundColor Yellow
Write-Host "Rate Limit: $RateLimit/min" -ForegroundColor Yellow
Write-Host "=" * 50

# Check API availability
Write-Host "`nChecking API availability..." -ForegroundColor Cyan
$apiAvailable = $false

try {
    $healthCheck = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 5
    if ($healthCheck.status -eq "ok") {
        $apiAvailable = $true
        Write-Host "API is available and healthy" -ForegroundColor Green
        Write-Host "   Status: $($healthCheck.status)" -ForegroundColor White
        Write-Host "   Engine: $($healthCheck.engine)" -ForegroundColor White
    }
} catch {
    Write-Host "API not available: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   Will run in simulation mode" -ForegroundColor Gray
}

if ($apiAvailable) {
    # Real API key issuance
    Write-Host "`nIssuing API key via live API..." -ForegroundColor Cyan
    
    # Load admin token
    if (Test-Path $AdminTokenFile) {
        $adminToken = Get-Content $AdminTokenFile -Raw
        Write-Host "Admin token loaded" -ForegroundColor Green
        
        $headers = @{
            "x-admin-token" = $adminToken.Trim()
            "Content-Type" = "application/json"
        }
        
        $body = @{
            label = $Label
            rate_limit_per_min = $RateLimit
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/admin/keys/issue" -Method POST -Headers $headers -Body $body -TimeoutSec 15
            
            if ($response.plaintext_key) {
                Write-Host "API key issued successfully!" -ForegroundColor Green
                Write-Host "   Key ID: $($response.record.id)" -ForegroundColor White
                Write-Host "   Label: $($response.record.label)" -ForegroundColor White
                Write-Host "   Status: $($response.record.status)" -ForegroundColor White
                Write-Host "   Rate Limit: $($response.record.rate_limit_per_min)/min" -ForegroundColor White
                
                # Save to file
                $response.plaintext_key | Out-File -FilePath $OutputFile -NoNewline -Encoding utf8
                Write-Host "API key saved to: $OutputFile" -ForegroundColor Green
                
                # Test the key
                Write-Host "`nTesting issued API key..." -ForegroundColor Cyan
                try {
                    $testHeaders = @{ "x-api-key" = $response.plaintext_key }
                    $voices = Invoke-RestMethod -Uri "$BaseUrl/v1/voices" -Headers $testHeaders -TimeoutSec 10
                    Write-Host "API key test successful!" -ForegroundColor Green
                    Write-Host "   Available voices: $($voices.voices -join ', ')" -ForegroundColor White
                } catch {
                    Write-Host "API key test failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                
            } else {
                Write-Host "API key issuance failed: No plaintext key in response" -ForegroundColor Red
            }
        } catch {
            Write-Host "API key issuance failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "   Check admin token and Supabase configuration" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Admin token file not found: $AdminTokenFile" -ForegroundColor Red
        Write-Host "   Run setup-env.ps1 to generate admin token" -ForegroundColor Yellow
    }
    
} else {
    # Simulation mode
    Write-Host "`nSIMULATION MODE: API Key Issuance" -ForegroundColor Magenta
    Write-Host "   (API not available - showing expected behavior)" -ForegroundColor Gray
    
    # Generate mock API key
    $mockApiKey = -join ((1..32) | ForEach {[char][int]((65..90)+(97..122)+(48..57) | Get-Random)})
    $mockKeyId = [System.Guid]::NewGuid().ToString()
    
    Write-Host "`nExpected API Call:" -ForegroundColor Cyan
    Write-Host "   POST $BaseUrl/admin/keys/issue" -ForegroundColor White
    Write-Host "   Headers: x-admin-token: <ADMIN_TOKEN>" -ForegroundColor White
    Write-Host "   Body:" -ForegroundColor White
    Write-Host "   {" -ForegroundColor White
    Write-Host "     `"label`": `"$Label`"," -ForegroundColor White
    Write-Host "     `"rate_limit_per_min`": $RateLimit" -ForegroundColor White
    Write-Host "   }" -ForegroundColor White
    
    Write-Host "`nExpected Response:" -ForegroundColor Cyan
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
    $mockResponse | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor Gray
    
    # Save mock key
    $mockApiKey | Out-File -FilePath $OutputFile -NoNewline -Encoding utf8
    Write-Host "`nMock API key saved to: $OutputFile" -ForegroundColor Green
    Write-Host "   Key preview: $($mockApiKey.Substring(0,8))..." -ForegroundColor White
    Write-Host "   (For testing when API becomes available)" -ForegroundColor Yellow
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "   Admin token file: $AdminTokenFile" -ForegroundColor White
Write-Host "   API key file: $OutputFile" -ForegroundColor White
Write-Host "   Keep these files secure!" -ForegroundColor Yellow

Write-Host "`nNext Steps:" -ForegroundColor Cyan
if ($apiAvailable) {
    Write-Host "   • Test TTS generation with issued key" -ForegroundColor White
    Write-Host "   • Set up monitoring for key usage" -ForegroundColor White
} else {
    Write-Host "   • Install Docker and start TTS API locally" -ForegroundColor White
    Write-Host "   • Configure Supabase connection" -ForegroundColor White
    Write-Host "   • Re-run this script to issue real API key" -ForegroundColor White
}

Write-Host "`nAPI key issuance process completed!" -ForegroundColor Green