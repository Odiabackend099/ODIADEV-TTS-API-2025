@"
# ODIADEV TTS API — Product Spec (Local Dev)

## Purpose
Provide a fast, Nigerian-accent text-to-speech API with simple auth, easy deployment (Docker), and admin key management.

## Base URL (local)
http://localhost:5000

## Endpoints

### 1) Health
- **GET /health**
- **200** → `{"status":"ok"}`

### 2) Admin – Issue API Key
- **POST /admin/keys/issue**
- **Headers:** `x-admin-token: <ADMIN_TOKEN>`
- **Body (JSON):** `{"label":"testsprite"}`
- **200** → `{"plaintext_key":"<use-this-as-x-api-key>", "id":"...", "label":"..."}`

### 3) TTS Synthesis
- **POST /v1/tts**
- **Headers:** `x-api-key: <plaintext_key>`, `Content-Type: application/json`
- **Body (JSON):**
```json
{"text":"Hello Naija","voice":"naija_female","format":"mp3"}
