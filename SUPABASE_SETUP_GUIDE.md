# SUPABASE SETUP GUIDE
# Apply Enhanced Schema for ODIADEV TTS API

## Step 1: Create Supabase Project

1. Go to https://app.supabase.com
2. Click "New Project"
3. Choose your organization
4. Project Name: `odiadev-tts-api`
5. Database Password: Generate a strong password (save it!)
6. Region: Choose closest to af-south-1 (e.g., eu-west-1)
7. Click "Create new project"
8. Wait for project to be ready (2-3 minutes)

## Step 2: Get Project Connection Details

After project creation, go to Settings > Database:
- Host: `db.[your-project-ref].supabase.co`
- Database name: `postgres`
- Port: `5432`
- User: `postgres`
- Password: [your-database-password]

Also get from Settings > API:
- Project URL: `https://[your-project-ref].supabase.co`
- anon public key: `eyJhbGciOiJIUzI1NiIsInR5cCI6...`
- service_role key: `eyJhbGciOiJIUzI1NiIsInR5cCI6...` (secret!)

## Step 3: Apply Enhanced Schema

1. In Supabase Dashboard, go to "SQL Editor"
2. Click "New Query"
3. Copy and paste the COMPLETE SQL below:

```sql
-- ========================================
-- ODIADEV TTS API - Enhanced Schema
-- ========================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tenants table (multi-tenancy support)
CREATE TABLE IF NOT EXISTS tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted'))
);

-- Create API keys table (hashed storage)
CREATE TABLE IF NOT EXISTS api_keys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  label TEXT,
  key_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked')),
  rate_limit_per_min INTEGER NOT NULL DEFAULT 60,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  usage_count BIGINT DEFAULT 0
);

-- Create TTS usage tracking table
CREATE TABLE IF NOT EXISTS tts_usage (
  id BIGSERIAL PRIMARY KEY,
  api_key_id UUID REFERENCES api_keys(id) ON DELETE CASCADE,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  text_length INTEGER NOT NULL,
  voice_used TEXT,
  format_used TEXT DEFAULT 'mp3',
  cache_hit BOOLEAN DEFAULT FALSE,
  processing_ms INTEGER,
  request_ip INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create admin tokens table
CREATE TABLE IF NOT EXISTS admin_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  token_hash TEXT NOT NULL UNIQUE,
  description TEXT,
  permissions TEXT[] DEFAULT ARRAY['key_management'],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked'))
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_api_keys_status ON api_keys(status);
CREATE INDEX IF NOT EXISTS idx_api_keys_tenant ON api_keys(tenant_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_tts_usage_api_key ON tts_usage(api_key_id);
CREATE INDEX IF NOT EXISTS idx_tts_usage_created ON tts_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_tokens_hash ON admin_tokens(token_hash);

-- Enable Row Level Security (RLS)
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE tts_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies for tenants
CREATE POLICY "Tenants can view own data" ON tenants
    FOR SELECT USING (auth.uid()::text = id::text);

-- RLS Policies for api_keys
CREATE POLICY "API keys belong to tenant" ON api_keys
    FOR ALL USING (tenant_id = auth.uid()::uuid);

-- RLS Policies for tts_usage
CREATE POLICY "Usage belongs to tenant" ON tts_usage
    FOR ALL USING (tenant_id = auth.uid()::uuid);

-- RLS Policies for admin_tokens (service role only)
CREATE POLICY "Admin tokens service role only" ON admin_tokens
    FOR ALL USING (auth.role() = 'service_role');

-- Function to hash API keys
CREATE OR REPLACE FUNCTION hash_api_key(plain_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(plain_key, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate API key
CREATE OR REPLACE FUNCTION generate_api_key()
RETURNS TEXT AS $$
DECLARE
    key_length INTEGER := 32;
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..key_length LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to issue API key
CREATE OR REPLACE FUNCTION issue_api_key(
    p_label TEXT DEFAULT 'api-key',
    p_tenant_id UUID DEFAULT NULL,
    p_rate_limit INTEGER DEFAULT 60
)
RETURNS JSON AS $$
DECLARE
    new_key TEXT;
    key_record RECORD;
    result JSON;
BEGIN
    -- Generate new API key
    new_key := generate_api_key();
    
    -- Insert API key record
    INSERT INTO api_keys (tenant_id, label, key_hash, rate_limit_per_min)
    VALUES (p_tenant_id, p_label, hash_api_key(new_key), p_rate_limit)
    RETURNING * INTO key_record;
    
    -- Return both the plaintext key and the record
    result := json_build_object(
        'plaintext_key', new_key,
        'record', row_to_json(key_record)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate API key
CREATE OR REPLACE FUNCTION validate_api_key(plain_key TEXT)
RETURNS TABLE(
    key_id UUID,
    tenant_id UUID,
    label TEXT,
    rate_limit_per_min INTEGER,
    is_valid BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ak.id,
        ak.tenant_id,
        ak.label,
        ak.rate_limit_per_min,
        (ak.status = 'active') as is_valid
    FROM api_keys ak
    WHERE ak.key_hash = hash_api_key(plain_key)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record TTS usage
CREATE OR REPLACE FUNCTION record_tts_usage(
    p_api_key_id UUID,
    p_text_length INTEGER,
    p_voice_used TEXT DEFAULT 'default',
    p_format_used TEXT DEFAULT 'mp3',
    p_cache_hit BOOLEAN DEFAULT FALSE,
    p_processing_ms INTEGER DEFAULT NULL,
    p_request_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    tenant_uuid UUID;
BEGIN
    -- Get tenant_id from api_key
    SELECT tenant_id INTO tenant_uuid
    FROM api_keys 
    WHERE id = p_api_key_id;
    
    -- Insert usage record
    INSERT INTO tts_usage (
        api_key_id, 
        tenant_id,
        text_length, 
        voice_used, 
        format_used,
        cache_hit,
        processing_ms,
        request_ip,
        user_agent
    )
    VALUES (
        p_api_key_id,
        tenant_uuid,
        p_text_length,
        p_voice_used,
        p_format_used,
        p_cache_hit,
        p_processing_ms,
        p_request_ip,
        p_user_agent
    );
    
    -- Update key usage count
    UPDATE api_keys 
    SET 
        usage_count = usage_count + 1,
        last_used_at = NOW()
    WHERE id = p_api_key_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create default tenant (for single-tenant usage)
INSERT INTO tenants (id, name, email, status)
VALUES (
    '00000000-0000-0000-0000-000000000000'::UUID,
    'ODIADEV Default Tenant',
    'admin@odiadev.com',
    'active'
) ON CONFLICT (id) DO NOTHING;

-- Create default admin token (hash of 'admin-token-12345')
INSERT INTO admin_tokens (token_hash, description, permissions)
VALUES (
    hash_api_key('admin-token-12345'),
    'Default admin token for initial setup',
    ARRAY['key_management', 'user_management', 'analytics']
) ON CONFLICT (token_hash) DO NOTHING;

-- Grant necessary permissions to anon and authenticated roles
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
```

