# ODIADEV TTS API - TestSprite Setup Script
# This script retrieves the API key and sets up TestSprite configuration

Write-Host "🚀 Setting up TestSprite for ODIADEV TTS API" -ForegroundColor Green
Write-Host "=" * 50

# First, let's test the EC2 endpoint to see if it's accessible
$SERVER = "13.247.217.147"
Write-Host "🌐 Testing EC2 endpoint accessibility..." -ForegroundColor Yellow

try {
    $healthResponse = Invoke-WebRequest "http://$SERVER/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Server is accessible!" -ForegroundColor Green
    Write-Host "Status: $($healthResponse.StatusCode)"
    
    # Parse the health response to get service info
    $healthData = $healthResponse.Content | ConvertFrom-Json
    Write-Host "Service: $($healthData.service)"
    Write-Host "Status: $($healthData.status)"
    Write-Host "Version: $($healthData.version)"
} catch {
    Write-Host "❌ Cannot reach server: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please ensure your EC2 instance is running and accessible."
    exit 1
}

Write-Host ""
Write-Host "🔑 API Key Configuration" -ForegroundColor Yellow
Write-Host "We need an API key to test the /v1/tts endpoint."
Write-Host "You can either:"
Write-Host "1. Provide an existing API key"
Write-Host "2. We'll use a placeholder and you can update it later"
Write-Host ""

# For now, we'll create the config with a placeholder
# User can update this with their actual API key
$API_KEY_PLACEHOLDER = "YOUR_API_KEY_HERE"

Write-Host "📝 Creating TestSprite configuration..." -ForegroundColor Yellow

# Create the TestSprite runtime config
$configContent = @{
    target = @{
        name = "ODIADEV TTS API"
        baseUrl = "http://$SERVER"
        headers = @{
            "x-api-key" = $API_KEY_PLACEHOLDER
        }
        timeoutMs = 30000
    }
    auth = @{
        type = "none"
    }
    spec = "testsprite_tests/PRD.md"
    port = $null
} | ConvertTo-Json -Depth 10

$configContent | Set-Content "testsprite_tests\config.json" -Encoding UTF8

Write-Host "✅ TestSprite configuration created!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. If you have an API key, edit testsprite_tests\config.json"
Write-Host "2. Replace 'YOUR_API_KEY_HERE' with your actual key"
Write-Host "3. Run TestSprite to execute the tests"
Write-Host ""
Write-Host "🔧 To get an API key (if needed):" -ForegroundColor Yellow
Write-Host "Run your deployment script and look for the API_KEY output"
Write-Host ""

# Display the current config for verification
Write-Host "📄 Current configuration:" -ForegroundColor Cyan
Get-Content "testsprite_tests\config.json" | Write-Host

Write-Host ""
Write-Host "🎯 Ready for TestSprite testing!" -ForegroundColor Green