# scripts\setup-env.ps1
# ODIADEV TTS API Environment Setup Script
param(
    [string]$SupabaseUrl = "",
    [string]$SupabaseServiceKey = "",
    [string]$AwsAccessKey = "",
    [string]$AwsSecretKey = "",
    [string]$S3Bucket = "odiadev-tts-artifacts-af-south-1"
)

$ErrorActionPreference = "Stop"

Write-Host "ODIADEV TTS API Environment Setup" -ForegroundColor Cyan

# Create secrets directory if not exists
if (!(Test-Path "secrets")) {
    New-Item -ItemType Directory -Name "secrets" | Out-Null
    Write-Host "Created secrets directory" -ForegroundColor Green
}

# Load current admin token or generate new one
$adminTokenFile = "secrets\ADMIN_TOKEN.txt"
if (Test-Path $adminTokenFile) {
    $adminToken = Get-Content $adminTokenFile -Raw
    Write-Host "Using existing admin token" -ForegroundColor Green
} else {
    $adminToken = -join ((1..32) | ForEach {[char][int]((65..90)+(97..122)+(48..57) | Get-Random)})
    $adminToken | Out-File -FilePath $adminTokenFile -NoNewline -Encoding utf8
    Write-Host "Generated new admin token" -ForegroundColor Green
}

# Update .env file with actual admin token
$envPath = "odiadev-tts-api\config\.env"
if (Test-Path $envPath) {
    $envContent = Get-Content $envPath
    $envContent = $envContent -replace "ADMIN_TOKEN=CONFIGURED_SECURE_TOKEN", "ADMIN_TOKEN=$adminToken"
    
    if ($SupabaseUrl) {
        $envContent = $envContent -replace "SUPABASE_URL=.*", "SUPABASE_URL=$SupabaseUrl"
    }
    if ($SupabaseServiceKey) {
        $envContent = $envContent -replace "SUPABASE_SERVICE_ROLE_KEY=.*", "SUPABASE_SERVICE_ROLE_KEY=$SupabaseServiceKey"
    }
    if ($AwsAccessKey) {
        $envContent = $envContent -replace "AWS_ACCESS_KEY_ID=.*", "AWS_ACCESS_KEY_ID=$AwsAccessKey"
    }
    if ($AwsSecretKey) {
        $envContent = $envContent -replace "AWS_SECRET_ACCESS_KEY=.*", "AWS_SECRET_ACCESS_KEY=$AwsSecretKey"
    }
    if ($S3Bucket) {
        $envContent = $envContent -replace "S3_BUCKET_TTS=.*", "S3_BUCKET_TTS=$S3Bucket"
    }
    
    $envContent | Set-Content $envPath
    Write-Host "Updated .env configuration" -ForegroundColor Green
} else {
    Write-Host ".env file not found at $envPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Admin Token: STORED_IN_secrets\ADMIN_TOKEN.txt" -ForegroundColor Yellow
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure Supabase URL and Service Role Key in .env" -ForegroundColor White
Write-Host "  2. Set up AWS credentials (CLI profile or IAM role preferred)" -ForegroundColor White
Write-Host "  3. Run: docker build -t odiadev/tts:local -f server/Dockerfile ." -ForegroundColor White
Write-Host "  4. Run: docker compose -f infra/docker-compose.yml up -d" -ForegroundColor White
Write-Host ""