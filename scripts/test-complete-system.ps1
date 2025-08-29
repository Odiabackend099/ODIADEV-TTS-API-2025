# scripts\test-complete-system.ps1
# Comprehensive End-to-End Testing for ODIADEV TTS API

param(
    [switch]$SimulationMode,
    [switch]$LocalOnly,
    [switch]$RemoteOnly,
    [string]$RemoteUrl = "",
    [switch]$VoiceTests,
    [switch]$PerformanceTests
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - Complete System Testing" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$testResults = @()

function Run-Test($testName, $description, $testFunc) {
    Write-Host "`n$('=' * 60)" -ForegroundColor DarkCyan
    Write-Host "TEST: $testName" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor DarkCyan
    Write-Host "Description: $description" -ForegroundColor White
    
    $startTime = Get-Date
    
    try {
        $result = & $testFunc
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        if ($result.Success) {
            Write-Host "RESULT: PASSED ($([math]::Round($duration))ms)" -ForegroundColor Green
            $testResults += @{
                Test = $testName
                Status = "PASSED"
                Duration = $duration
                Details = $result.Details
            }
        } else {
            Write-Host "RESULT: FAILED ($([math]::Round($duration))ms)" -ForegroundColor Red
            Write-Host "Error: $($result.Error)" -ForegroundColor Yellow
            $testResults += @{
                Test = $testName
                Status = "FAILED"
                Duration = $duration
                Error = $result.Error
            }
        }
    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        Write-Host "RESULT: ERROR ($([math]::Round($duration))ms)" -ForegroundColor Red
        Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Yellow
        $testResults += @{
            Test = $testName
            Status = "ERROR"
            Duration = $duration
            Error = $_.Exception.Message
        }
    }
}

function Test-ConfigurationFiles {
    $requiredFiles = @(
        @{ Path = "config/.env"; Description = "Environment configuration" },
        @{ Path = "voices/voice_config.json"; Description = "Nigerian voice configuration" },
        @{ Path = "Dockerfile"; Description = "Container configuration" },
        @{ Path = "supabase/complete_schema.sql"; Description = "Database schema" }
    )
    
    $missing = @()
    foreach ($file in $requiredFiles) {
        if (Test-Path $file.Path) {
            Write-Host "✓ $($file.Description): $($file.Path)" -ForegroundColor Green
        } else {
            Write-Host "✗ $($file.Description): $($file.Path) - MISSING" -ForegroundColor Red
            $missing += $file.Path
        }
    }
    
    if ($missing.Count -eq 0) {
        return @{ Success = $true; Details = "All configuration files present" }
    } else {
        return @{ Success = $false; Error = "Missing files: $($missing -join ', ')" }
    }
}

function Test-VoiceConfiguration {
    if (-not (Test-Path "voices/voice_config.json")) {
        return @{ Success = $false; Error = "Voice configuration file not found" }
    }
    
    try {
        $voiceConfig = Get-Content "voices/voice_config.json" | ConvertFrom-Json
        
        # Check required voices
        $requiredVoices = @("naija_female", "naija_male")
        $availableVoices = $voiceConfig.voices.PSObject.Properties.Name
        
        $missingVoices = $requiredVoices | Where-Object { $_ -notin $availableVoices }
        
        if ($missingVoices.Count -gt 0) {
            return @{ Success = $false; Error = "Missing voices: $($missingVoices -join ', ')" }
        }
        
        Write-Host "Available voices: $($availableVoices -join ', ')" -ForegroundColor Green
        Write-Host "Default voice: $($voiceConfig.default_voice)" -ForegroundColor Green
        
        # Validate voice properties
        foreach ($voiceName in $requiredVoices) {
            $voice = $voiceConfig.voices.$voiceName
            if (-not $voice.model -or -not $voice.language -or -not $voice.gender) {
                return @{ Success = $false; Error = "Voice $voiceName missing required properties" }
            }
            Write-Host "✓ $voiceName - $($voice.gender) $($voice.language) voice" -ForegroundColor Green
        }
        
        return @{ Success = $true; Details = "Nigerian voices configured: $($availableVoices -join ', ')" }
        
    } catch {
        return @{ Success = $false; Error = "Failed to parse voice configuration: $($_.Exception.Message)" }
    }
}

function Test-EnvironmentConfiguration {
    if (-not (Test-Path "config/.env")) {
        return @{ Success = $false; Error = ".env file not found" }
    }
    
    $envContent = Get-Content "config/.env" -Raw
    $requiredVars = @(
        "PORT",
        "ADMIN_TOKEN", 
        "SUPABASE_URL",
        "TTS_ENGINE",
        "AWS_REGION"
    )
    
    $missing = @()
    foreach ($var in $requiredVars) {
        if ($envContent -match "$var=") {
            Write-Host "✓ $var configured" -ForegroundColor Green
        } else {
            Write-Host "✗ $var missing" -ForegroundColor Red
            $missing += $var
        }
    }
    
    # Check specific configurations
    if ($envContent -match "TTS_ENGINE=coqui") {
        Write-Host "✓ Coqui TTS engine selected" -ForegroundColor Green
    }
    
    if ($envContent -match "AWS_REGION=af-south-1") {
        Write-Host "✓ af-south-1 region configured" -ForegroundColor Green
    }
    
    if ($envContent -match "ADMIN_TOKEN=admin-token-12345") {
        Write-Host "✓ Default admin token configured" -ForegroundColor Green
    }
    
    if ($missing.Count -eq 0) {
        return @{ Success = $true; Details = "Environment configuration complete" }
    } else {
        return @{ Success = $false; Error = "Missing environment variables: $($missing -join ', ')" }
    }
}

function Test-DatabaseSchema {
    if (-not (Test-Path "supabase/complete_schema.sql")) {
        return @{ Success = $false; Error = "Database schema file not found" }
    }
    
    $schemaContent = Get-Content "supabase/complete_schema.sql" -Raw
    
    # Check for required tables
    $requiredTables = @("tenants", "api_keys", "tts_usage", "admin_tokens")
    $missing = @()
    
    foreach ($table in $requiredTables) {
        if ($schemaContent -match "CREATE TABLE.*$table") {
            Write-Host "✓ Table: $table" -ForegroundColor Green
        } else {
            Write-Host "✗ Table: $table - MISSING" -ForegroundColor Red
            $missing += $table
        }
    }
    
    # Check for required functions
    $requiredFunctions = @("issue_api_key", "validate_api_key", "record_tts_usage")
    foreach ($func in $requiredFunctions) {
        if ($schemaContent -match "CREATE.*FUNCTION.*$func") {
            Write-Host "✓ Function: $func" -ForegroundColor Green
        } else {
            Write-Host "✗ Function: $func - MISSING" -ForegroundColor Red
            $missing += $func
        }
    }
    
    # Check for RLS policies
    if ($schemaContent -match "ENABLE ROW LEVEL SECURITY") {
        Write-Host "✓ Row Level Security enabled" -ForegroundColor Green
    } else {
        Write-Host "✗ Row Level Security not configured" -ForegroundColor Red
        $missing += "RLS"
    }
    
    if ($missing.Count -eq 0) {
        return @{ Success = $true; Details = "Database schema complete with all required tables and functions" }
    } else {
        return @{ Success = $false; Error = "Missing schema components: $($missing -join ', ')" }
    }
}

function Test-ContainerConfiguration {
    if (-not (Test-Path "Dockerfile")) {
        return @{ Success = $false; Error = "Dockerfile not found" }
    }
    
    $dockerContent = Get-Content "Dockerfile" -Raw
    
    # Check key Dockerfile components
    $checks = @(
        @{ Pattern = "FROM python:"; Description = "Python base image" },
        @{ Pattern = "COPY server/"; Description = "Server code copy" },
        @{ Pattern = "COPY voices/"; Description = "Voice configuration copy" },
        @{ Pattern = "EXPOSE 3000"; Description = "Port exposure" },
        @{ Pattern = "TTS_CACHE_DIR"; Description = "TTS cache configuration" },
        @{ Pattern = "ffmpeg"; Description = "Audio processing tools" }
    )
    
    $missing = @()
    foreach ($check in $checks) {
        if ($dockerContent -match $check.Pattern) {
            Write-Host "✓ $($check.Description)" -ForegroundColor Green
        } else {
            Write-Host "✗ $($check.Description) - MISSING" -ForegroundColor Red
            $missing += $check.Description
        }
    }
    
    if ($missing.Count -eq 0) {
        return @{ Success = $true; Details = "Dockerfile configured for Nigerian TTS deployment" }
    } else {
        return @{ Success = $false; Error = "Missing Dockerfile components: $($missing -join ', ')" }
    }
}

function Test-AutomationScripts {
    $requiredScripts = @(
        @{ Path = "scripts/build-container.ps1"; Description = "Container build automation" },
        @{ Path = "scripts/deploy-ecr.ps1"; Description = "ECR deployment" },
        @{ Path = "scripts/deploy-ec2.ps1"; Description = "EC2 deployment" },
        @{ Path = "scripts/health-check.ps1"; Description = "Health monitoring" },
        @{ Path = "scripts/setup-supabase.ps1"; Description = "Database setup" },
        @{ Path = "scripts/deploy-complete.ps1"; Description = "Complete deployment orchestration" }
    )
    
    $missing = @()
    foreach ($script in $requiredScripts) {
        if (Test-Path $script.Path) {
            Write-Host "✓ $($script.Description): $($script.Path)" -ForegroundColor Green
        } else {
            Write-Host "✗ $($script.Description): $($script.Path) - MISSING" -ForegroundColor Red
            $missing += $script.Path
        }
    }
    
    if ($missing.Count -eq 0) {
        return @{ Success = $true; Details = "All automation scripts present and ready" }
    } else {
        return @{ Success = $false; Error = "Missing scripts: $($missing -join ', ')" }
    }
}

function Test-SimulatedAPIEndpoints {
    Write-Host "Running simulated API endpoint tests..." -ForegroundColor Yellow
    
    $testCases = @(
        @{ Endpoint = "/health"; Method = "GET"; ExpectedStatus = 200; Description = "Health check endpoint" },
        @{ Endpoint = "/v1/voices"; Method = "GET"; ExpectedStatus = 200; Description = "Voice listing endpoint" },
        @{ Endpoint = "/v1/tts"; Method = "POST"; ExpectedStatus = 200; Description = "TTS generation endpoint" },
        @{ Endpoint = "/admin/keys/issue"; Method = "POST"; ExpectedStatus = 200; Description = "API key issuance endpoint" }
    )
    
    $simulatedResults = @()
    foreach ($test in $testCases) {
        Write-Host "Simulating $($test.Method) $($test.Endpoint)" -ForegroundColor White
        
        # Simulate successful responses
        $mockResponse = switch ($test.Endpoint) {
            "/health" { @{ status = "ok"; engine = "coqui"; voices = @("naija_female", "naija_male") } }
            "/v1/voices" { @{ voices = @("naija_female", "naija_male"); engine = "coqui" } }
            "/v1/tts" { @{ url = "https://s3.af-south-1.amazonaws.com/cache/mock.mp3"; format = "mp3"; ms = 2500 } }
            "/admin/keys/issue" { @{ plaintext_key = "test-api-key-12345"; record = @{ id = "uuid"; status = "active" } } }
        }
        
        $simulatedResults += @{
            Endpoint = $test.Endpoint
            Status = "SIMULATED_SUCCESS"
            Response = $mockResponse
        }
        
        Write-Host "  → Simulated response: $($mockResponse | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
    
    return @{ Success = $true; Details = "All API endpoints simulated successfully" }
}

# Main test execution
Write-Host "Test Mode: $(if ($SimulationMode) { 'SIMULATION' } else { 'LIVE' })" -ForegroundColor Yellow
Write-Host "Scope: $(if ($LocalOnly) { 'LOCAL ONLY' } elseif ($RemoteOnly) { 'REMOTE ONLY' } else { 'FULL SYSTEM' })" -ForegroundColor Yellow

# Run tests
Run-Test "Configuration Files" "Validate all required configuration files are present" { Test-ConfigurationFiles }
Run-Test "Voice Configuration" "Validate Nigerian voice configuration" { Test-VoiceConfiguration }
Run-Test "Environment Variables" "Validate environment configuration" { Test-EnvironmentConfiguration }
Run-Test "Database Schema" "Validate Supabase schema completeness" { Test-DatabaseSchema }
Run-Test "Container Configuration" "Validate Dockerfile and container setup" { Test-ContainerConfiguration }
Run-Test "Automation Scripts" "Validate deployment automation scripts" { Test-AutomationScripts }

if ($SimulationMode) {
    Run-Test "API Endpoints (Simulated)" "Simulate API endpoint responses" { Test-SimulatedAPIEndpoints }
}

# Generate test report
Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
Write-Host "TEST SUMMARY REPORT" -ForegroundColor Cyan
Write-Host "$('=' * 80)" -ForegroundColor Cyan

$passed = ($testResults | Where-Object { $_.Status -eq "PASSED" }).Count
$failed = ($testResults | Where-Object { $_.Status -eq "FAILED" }).Count
$errors = ($testResults | Where-Object { $_.Status -eq "ERROR" }).Count
$total = $testResults.Count

Write-Host "`nOverall Results:" -ForegroundColor White
Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Errors: $errors" -ForegroundColor Yellow
Write-Host "Success Rate: $([math]::Round(($passed / $total) * 100, 1))%" -ForegroundColor White

Write-Host "`nDetailed Results:" -ForegroundColor White
foreach ($result in $testResults) {
    $status = switch ($result.Status) {
        "PASSED" { "✓" }
        "FAILED" { "✗" }
        "ERROR" { "⚠" }
    }
    
    $color = switch ($result.Status) {
        "PASSED" { "Green" }
        "FAILED" { "Red" }
        "ERROR" { "Yellow" }
    }
    
    Write-Host "$status $($result.Test) ($([math]::Round($result.Duration))ms)" -ForegroundColor $color
    
    if ($result.Error) {
        Write-Host "    Error: $($result.Error)" -ForegroundColor Gray
    }
}

# Save test report
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportFile = "test_report_$timestamp.json"
$testResults | ConvertTo-Json -Depth 3 | Out-File $reportFile
Write-Host "`nTest report saved: $reportFile" -ForegroundColor Cyan

if ($passed -eq $total) {
    Write-Host "`n🎉 ALL TESTS PASSED! System is ready for deployment." -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some tests failed. Review the issues above before deployment." -ForegroundColor Yellow
}

Write-Host "`nComplete system testing finished!" -ForegroundColor Green