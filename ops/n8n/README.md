# ODIADEV TTS API - n8n Workflow Stubs

This directory contains n8n workflow templates for automating key management, monitoring, and alerting for the ODIADEV TTS API.

## 📁 Workflows

### 1. `api-key-issuance.json`
**Purpose:** Automate API key issuance through webhook  
**Trigger:** HTTP POST webhook  
**Features:**
- Receives key issuance requests via webhook
- Issues new API keys through admin endpoint
- Sends success/error responses
- Notifies team via Slack

**Webhook Endpoint:** `POST /issue-api-key`

**Request Body:**
```json
{
  "label": "mobile-app-v2",
  "rate_limit_per_min": 120,
  "tenant_id": "uuid-optional"
}
```

**Response:**
```json
{
  "success": true,
  "api_key": "generated-key-here",
  "key_id": "uuid",
  "label": "mobile-app-v2",
  "rate_limit": 120
}
```

### 2. `usage-monitoring.json`
**Purpose:** Monitor API usage and send alerts  
**Trigger:** Scheduled every 15 minutes  
**Features:**
- Fetches usage data from Supabase
- Analyzes metrics and performance
- Detects high usage patterns
- Monitors API health
- Sends alerts for anomalies

**Metrics Tracked:**
- Total requests in period
- Character count processed
- Average response time
- Cache hit rate
- High-usage API keys
- Slow response detection

### 3. `api-key-revocation.json`
**Purpose:** Revoke API keys through webhook  
**Trigger:** HTTP POST webhook  
**Features:**
- Validates revocation requests
- Updates key status in Supabase
- Provides confirmation responses
- Logs revocation events

**Webhook Endpoint:** `POST /revoke-api-key`

**Request Body:**
```json
{
  "key_id": "uuid-of-key-to-revoke",
  "reason": "Security breach",
  "revoked_by": "admin@odiadev.com"
}
```

## 🚀 Setup Instructions

### Prerequisites
- n8n instance (self-hosted or cloud)
- Access to ODIADEV TTS API
- Supabase database access
- Slack webhook URL (optional, for notifications)

### Environment Variables
Configure these in your n8n environment:

```bash
# TTS API Configuration
TTS_API_URL=http://localhost:8080  # or production URL
TTS_ADMIN_TOKEN=your-admin-token-here

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Notifications (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

### Import Workflows

1. **Open n8n interface**
2. **Create new workflow**
3. **Import from JSON:**
   - Copy content from any `.json` file in this directory
   - Paste into n8n workflow import dialog
4. **Configure credentials:**
   - Set up HTTP Header Auth for Supabase
   - Configure webhook URLs
5. **Activate workflows**

### Credential Setup

#### Supabase HTTP Header Auth
- **Name:** `supabase-auth`
- **Header:** `Authorization`
- **Value:** `Bearer YOUR_SERVICE_ROLE_KEY`

#### Admin Token Header Auth
- **Name:** `tts-admin-auth`  
- **Header:** `x-admin-token`
- **Value:** `YOUR_ADMIN_TOKEN`

## 🔧 Customization

### Modify Alert Thresholds
Edit the `Analyze Usage` node in `usage-monitoring.json`:

```javascript
// Current thresholds
const highUsageKeys = Object.entries(keyUsage)
  .filter(([key, data]) => data.requests > 50)  // Adjust threshold
  
const slowResponses = usage.filter(item => (item.json.request_ms || 0) > 5000); // Adjust timeout
```

### Add Custom Notifications
Extend workflows to support additional notification channels:
- Email notifications
- Discord webhooks
- PagerDuty alerts
- Custom API calls

### Scheduling Changes
Modify the `Schedule Trigger` in monitoring workflow:
- **Current:** Every 15 minutes
- **Options:** 5min, 30min, hourly, etc.

## 📊 Dashboard Integration

### Grafana Integration
Add HTTP Request node to send metrics to Grafana:

```json
{
  "url": "http://grafana:3000/api/annotations",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer YOUR_GRAFANA_TOKEN"
  },
  "body": {
    "text": "High TTS usage detected",
    "tags": ["tts", "usage", "alert"],
    "time": "{{DateTime.now().toMillis()}}"
  }
}
```

### Prometheus Metrics
Export metrics to Prometheus endpoint:

```javascript
// In analysis node, format for Prometheus
const prometheusMetrics = `
# HELP tts_requests_total Total TTS requests
# TYPE tts_requests_total counter
tts_requests_total ${totalRequests}

# HELP tts_response_time_avg Average response time in ms  
# TYPE tts_response_time_avg gauge
tts_response_time_avg ${avgResponseTime}

# HELP tts_cache_hit_rate Cache hit rate percentage
# TYPE tts_cache_hit_rate gauge  
tts_cache_hit_rate ${cacheHitRate}
`;
```

## 🛡️ Security Considerations

### Webhook Security
- Use HTTPS endpoints only
- Implement webhook authentication
- Validate request signatures
- Rate limit webhook endpoints

### Credential Management
- Store credentials securely in n8n
- Use environment variables for sensitive data
- Rotate API keys regularly
- Audit workflow access

### Data Privacy
- Avoid logging sensitive data
- Mask API keys in notifications
- Comply with data retention policies

## 🔍 Troubleshooting

### Common Issues

#### Workflow Not Triggering
- Check webhook URL configuration
- Verify trigger is activated
- Review n8n execution logs

#### Supabase Connection Errors
- Validate service role key
- Check network connectivity
- Verify table permissions

#### Missing Notifications
- Test Slack webhook URL
- Check notification conditions
- Review error logs

### Debug Mode
Enable debug output in workflows:

```javascript
// Add to any Code node
console.log('Debug data:', JSON.stringify($input.all(), null, 2));
return $input.all();
```

## 📈 Scaling Considerations

### High-Volume Environments
- Increase monitoring frequency
- Add queue management
- Implement batched operations
- Scale n8n workers

### Multi-Region Setup
- Deploy regional n8n instances  
- Configure region-specific endpoints
- Implement cross-region monitoring

## 📞 Support

For issues with these workflows:
1. Check n8n execution logs
2. Review TTS API health endpoints
3. Validate Supabase connectivity
4. Consult n8n documentation
5. Contact ODIADEV support team

## 🔄 Version History

- **v1.0.0** (2025-08-29): Initial workflow stubs
  - API key issuance automation
  - Usage monitoring and alerts  
  - Key revocation workflow
  - Basic Slack notifications

---

*These workflows provide a foundation for TTS API automation. Customize according to your specific operational needs.*