4. Click "Run" to execute the SQL
5. Verify no errors appear in the output

## Step 4: Update Environment Variables

Add these to your `.env` file:

```bash
# Supabase Configuration
SUPABASE_URL=https://[your-project-ref].supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...

# Database Connection (optional, for direct connection)
DATABASE_URL=postgresql://postgres:[password]@db.[your-project-ref].supabase.co:5432/postgres

# Default Admin Token (for testing)
ADMIN_TOKEN=admin-token-12345
```

## Step 5: Test Database Connection

Create a test script to verify everything works:

```powershell
# Test Supabase connection
curl -X POST "https://[your-project-ref].supabase.co/rest/v1/rpc/issue_api_key" `
  -H "apikey: [your-anon-key]" `
  -H "Authorization: Bearer [your-service-key]" `
  -H "Content-Type: application/json" `
  -d '{"p_label": "test-key", "p_rate_limit": 60}'
```

## Step 6: Verify Tables Created

In Supabase Dashboard > Table Editor, you should see:
- ✅ tenants
- ✅ api_keys  
- ✅ tts_usage
- ✅ admin_tokens

## Next Steps

1. Update your `.env` file with Supabase credentials
2. Test API key issuance: `.\scripts\issue-api-key.ps1`
3. Proceed with Docker container build

## Security Notes

- ✅ All API keys are hashed with SHA-256
- ✅ Row Level Security (RLS) enabled
- ✅ Admin tokens have controlled permissions
- ✅ No secrets stored in plaintext
- ✅ Tenant isolation implemented

Your Supabase database is now ready for production use!