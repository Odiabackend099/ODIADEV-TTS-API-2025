# ODIADEV TTS API – Minimal PRD

## Base URL
- Production (EC2): http://13.247.217.147

## Auth
- Header: `x-api-key: <string>` for user calls
- Admin endpoints require header `x-admin-token: <string>` (server-only; not used in tests)

## Endpoints
### GET /health
- 200 JSON: `{ "service": "ODIADEV TTS API", "status": "healthy", "version": "<semver>" }`

### POST /v1/tts
- Headers: `x-api-key`
- Body (JSON):
  - `text: string` (<= ~4000 chars for this test)
  - `voice: string` (e.g., "alloy" or "naija_female")
  - `format: string` ("mp3" | "wav")
- Returns:
  - In mock mode: 200 JSON `{ data: { audio_base64, format, provider, mock: true }, success: true }`
  - In real mode: may stream/binary; for tests we accept 200 JSON OR 200 audio content-type.

### (Optional) GET /api/logs?limit=5
- 200 JSON list of recent app logs

## Non-functional
- P95 latency < 3s for /v1/tts (mock)
- Handles header missing with 401/403
- Handles bad body with 400/422