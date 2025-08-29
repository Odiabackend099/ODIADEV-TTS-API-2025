# scripts\one_click_run.ps1
param(
  [string]$EnvFile = ".\config\.env"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $EnvFile)) {
  Write-Host "Copying .env.example -> $EnvFile" -ForegroundColor Yellow
  Copy-Item ".\config\.env.example" $EnvFile
  Write-Host "Fill your values in $EnvFile and re-run." -ForegroundColor Yellow
  exit 1
}

# Build image and start compose
docker build -t odiadev/tts:local -f server/Dockerfile .
docker compose -f infra/docker-compose.yml up -d

Write-Host "`n✅ TTS API is running at http://localhost:8080" -ForegroundColor Green
Write-Host "Test with:"
Write-Host 'curl -X POST http://localhost:8080/v1/tts -H "x-api-key: TEST_KEY" -H "Content-Type: application/json" -d "{\"text\":\"Hello Naija!\",\"voice\":\"naija_female\",\"format\":\"mp3\"}" --output out.mp3'
