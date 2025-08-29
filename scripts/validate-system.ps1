# scripts\validate-system.ps1
# Simple System Validation for ODIADEV TTS API

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - System Validation" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

$tests = @()

# Test 1: Configuration Files
Write-Host "`nTesting configuration files..." -ForegroundColor Yellow
$configFiles = @(
    "config/.env",
    "voices/voice_config.json", 
    "Dockerfile",
    "supabase/complete_schema.sql"
)

$configResult = $true
foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "OK: $file" -ForegroundColor Green
    } else {
        Write-Host "MISSING: $file" -ForegroundColor Red
        $configResult = $false
    }
}
$tests += @{ Name = "Configuration Files"; Result = $configResult }

# Test 2: Voice Configuration
Write-Host "`nTesting voice configuration..." -ForegroundColor Yellow
if (Test-Path "voices/voice_config.json") {
    try {
        $voices = Get-Content "voices/voice_config.json" | ConvertFrom-Json
        if ($voices.voices.naija_female -and $voices.voices.naija_male) {
            Write-Host "OK: Nigerian voices configured" -ForegroundColor Green
            Write-Host "  - naija_female: $($voices.voices.naija_female.description)" -ForegroundColor White
            Write-Host "  - naija_male: $($voices.voices.naija_male.description)" -ForegroundColor White
            $voiceResult = $true
        } else {
            Write-Host "FAILED: Missing Nigerian voices" -ForegroundColor Red
            $voiceResult = $false
        }
    } catch {
        Write-Host "FAILED: Invalid voice configuration" -ForegroundColor Red
        $voiceResult = $false
    }
} else {
    Write-Host "FAILED: Voice configuration missing" -ForegroundColor Red
    $voiceResult = $false
}
$tests += @{ Name = "Voice Configuration"; Result = $voiceResult }

# Test 3: Environment Variables
Write-Host "`nTesting environment configuration..." -ForegroundColor Yellow
if (Test-Path "config/.env") {
    $envContent = Get-Content "config/.env" -Raw
    $envVars = @("PORT", "ADMIN_TOKEN", "SUPABASE_URL", "TTS_ENGINE", "AWS_REGION")
    $envResult = $true
    
    foreach ($var in $envVars) {
        if ($envContent -match "$var=") {
            Write-Host "OK: $var configured" -ForegroundColor Green
        } else {
            Write-Host "MISSING: $var" -ForegroundColor Red
            $envResult = $false
        }
    }
} else {
    Write-Host "FAILED: .env file missing" -ForegroundColor Red
    $envResult = $false
}
$tests += @{ Name = "Environment Variables"; Result = $envResult }

# Test 4: Database Schema
Write-Host "`nTesting database schema..." -ForegroundColor Yellow
if (Test-Path "supabase/complete_schema.sql") {
    $schema = Get-Content "supabase/complete_schema.sql" -Raw
    $tables = @("tenants", "api_keys", "tts_usage", "admin_tokens")
    $schemaResult = $true
    
    foreach ($table in $tables) {
        if ($schema -match "CREATE TABLE.*$table") {
            Write-Host "OK: Table $table defined" -ForegroundColor Green
        } else {
            Write-Host "MISSING: Table $table" -ForegroundColor Red
            $schemaResult = $false
        }
    }
    
    if ($schema -match "issue_api_key") {
        Write-Host "OK: API key functions defined" -ForegroundColor Green
    } else {
        Write-Host "MISSING: API key functions" -ForegroundColor Red
        $schemaResult = $false
    }
} else {
    Write-Host "FAILED: Database schema missing" -ForegroundColor Red
    $schemaResult = $false
}
$tests += @{ Name = "Database Schema"; Result = $schemaResult }

# Test 5: Automation Scripts
Write-Host "`nTesting automation scripts..." -ForegroundColor Yellow
$scripts = @(
    "scripts/build-container.ps1",
    "scripts/deploy-ecr.ps1", 
    "scripts/deploy-ec2.ps1",
    "scripts/health-check.ps1",
    "scripts/setup-supabase.ps1",
    "scripts/deploy-complete.ps1"
)

$scriptResult = $true
foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Host "OK: $script" -ForegroundColor Green
    } else {
        Write-Host "MISSING: $script" -ForegroundColor Red
        $scriptResult = $false
    }
}
$tests += @{ Name = "Automation Scripts"; Result = $scriptResult }

# Test 6: Container Configuration
Write-Host "`nTesting container configuration..." -ForegroundColor Yellow
if (Test-Path "Dockerfile") {
    $dockerfile = Get-Content "Dockerfile" -Raw
    $containerChecks = @(
        @{ Pattern = "FROM python"; Description = "Python base image" },
        @{ Pattern = "COPY server/"; Description = "Server code" },
        @{ Pattern = "COPY voices/"; Description = "Voice config" },
        @{ Pattern = "EXPOSE 3000"; Description = "Port exposure" }
    )
    
    $containerResult = $true
    foreach ($check in $containerChecks) {
        if ($dockerfile -match $check.Pattern) {
            Write-Host "OK: $($check.Description)" -ForegroundColor Green
        } else {
            Write-Host "MISSING: $($check.Description)" -ForegroundColor Red
            $containerResult = $false
        }
    }
} else {
    Write-Host "FAILED: Dockerfile missing" -ForegroundColor Red
    $containerResult = $false
}
$tests += @{ Name = "Container Configuration"; Result = $containerResult }

# Results Summary
Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$passed = 0
$total = $tests.Count

foreach ($test in $tests) {
    if ($test.Result) {
        Write-Host "PASS: $($test.Name)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAIL: $($test.Name)" -ForegroundColor Red
    }
}

Write-Host "`nOverall Results:" -ForegroundColor White
Write-Host "Tests Passed: $passed / $total" -ForegroundColor White
Write-Host "Success Rate: $([math]::Round(($passed / $total) * 100, 1))%" -ForegroundColor White

if ($passed -eq $total) {
    Write-Host "`nSYSTEM VALIDATION: PASSED" -ForegroundColor Green
    Write-Host "All components are ready for deployment!" -ForegroundColor White
} else {
    Write-Host "`nSYSTEM VALIDATION: FAILED" -ForegroundColor Red
    Write-Host "Fix the issues above before deployment." -ForegroundColor White
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Install Docker Desktop" -ForegroundColor White
Write-Host "2. Install AWS CLI" -ForegroundColor White
Write-Host "3. Setup Supabase project" -ForegroundColor White
Write-Host "4. Run: .\scripts\deploy-complete.ps1" -ForegroundColor White

Write-Host "`nValidation completed!" -ForegroundColor Green