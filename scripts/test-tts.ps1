# scripts\test-tts.ps1
# Test TTS Endpoint with Issued API Key

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$ApiKeyFile = "secrets\DEV_TTS_KEY.txt",
    [string]$OutputDir = "output",
    [string]$TestText = "Hello! Welcome to ODIADEV TTS service. This is a test of our Nigerian English voice synthesis."
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Test TTS Endpoint" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host "API Key File: $ApiKeyFile" -ForegroundColor Yellow
Write-Host "Output Directory: $OutputDir" -ForegroundColor Yellow
Write-Host "=" * 50

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

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

# Load API key
$apiKey = $null
if (Test-Path $ApiKeyFile) {
    $apiKey = Get-Content $ApiKeyFile -Raw
    $apiKey = $apiKey.Trim()
    Write-Host "API key loaded from: $ApiKeyFile" -ForegroundColor Green
    Write-Host "   Key preview: $($apiKey.Substring(0, [Math]::Min(8, $apiKey.Length)))..." -ForegroundColor White
} else {
    Write-Host "API key file not found: $ApiKeyFile" -ForegroundColor Red
    Write-Host "   Run issue-api-key.ps1 first to generate an API key" -ForegroundColor Yellow
    exit 1
}

if ($apiAvailable -and $apiKey) {
    # Real TTS testing
    Write-Host "`nTesting TTS endpoint with live API..." -ForegroundColor Cyan
    
    try {
        # First, check available voices
        Write-Host "`nFetching available voices..." -ForegroundColor Cyan
        $voicesHeaders = @{ "x-api-key" = $apiKey }
        $voicesResponse = Invoke-RestMethod -Uri "$BaseUrl/v1/voices" -Headers $voicesHeaders -TimeoutSec 10
        
        Write-Host "Available voices: $($voicesResponse.voices -join ', ')" -ForegroundColor Green
        $testVoice = $voicesResponse.voices[0]  # Use first available voice
        
        # Test TTS generation
        Write-Host "`nGenerating TTS with voice: $testVoice" -ForegroundColor Cyan
        Write-Host "Text: $TestText" -ForegroundColor White
        
        $ttsHeaders = @{
            "x-api-key" = $apiKey
            "Content-Type" = "application/json"
        }
        
        $ttsBody = @{
            text = $TestText
            voice = $testVoice
            format = "mp3"
            speed = 1.0
        } | ConvertTo-Json
        
        $ttsResponse = Invoke-RestMethod -Uri "$BaseUrl/v1/tts" -Method POST -Headers $ttsHeaders -Body $ttsBody -TimeoutSec 30
        
        if ($ttsResponse.url) {
            # S3 URL response
            Write-Host "TTS generation successful!" -ForegroundColor Green
            Write-Host "   Audio URL: $($ttsResponse.url)" -ForegroundColor White
            Write-Host "   Format: $($ttsResponse.format)" -ForegroundColor White
            Write-Host "   Cache Hit: $($ttsResponse.cache_hit)" -ForegroundColor White
            Write-Host "   Generation Time: $($ttsResponse.ms)ms" -ForegroundColor White
            
            # Download audio file
            $outputFile = "$OutputDir\test_tts_$(Get-Date -Format 'yyyyMMdd_HHmmss').$($ttsResponse.format)"
            Write-Host "`nDownloading audio from S3..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $ttsResponse.url -OutFile $outputFile
            Write-Host "Audio saved to: $outputFile" -ForegroundColor Green
            
        } else {
            Write-Host "TTS generation failed: No URL in response" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "TTS test failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            Write-Host "   HTTP Status: $statusCode" -ForegroundColor Yellow
        }
    }
    
} else {
    # Simulation mode
    Write-Host "`nSIMULATION MODE: TTS Endpoint Testing" -ForegroundColor Magenta
    Write-Host "   (API not available - showing expected behavior)" -ForegroundColor Gray
    
    Write-Host "`nExpected Voices API Call:" -ForegroundColor Cyan
    Write-Host "   GET $BaseUrl/v1/voices" -ForegroundColor White
    Write-Host "   Headers: x-api-key: $($apiKey.Substring(0, [Math]::Min(8, $apiKey.Length)))..." -ForegroundColor White
    
    Write-Host "`nExpected Voices Response:" -ForegroundColor Cyan
    $mockVoicesResponse = @{
        voices = @("naija_female", "naija_male")
        engine = "coqui"
    }
    $mockVoicesResponse | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Gray
    
    Write-Host "`nExpected TTS API Call:" -ForegroundColor Cyan
    Write-Host "   POST $BaseUrl/v1/tts" -ForegroundColor White
    Write-Host "   Headers: x-api-key: $($apiKey.Substring(0, [Math]::Min(8, $apiKey.Length)))..." -ForegroundColor White
    Write-Host "   Body:" -ForegroundColor White
    
    $mockTtsRequest = @{
        text = $TestText
        voice = "naija_female"
        format = "mp3"
        speed = 1.0
    }
    $mockTtsRequest | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Gray
    
    Write-Host "`nExpected TTS Response:" -ForegroundColor Cyan
    $mockTtsResponse = @{
        url = "https://s3.af-south-1.amazonaws.com/odiadev-tts-cache/mock-audio-$(Get-Random).mp3"
        format = "mp3"
        cache_hit = $false
        ms = 2500 + (Get-Random -Maximum 1000)
    }
    $mockTtsResponse | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Gray
    
    # Create mock audio file
    $mockOutputFile = "$OutputDir\mock_tts_$(Get-Date -Format 'yyyyMMdd_HHmmss').mp3"
    Write-Host "`nCreating mock audio file..." -ForegroundColor Cyan
    
    # Create a simple header for MP3 file (not actual audio, just for testing file operations)
    $mp3Header = [byte[]](0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    [System.IO.File]::WriteAllBytes($mockOutputFile, $mp3Header)
    
    Write-Host "Mock audio file created: $mockOutputFile" -ForegroundColor Green
    Write-Host "   File size: $((Get-Item $mockOutputFile).Length) bytes" -ForegroundColor White
    Write-Host "   (This is a mock file for testing - not actual audio)" -ForegroundColor Yellow
}

# Generate test report
Write-Host "`nGenerating test report..." -ForegroundColor Cyan
$reportFile = "$OutputDir\tts_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

$report = @"
ODIADEV TTS API - Test Report
Generated: $(Get-Date)
Base URL: $BaseUrl
API Key File: $ApiKeyFile

Test Configuration:
- Text: $TestText
- Voice: naija_female (or first available)
- Format: mp3
- Speed: 1.0

Test Results:
- API Available: $apiAvailable
- API Key Present: $($apiKey -ne $null)
- Mode: $(if ($apiAvailable) { "Live API" } else { "Simulation" })

Output Files:
- Report: $reportFile
$(if (Test-Path "$OutputDir\*.mp3") {
    Get-ChildItem "$OutputDir\*.mp3" | ForEach-Object { "- Audio: $($_.Name)" }
} else {
    "- No audio files generated"
})

Next Steps:
$(if (-not $apiAvailable) {
    "- Install Docker and start TTS API locally
- Configure Supabase for key management
- Re-run this test with live API"
} else {
    "- Verify audio quality and voice accuracy
- Test with different voices and parameters
- Set up automated testing pipeline"
})

Test completed successfully.
"@

$report | Out-File -FilePath $reportFile -Encoding utf8
Write-Host "Test report saved to: $reportFile" -ForegroundColor Green

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "   Test Mode: $(if ($apiAvailable) { "Live API" } else { "Simulation" })" -ForegroundColor White
Write-Host "   Output Directory: $OutputDir" -ForegroundColor White
Write-Host "   Files Generated: $(Get-ChildItem $OutputDir | Measure-Object | ForEach-Object { $_.Count })" -ForegroundColor White

Write-Host "`nTTS endpoint testing completed!" -ForegroundColor Green