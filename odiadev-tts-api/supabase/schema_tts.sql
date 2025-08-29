-- supabase/schema_tts.sql
-- Key management (hashed)
create table if not exists api_keys (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references tenants(id) on delete cascade,
  label text,
  key_hash text not null unique,
  status text not null default 'active' check (status in ('active','revoked')),
  rate_limit_per_min int not null default 60,
  created_at timestamptz default now()
);

-- Usage accounting (lightweight; no message content)
create table if not exists tts_usage (
  id bigserial primary key,
  api_key_id uuid references api_keys(id) on delete cascade,
  char_count int not null,
  request_ms int,
  cache_hit boolean default false,
  created_at timestamptz default now()
);

-- Helper index
create index if not exists idx_api_keys_status on api_keys(status);
