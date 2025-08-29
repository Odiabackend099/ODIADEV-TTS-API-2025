-- ODIADEV TTS API - Enhanced Supabase Schema
-- Execute this in Supabase SQL Editor to set up the complete database

-- Enable UUID extension (if not already enabled)
create extension if not exists "uuid-ossp";

-- Tenants table (optional multi-tenancy support)
create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  plan_tier text not null default 'starter' check (plan_tier in ('starter', 'pro', 'enterprise')),
  status text not null default 'active' check (status in ('active', 'suspended', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- API Keys management (hashed keys for security)
create table if not exists api_keys (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references tenants(id) on delete cascade,
  label text,
  key_hash text not null unique,
  status text not null default 'active' check (status in ('active','revoked')),
  rate_limit_per_min int not null default 60,
  created_at timestamptz default now(),
  last_used_at timestamptz,
  usage_count bigint default 0
);

-- TTS Usage tracking (for analytics and billing)
create table if not exists tts_usage (
  id bigserial primary key,
  api_key_id uuid references api_keys(id) on delete cascade,
  char_count int not null,
  request_ms int,
  cache_hit boolean default false,
  voice_used text,
  format_used text,
  error_occurred boolean default false,
  error_message text,
  created_at timestamptz default now()
);

-- Rate limiting tracking (for per-minute limits)
create table if not exists rate_limits (
  id bigserial primary key,
  api_key_id uuid references api_keys(id) on delete cascade,
  window_start timestamptz not null,
  request_count int not null default 1,
  created_at timestamptz default now(),
  unique(api_key_id, window_start)
);

-- System logs (for monitoring and debugging)
create table if not exists system_logs (
  id bigserial primary key,
  level text not null check (level in ('debug', 'info', 'warn', 'error')),
  message text not null,
  component text,
  api_key_id uuid,
  metadata jsonb,
  created_at timestamptz default now()
);

-- Performance indexes
create index if not exists idx_api_keys_status on api_keys(status);
create index if not exists idx_api_keys_tenant on api_keys(tenant_id);
create index if not exists idx_api_keys_hash on api_keys(key_hash);
create index if not exists idx_tts_usage_key_time on tts_usage(api_key_id, created_at);
create index if not exists idx_tts_usage_time on tts_usage(created_at);
create index if not exists idx_rate_limits_key_window on rate_limits(api_key_id, window_start);
create index if not exists idx_system_logs_time on system_logs(created_at);
create index if not exists idx_system_logs_level on system_logs(level);

-- Row Level Security (RLS) policies for multi-tenancy
alter table tenants enable row level security;
alter table api_keys enable row level security;
alter table tts_usage enable row level security;
alter table rate_limits enable row level security;
alter table system_logs enable row level security;

-- Service role can access all data (for the API)
create policy "Service role can access all tenants" on tenants
  for all using (auth.role() = 'service_role');

create policy "Service role can access all api_keys" on api_keys
  for all using (auth.role() = 'service_role');

create policy "Service role can access all tts_usage" on tts_usage
  for all using (auth.role() = 'service_role');

create policy "Service role can access all rate_limits" on rate_limits
  for all using (auth.role() = 'service_role');

create policy "Service role can access all system_logs" on system_logs
  for all using (auth.role() = 'service_role');

-- Functions for common operations

-- Function to clean up old rate limit records (run periodically)
create or replace function cleanup_old_rate_limits()
returns void as $$
begin
  delete from rate_limits 
  where window_start < now() - interval '1 hour';
end;
$$ language plpgsql;

-- Function to get usage stats for a time period
create or replace function get_usage_stats(
  start_time timestamptz default now() - interval '1 day',
  end_time timestamptz default now()
)
returns table (
  total_requests bigint,
  total_characters bigint,
  avg_response_time numeric,
  cache_hit_rate numeric,
  unique_keys bigint,
  error_rate numeric
) as $$
begin
  return query
  select 
    count(*)::bigint as total_requests,
    sum(char_count)::bigint as total_characters,
    round(avg(request_ms), 2) as avg_response_time,
    round(avg(case when cache_hit then 1 else 0 end) * 100, 2) as cache_hit_rate,
    count(distinct api_key_id)::bigint as unique_keys,
    round(avg(case when error_occurred then 1 else 0 end) * 100, 2) as error_rate
  from tts_usage
  where created_at between start_time and end_time;
end;
$$ language plpgsql;

-- Function to update API key last used timestamp
create or replace function update_api_key_usage(key_id uuid)
returns void as $$
begin
  update api_keys 
  set 
    last_used_at = now(),
    usage_count = usage_count + 1
  where id = key_id;
end;
$$ language plpgsql;

-- Sample data for testing (optional - remove for production)
-- insert into tenants (name, email, plan_tier) values 
--   ('ODIADEV Test Tenant', 'test@odiadev.com', 'pro'),
--   ('Demo Company', 'demo@example.com', 'starter');

-- Grants for service role
grant usage on schema public to service_role;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- Set up automatic updated_at trigger for tenants
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_tenants_updated_at 
  before update on tenants 
  for each row execute function update_updated_at_column();

-- Comments for documentation
comment on table tenants is 'Multi-tenant support for TTS API';
comment on table api_keys is 'Hashed API keys with rate limiting configuration';
comment on table tts_usage is 'Usage tracking for analytics and billing';
comment on table rate_limits is 'Rate limiting enforcement data';
comment on table system_logs is 'System-wide logging for monitoring';

comment on function get_usage_stats is 'Get aggregated usage statistics for a time period';
comment on function cleanup_old_rate_limits is 'Clean up old rate limiting records (run via cron)';
comment on function update_api_key_usage is 'Update API key usage counters';

-- Create initial admin notification (optional)
insert into system_logs (level, message, component, metadata) 
values ('info', 'ODIADEV TTS API database schema installed successfully', 'setup', 
        jsonb_build_object('version', '1.0.0', 'timestamp', now()));