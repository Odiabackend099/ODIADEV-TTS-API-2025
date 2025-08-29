param(
  [string]$ServerIP    = "13.247.217.147",
  [string]$PemPath     = "$HOME\Downloads\odiadev-ec2.pem",
  [string]$ProjectDir  = "$HOME\Downloads\odiadev-tts-api",
  [string]$Voice       = "naija_female",
  [string]$SampleText  = "Hello Naija, this is ODIADEV TTS live!",
  [string]$LocalOutDir = "$HOME\Downloads\odiadev-tts-api\output"
)

$ErrorActionPreference = "Stop"
Write-Host "`n=== ODIADEV • One-Click EC2 TTS Deploy ===`n" -ForegroundColor Cyan

function Need($cmd){
  if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required command '$cmd' not found in PATH."
  }
}

# --- Preflight ---------------------------------------------------------
Need "ssh"; Need "scp"
if (!(Test-Path $PemPath))    { throw "PEM file not found: $PemPath" }
if (!(Test-Path $ProjectDir)) { throw "Project folder not found: $ProjectDir" }

Write-Host "Setting PEM file permissions..." -ForegroundColor Yellow
icacls $PemPath /inheritance:r | Out-Null
icacls $PemPath /grant:r "$($env:UserName):(R)" | Out-Null

Write-Host "Priming SSH known_hosts..." -ForegroundColor Yellow
ssh -i $PemPath -o StrictHostKeyChecking=accept-new "ubuntu@$ServerIP" "echo ok" | Out-Null

# --- Copy the project safely (no ZIPs, no backslashes) ----------------
Write-Host "Copying project to server..." -ForegroundColor Yellow
ssh -i $PemPath "ubuntu@$ServerIP" "rm -rf ~/odiadev-tts-api && mkdir -p ~/odiadev-tts-api" | Out-Null
scp -i $PemPath -r "$ProjectDir\*" "ubuntu@${ServerIP}:~/odiadev-tts-api/" | Out-Null

# --- Remote deploy script (single-quoted here-string; no PS parsing) ---
$remoteScript = @'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[1/7] Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y jq curl openssl python3 docker.io dos2unix

echo "[2/7] Ensuring Docker is running..."
sudo systemctl enable --now docker

echo "[3/7] CRLF->LF for *.sh and Dockerfile..."
cd ~/odiadev-tts-api
find . -type f \( -name "*.sh" -o -name "Dockerfile*" \) -print0 | xargs -0 -I{} bash -c 'sed -i "s/\r$//" "{}"'

echo "[4/7] Preparing config/.env ..."
mkdir -p config
if [ ! -f config/.env ]; then
  if [ -f config/.env.example ]; then
    cp config/.env.example config/.env
  else
    : > config/.env
  fi
fi
grep -q '^AWS_REGION='  config/.env || echo "AWS_REGION=af-south-1" >> config/.env
grep -q '^TTS_ENGINE='  config/.env || echo "TTS_ENGINE=coqui"     >> config/.env
if ! grep -q '^ADMIN_TOKEN=' config/.env; then
  AT="$(openssl rand -hex 24 || true)"
  if [ -z "$AT" ]; then AT="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(24))
PY
)"; fi
  echo "ADMIN_TOKEN=$AT" >> config/.env
fi

echo "[5/7] Building Docker image..."
DOCKERFILE="Dockerfile"
[ -f server/Dockerfile ] && DOCKERFILE="server/Dockerfile"
sudo docker rm -f tts-holding >/dev/null 2>&1 || true
sudo docker rm -f odiadev-tts  >/dev/null 2>&1 || true
sudo docker build -t odiadev/tts:local -f "$DOCKERFILE" .

echo "[6/7] Running container on 127.0.0.1:3000 ..."
sudo docker run -d --name odiadev-tts --restart unless-stopped \
  --env-file config/.env -p 127.0.0.1:3000:3000 \
  odiadev/tts:local

echo "[7/7] Waiting for /health ..."
for i in {1..150}; do
  if curl -sf http://127.0.0.1:3000/health >/dev/null; then echo "HEALTH_OK"; break; fi
  sleep 2
done

# Try to issue key
ADMIN_TOKEN="$(grep '^ADMIN_TOKEN=' config/.env | cut -d= -f2-)"
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/admin/keys/issue | grep -qE '^(200|201|401|403)$'; then
  curl -s -X POST http://127.0.0.1:3000/admin/keys/issue \
    -H "x-admin-token: $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"label":"first-key"}' > key.json || true
  API_KEY="$(jq -r '.plaintext_key // empty' key.json 2>/dev/null || true)"
  if [ -n "$API_KEY" ]; then
    echo "$API_KEY" > DEV_TTS_KEY.txt
    chmod 600 DEV_TTS_KEY.txt
  fi
fi

# Try sample TTS
API_KEY_HDR=""
[ -f DEV_TTS_KEY.txt ] && API_KEY_HDR="-H x-api-key: $(cat DEV_TTS_KEY.txt)"
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/v1/tts | grep -qE '^(200|400|405)$'; then
  curl -s -X POST http://127.0.0.1:3000/v1/tts \
    $API_KEY_HDR -H "Content-Type: application/json" \
    -d '{"text":"__SAMPLETEXT__","voice":"__VOICE__","format":"mp3"}' \
    --output out.mp3 || true
fi

[ -s out.mp3 ] && echo READY || echo READY_NO_MP3
'@

# inject content safely
$remoteScript = $remoteScript.Replace('__SAMPLETEXT__', ($SampleText.Replace('"','\"')))
$remoteScript = $remoteScript.Replace('__VOICE__', $Voice)

# write without BOM; upload; strip CR; execute
$tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
[System.IO.File]::WriteAllText($tempScript, $remoteScript, [System.Text.UTF8Encoding]::new($false))
scp -i $PemPath "$tempScript" "ubuntu@${ServerIP}:~/deploy_run.sh" | Out-Null
$remoteResult = ssh -i $PemPath "ubuntu@$ServerIP" "tr -d '\r' < ~/deploy_run.sh > ~/deploy_run.lf && bash ~/deploy_run.lf" 2>&1

if (-not $remoteResult -or ($remoteResult -notmatch 'READY')) {
  throw "Remote build/run failed. Output:`n$remoteResult"
}
Write-Host "Server reports:`n$remoteResult" -ForegroundColor Green

# --- pull artifacts if present ----------------------------------------
New-Item -ItemType Directory -Force -Path $LocalOutDir | Out-Null
$localMp3 = Join-Path $LocalOutDir 'out.mp3'
$localKey = Join-Path $LocalOutDir 'DEV_TTS_KEY.txt'

Write-Host "Downloading MP3 and API key (if present)..." -ForegroundColor Yellow
try { scp -i $PemPath "ubuntu@${ServerIP}:~/odiadev-tts-api/out.mp3"         "$localMp3" | Out-Null } catch { }
try { scp -i $PemPath "ubuntu@${ServerIP}:~/odiadev-tts-api/DEV_TTS_KEY.txt" "$localKey" | Out-Null } catch { }

if (Test-Path $localMp3) { Write-Host ("MP3 saved to:  " + (Resolve-Path $localMp3)) -ForegroundColor Green }
if (Test-Path $localKey) { Write-Host ("API key saved: " + (Resolve-Path $localKey)) -ForegroundColor Green }

Write-Host "`nDone. If Caddy is proxying :80 → 127.0.0.1:3000, your API is now at http://$ServerIP" -ForegroundColor Green
