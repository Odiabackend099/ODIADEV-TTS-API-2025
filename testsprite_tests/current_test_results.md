# ODIADEV TTS API Test Results

## Current Status: API Backend Issues Detected

### 🔍 Test Summary
**Date:** $(Get-Date)
**Target:** http://13.247.217.147
**API Key:** sk-user-0cze1Y-...

### 🔥 Critical Issues Found

#### 1. Health Endpoint Test
**URL:** GET http://13.247.217.147/health
**Expected:** 200 JSON with `{ "service": "ODIADEV TTS API", "status": "healthy" }`
**Actual:** ❌ **502 Bad Gateway**

This indicates:
- Nginx is running (receiving requests)
- Backend container is DOWN or not responding
- Docker container may have crashed or failed to start

#### 2. TTS Endpoint Test  
**URL:** POST http://13.247.217.147/v1/tts
**Status:** ❌ **Cannot test** (backend down)

### 🛠️ Immediate Fix Required

The 502 error means your backend container is not running. To fix this, you need to:

1. **SSH into your EC2 instance:**
   ```bash
   ssh -i your-key.pem ubuntu@13.247.217.147
   ```

2. **Check container status:**
   ```bash
   sudo docker ps
   sudo docker logs odiadev-tts --tail=50
   ```

3. **If container is not running, restart it:**
   ```bash
   sudo docker-compose up -d
   # OR
   sudo docker run -d --name odiadev-tts -p 3000:3000 your-image
   ```

4. **Check Nginx configuration:**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   curl http://localhost:3000/health
   ```

### 📋 Once Backend is Fixed, Run These Tests:

#### Health Check Test
```powershell
$response = Invoke-WebRequest "http://13.247.217.147/health" -UseBasicParsing
Write-Host "Status: $($response.StatusCode)"
Write-Host "Content: $($response.Content)"
```

#### TTS API Test  
```powershell
$headers = @{ "x-api-key" = "sk-user-0cze1Y-8gbUpRXGmbEs5-0ScoTrw5LaGOuBGuJzu7zucKLQi1S1J-YQPCFsIUQ16QYDbj9obOOb6Uy3OaHHgu1-a-T0-8UHsY4q3mUE2Z43ksDlgO4Kqdqn1htMrLNh0GA8" }
$body = @{ 
    text = "Hello from ODIADEV TTS API test"
    voice = "alloy"  
    format = "mp3"
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "http://13.247.217.147/v1/tts" -Method POST -Body $body -Headers $headers -ContentType "application/json"
Write-Host "TTS Status: $($response.StatusCode)"
```

#### Authentication Test (Should fail)
```powershell
$body = @{ 
    text = "Test without API key"
    voice = "alloy"
    format = "mp3"
} | ConvertTo-Json

try {
    Invoke-WebRequest -Uri "http://13.247.217.147/v1/tts" -Method POST -Body $body -ContentType "application/json"
} catch {
    Write-Host "Expected auth failure: $($_.Exception.Response.StatusCode)"
}
```

### 🎯 Expected Results After Fix:
- ✅ Health endpoint returns 200 with service info
- ✅ TTS endpoint returns 200 with audio data (mock mode)
- ✅ TTS without API key returns 401/403
- ✅ TTS with malformed body returns 400/422
- ✅ Response time < 3 seconds