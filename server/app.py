# server/app.py
import os, io, time, hashlib, json
from typing import Optional
from fastapi import FastAPI, HTTPException, Header, Response, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import boto3
from botocore.exceptions import BotoCoreError, ClientError

from .engine import TTSEngine
from .security import sha256_hex, supabase_select_api_key, check_and_consume_rate

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", "config", ".env"))

PORT = int(os.getenv("PORT", "3000"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "info")
ALLOWED_ORIGINS = [o.strip() for o in os.getenv("ALLOWED_ORIGINS", "*").split(",")]
S3_BUCKET = os.getenv("S3_BUCKET_TTS", "")
AWS_REGION = os.getenv("AWS_REGION", "af-south-1")
ADMIN_TOKEN = os.getenv("ADMIN_TOKEN", "")

app = FastAPI(title="ODIADEV TTS API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if "*" in ALLOWED_ORIGINS else ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_engine = TTSEngine()

# ---------- Models
class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)
    voice: Optional[str] = "naija_female"
    format: str = Field(default="mp3", pattern="^(mp3|wav|ogg)$")
    speed: float = Field(default=1.0, ge=0.5, le=1.5)

class IssueKeyRequest(BaseModel):
    tenant_id: Optional[str] = None
    label: Optional[str] = "default"
    rate_limit_per_min: int = 60
    # optionally pre-create with plaintext provided
    plaintext_key: Optional[str] = None

# ---------- Helpers
def _s3_client():
    # Works with IAM role or static keys
    session = boto3.session.Session(region_name=AWS_REGION)
    return session.client("s3")

def _put_usage_async(api_key_id: str, char_count: int, ms: int, cache_hit: bool):
    # Fire-and-forget to Supabase if configured
    url = os.getenv("SUPABASE_URL", "").rstrip("/") + "/rest/v1/tts_usage"
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        return
    import threading, requests
    def _send():
        try:
            headers = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}
            payload = {"api_key_id": api_key_id, "char_count": char_count, "request_ms": ms, "cache_hit": cache_hit}
            requests.post(url, headers=headers, data=json.dumps(payload), timeout=5)
        except Exception:
            pass
    threading.Thread(target=_send, daemon=True).start()

def _upload_to_s3(file_path: str, cache_key: str) -> Optional[str]:
    if not S3_BUCKET:
        return None
    key = f"tts-cache/{cache_key}"
    s3 = _s3_client()
    try:
        s3.upload_file(file_path, S3_BUCKET, key, ExtraArgs={"ContentType": "audio/mpeg"})
        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": key},
            ExpiresIn=3600,
        )
        return url
    except (BotoCoreError, ClientError):
        return None

# ---------- Routes
@app.get("/health")
def health():
    return {"status": "ok", "engine": os.getenv("TTS_ENGINE", "coqui")}

def _auth(x_api_key: Optional[str] = Header(default=None)):
    if not x_api_key:
        raise HTTPException(status_code=401, detail="Missing API key")
    rec = supabase_select_api_key(sha256_hex(x_api_key))
    if not rec:
        raise HTTPException(status_code=401, detail="Invalid API key")
    check_and_consume_rate(rec["id"], rec["rate_limit_per_min"])
    return rec

@app.post("/v1/tts")
def tts(req: TTSRequest, auth=Depends(_auth)):
    path, cache_hit, ms = _engine.synth(req.text, req.voice, req.speed, req.format)
    cache_key = hashlib.sha1(open(path, "rb").read()).hexdigest() + f".{req.format}"
    s3_url = _upload_to_s3(path, cache_key)
    _put_usage_async(auth["id"], len(req.text), ms, cache_hit)

    # Prefer returning a signed URL if S3 configured
    if s3_url:
        return {"url": s3_url, "format": req.format, "cache_hit": cache_hit, "ms": ms}

    # Else, stream the bytes
    data = open(path, "rb").read()
    media = "audio/mpeg" if req.format == "mp3" else "audio/wav"
    return Response(content=data, media_type=media)

@app.get("/v1/voices")
def voices():
    # Static logical voices; at Stage 2 we'll map to real embeddings/models
    return {"voices": ["naija_female", "naija_male"], "engine": os.getenv("TTS_ENGINE", "coqui")}

@app.post("/admin/keys/issue")
def issue_key(payload: IssueKeyRequest, x_admin_token: Optional[str] = Header(default=None)):
    if ADMIN_TOKEN and x_admin_token != ADMIN_TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")

    import secrets, requests
    plaintext = payload.plaintext_key or secrets.token_urlsafe(32)
    key_hash = sha256_hex(plaintext)

    url = os.getenv("SUPABASE_URL", "").rstrip("/") + "/rest/v1/api_keys"
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        return {"plaintext_key": plaintext, "warning": "Supabase not configured; not persisted."}

    headers = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json", "Prefer": "return=representation"}
    row = {
        "tenant_id": payload.tenant_id,
        "label": payload.label,
        "key_hash": key_hash,
        "rate_limit_per_min": payload.rate_limit_per_min,
        "status": "active",
    }
    r = requests.post(url, headers=headers, data=json.dumps(row), timeout=10)
    if r.status_code not in (200, 201):
        raise HTTPException(status_code=500, detail=f"Supabase insert failed: {r.text}")
    return {"plaintext_key": plaintext, "record": r.json()[0]}
