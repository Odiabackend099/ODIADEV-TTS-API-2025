param(
  [string]$ServerIP    = "13.247.217.147",
  [string]$PemPath     = "$HOME\Downloads\odiadev-ec2.pem",
  [string]$ProjectDir  = "$HOME\Downloads\odiadev-tts-api",
  [string]$ZipPath     = "$HOME\Downloads\odiadev-tts-api.zip",
  [string]$Voice       = "naija_female",
  [string]$SampleText  = "Hello Naija, this is ODIADEV TTS live!",
  [string]$LocalOutDir = "$HOME\Downloads\odiadev-tts-api\output"
)

$ErrorActionPreference = "Stop"
Write-Host "`n=== ODIADEV • One-Click EC2 TTS Deploy ===`n" -ForegroundColor Cyan

function Need($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required command '$cmd' not found in PATH."
  }
}
Need "ssh"; Need "scp"; Need "Compress-Archive"

if (-not (Test-Path $PemPath))    { throw "PEM file not found: $PemPath" }
if (-not (Test-Path $ProjectDir)) { throw "Project folder not found: $ProjectDir" }

# Restrict key perms on Windows
icacls $PemPath /inheritance:r | Out-Null
icacls $PemPath /grant:r "$($env:UserName):(R)" | Out-Null

# Zip project
Write-Host "Zipping project → $ZipPath" -ForegroundColor Yellow
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $ProjectDir '*') -DestinationPath $ZipPath -Force

# Accept host key once (no yes/no prompt)
Write-Host "Warming SSH known_hosts..." -ForegroundColor Yellow
ssh -i $PemPath -o StrictHostKeyChecking=accept-new "ubuntu@$ServerIP" "echo ok" | Out-Null

# Upload
Write-Host "Uploading zip to server..." -ForegroundColor Yellow
scp -i $PemPath "$ZipPath" "ubuntu@${ServerIP}:~/" | Out-Null

# Remote build & run (single-quoted here-string so PS doesn’t expand $ or $(...) )
$remoteScript = @'
set -e

sudo apt-get update -y
sudo apt-get install -y unzip jq openssl

cd ~
rm -rf ~/odiadev-tts-api
mkdir -p ~/odiadev-tts-api
unzip -o ~/odiadev-tts-api.zip -d ~/odiadev-tts-api > /dev/null
cd ~/odiadev-tts-api

cp -f config/.env.example config/.env

ADMIN_TOKEN=$(openssl rand -hex 24)
sed -i "s/^ADMIN_TOKEN=.*/ADMIN_TOKEN=$ADMIN_TOKEN/" config/.env
sed -i "s/^AWS_REGION=.*/AWS_REGION=af-south-1/"     config/.env
sed -i "s/^TTS_ENGINE=.*/TTS_ENGINE=coqui/"          config/.env

sudo docker rm -f tts-holding >/dev/null 2>&1 || true
sudo docker build -t odiadev/tts:local -f server/Dockerfile .
sudo docker rm -f odiadev-tts >/dev/null 2>&1 || true
sudo docker run -d --name odiadev-tts --env-file config/.env -p 127.0.0.1:3000:3000 odiadev/tts:local

# wait for health
for i in {1..60}; do
  curl -sf http://127.0.0.1:3000/health >/dev/null && break
  sleep 2
done

# issue key
curl -s -X POST http://127.0.0.1:3000/admin/keys/issue \
  -H "x-admin-token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"first-key"}' > key.json

API_KEY=$(jq -r '.plaintext_key' key.json)
echo "$API_KEY" > DEV_TTS_KEY.txt
chmod 600 DEV_TTS_KEY.txt

# synthesize sample mp3
curl -s -X POST http://127.0.0.1:3000/v1/tts \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{"text":"__SAMPLETEXT__","voice":"__VOICE__","format":"mp3"}' \
  --output out.mp3

[ -s out.mp3 ] && echo READY || (echo FAIL; exit 2)
'@

# inject SampleText/Voice safely
$remoteScript = $remoteScript.Replace('__SAMPLETEXT__', ($SampleText.Replace('"','\"')))
$remoteScript = $remoteScript.Replace('__VOICE__', $Voice)

Write-Host "Building & starting TTS API on the server..." -ForegroundColor Yellow
$remoteResult = $remoteScript | ssh -i $PemPath "ubuntu@$ServerIP" "bash -s"
if (-not $remoteResult -or ($remoteResult -notmatch 'READY')) {
  throw "Remote build/run failed. Output:`n$remoteResult"
}
Write-Host "Server reports: READY" -ForegroundColor Green

# Download artifacts
New-Item -ItemType Directory -Force -Path $LocalOutDir | Out-Null
$localMp3 = Join-Path $LocalOutDir 'out.mp3'
$localKey = Join-Path $LocalOutDir 'DEV_TTS_KEY.txt'

Write-Host "Downloading MP3 and API key..." -ForegroundColor Yellow
scp -i $PemPath "ubuntu@${ServerIP}:~/odiadev-tts-api/out.mp3"      "$localMp3" | Out-Null
scp -i $PemPath "ubuntu@${ServerIP}:~/odiadev-tts-api/DEV_TTS_KEY.txt" "$localKey" | Out-Null

Write-Host "`n✅ Done!" -ForegroundColor Green
Write-Host ("MP3 saved to:  " + (Resolve-Path $localMp3))
Write-Host ("API key saved: " + (Resolve-Path $localKey))
Write-Host "Keep the API key private."
