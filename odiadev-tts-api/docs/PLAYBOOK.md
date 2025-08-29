# ODIADEV TTS — Execution Notes

**Stage 1 (Today):** Ship neutral English w/ Naija prosody using Coqui. Return MP3, API keys in Supabase, S3 cache via IAM role. Windows one‑click works locally; deploy to EC2 via ECR/Caddy script.

**Stage 2 (2–3 weeks):** Record 3–6 hours Nigerian English + Pidgin from approved voice talent; align with MFA/WhisperX; fine‑tune VITS/YourTTS; export inference model; replace `COQUI_MODEL_NAME` or add custom checkpoint. Update `/v1/voices` to map to new embeddings.

**Data:** Keep transcripts simple, conversational, include Pidgin variants. Aim for 10–15k sentences across both registers for production quality.
