# server/security.py
import os, hashlib, time
from typing import Optional
from fastapi import HTTPException, status

import requests

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

def sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()

def supabase_select_api_key(key_hash: str) -> Optional[dict]:
    if not SUPABASE_URL or not SUPABASE_KEY:
        # Dev mode: allow a single fixed key "TEST_KEY"
        if key_hash == sha256_hex("TEST_KEY"):
            return {"id": "00000000-0000-0000-0000-000000000000", "rate_limit_per_min": 60, "status": "active"}
        return None
    url = f"{SUPABASE_URL}/rest/v1/api_keys?select=*&key_hash=eq.{key_hash}&status=eq.active"
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    r = requests.get(url, headers=headers, timeout=10)
    if r.status_code != 200 or not r.json():
        return None
    return r.json()[0]

# simple in-memory rate limiter (per-process)
_BUCKETS = {}

def check_and_consume_rate(key_id: str, limit_per_min: int):
    now = int(time.time())
    window = now // 60
    k = f"{key_id}:{window}"
    used = _BUCKETS.get(k, 0)
    if used >= limit_per_min:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Rate limit exceeded")
    _BUCKETS[k] = used + 1
