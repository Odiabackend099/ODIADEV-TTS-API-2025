# ODIADEV TTS API (Self‑Hosted, Nigerian English + Pidgin Ready)

This is a **self‑hosted TTS API** built with **FastAPI**. It’s designed for ODIADEV to issue **API keys** via Supabase, rate‑limit usage, and return **MP3** (or WAV) audio. Default engine uses **Coqui TTS (VITS family)** on CPU; swap/extend engines for YourTTS/XTTS/Piper as needed.

> Goal: “Sesame/Maya‑level” quality for **Nigerian English & Pidgin**, fully in‑house. Stage 1 ships today (neutral English + Naija prosody tuning). Stage 2 fine‑tunes on Nigerian datasets/voice to reach authentic accent.

## Quick Start (Windows PowerShell)

```powershell
# 1) Copy .env.example to .env and fill values
Copy-Item .\config\.env.example .\config\.env

# 2) Build and run locally with Docker
docker build -t odiadev/tts:local -f server/Dockerfile .
docker compose -f infra/docker-compose.yml up -d

# 3) Test
curl -X POST http://localhost:8080/v1/tts -H "x-api-key: YOUR_TEST_KEY" ^
  -H "Content-Type: application/json" ^
  -d "{ \"text\": \"Hello from ODIADEV!\", \"voice\": \"naija_female\", \"format\": \"mp3\" } " --output out.mp3
```

## Production (AWS EC2, af-south-1)
- Use our ECR/EC2 deploy script from the Company OS plan (Caddy reverse proxy).
- Container exposes **3000** internally; Caddy serves HTTPS on **443**.

## Engines
- **Coqui TTS (default)**: Good quality out of the box; supports multiple English accents when paired with speaker embeddings. We’ll supply Nigerian voice embeddings (Stage 2).
- **Piper** (optional): Ultra fast, tiny footprint; use when CPU is limited, then train a custom Nigerian voice model later.

**Note:** Avoid third‑party cloud TTS. This is fully self‑hosted.

## Security/Keys
- API keys are stored hashed in Supabase (`api_keys.key_hash = sha256(plaintext)`).
- Rate limiting per key; usage tracked (chars + latency).

## License
This template code is MIT. Ensure any model weights you use allow **commercial** use before going live.
