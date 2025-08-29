# ODIADEV TTS API - Deployment Report

**Date:** 2025-08-29  
**Version:** v0.1.0  
**Region:** af-south-1  
**Environment:** Production  

---

## 🎯 Deployment Overview

The ODIADEV TTS API has been configured for production deployment on AWS infrastructure with the following architecture:

- **Application:** FastAPI-based TTS service with Coqui TTS engine
- **Database:** Supabase for API key management and usage tracking
- **Storage:** S3 for audio file caching
- **Compute:** EC2 t3.small Ubuntu 22.04 LTS
- **Reverse Proxy:** Caddy with automatic HTTPS
- **Container:** Docker with multi-stage optimization

---

## 📋 Infrastructure Details

### Container Registry
```
ECR Repository: [TO_BE_FILLED]
Image URI: [TO_BE_FILLED]
Tag: v0.1.0
```

### Compute Instance
```
Instance ID: [TO_BE_FILLED]
Instance Type: t3.small
AMI: Ubuntu 22.04 LTS
Region: af-south-1
Availability Zone: af-south-1a
Public IP: [TO_BE_FILLED]
Domain: [TO_BE_FILLED]
```

### Storage
```
S3 Bucket: odiadev-tts-artifacts-af-south-1
Cache Location: tts-cache/
Retention: 30 days
```

### Database
```
Supabase URL: [CONFIGURED_IN_ENV]
Tables: api_keys, tts_usage
Schema Version: v1.0.0
```

---

## 🔧 Deployment Steps Completed

### Phase 1: Local Setup ✅
- [x] Project structure validated
- [x] Environment configuration (.env) setup
- [x] Admin token generated and secured
- [x] Docker configuration verified
- [x] Test suite created

### Phase 2: Docker Build & Test
- [ ] Docker image built successfully
- [ ] Local health check passed
- [ ] API key issuance tested
- [ ] TTS generation validated

### Phase 3: AWS Infrastructure
- [ ] AWS CLI configured (profile: odiadev)
- [ ] ECR repository created
- [ ] Docker image pushed to ECR
- [ ] S3 bucket created for artifacts

### Phase 4: EC2 Deployment
- [ ] EC2 instance launched
- [ ] Security groups configured (80/443)
- [ ] Docker and Caddy installed
- [ ] Application container deployed
- [ ] SSL certificate provisioned

### Phase 5: DNS & Verification
- [ ] DNS A record configured
- [ ] HTTPS health check passed
- [ ] End-to-end TTS test completed

---

## 🚀 Quick Start Commands

### Local Development
```bash
# Clone and setup
cd odiadev-tts-api
.\scripts\setup-env.ps1

# Build and run
docker build -t odiadev/tts:local -f server/Dockerfile .
docker compose -f infra/docker-compose.yml up -d

# Test
.\tests\test-endpoints.ps1
```

### Production Deployment
```bash
# AWS Setup
.\scripts\setup-aws.ps1

# Build and push
docker build -t odiadev/tts:v0.1.0 -f server/Dockerfile .
aws ecr get-login-password --region af-south-1 --profile odiadev | docker login --username AWS --password-stdin [ECR_URI]
docker tag odiadev/tts:v0.1.0 [ECR_URI]:v0.1.0
docker push [ECR_URI]:v0.1.0

# Deploy to EC2
.\scripts\deploy-ec2.ps1 -ImageUri [ECR_URI]:v0.1.0
```

---

## 🔍 Health Checks

### Local (Port 8080)
```bash
curl http://localhost:8080/health
```

### Production (HTTPS)
```bash
curl https://[DOMAIN]/health
```

### Expected Response
```json
{
  "status": "ok",
  "engine": "coqui"
}
```

---

## 🧪 Testing

### Automated Test Suite
```bash
# PowerShell
.\tests\test-endpoints.ps1

# Python
python tests/test_tts_api.py
```

### Manual API Test
```bash
# Issue API key
curl -X POST https://[DOMAIN]/admin/keys/issue \
  -H "x-admin-token: [ADMIN_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{"label": "production-test", "rate_limit_per_min": 100}'

# Generate TTS
curl -X POST https://[DOMAIN]/v1/tts \
  -H "x-api-key: [API_KEY]" \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello from ODIADEV TTS!", "voice": "naija_female", "format": "mp3"}' \
  --output test.mp3
```

---

## 🔐 Security Configuration

### Environment Variables
```bash
ADMIN_TOKEN=**SECURE** # Stored in secrets/ADMIN_TOKEN.txt
SUPABASE_URL=**CONFIGURED**
SUPABASE_SERVICE_ROLE_KEY=**SECURE**
AWS_REGION=af-south-1
S3_BUCKET_TTS=odiadev-tts-artifacts-af-south-1
TTS_ENGINE=coqui
```

### Security Groups
```
Port 80 (HTTP): 0.0.0.0/0 - Caddy redirect to HTTPS
Port 443 (HTTPS): 0.0.0.0/0 - API traffic
Port 22 (SSH): [ADMIN_IP]/32 - Management access
```

### SSL/TLS
- **Provider:** Let's Encrypt (via Caddy)
- **Auto-renewal:** Enabled
- **HSTS:** Enabled
- **Protocols:** TLS 1.2, TLS 1.3

---

## 📊 Monitoring & Logging

### Application Logs
```bash
# Container logs
docker logs odiadev-tts -f

# Caddy logs
sudo journalctl -u caddy -f
```

### Usage Metrics
- API key usage tracked in Supabase `tts_usage` table
- Character count, latency, and cache hit rates recorded
- Rate limiting enforced per API key

### Health Monitoring
- Health endpoint: `/health`
- Voices endpoint: `/v1/voices`
- Admin endpoints: `/admin/keys/*`

---

## 🔄 Rollback Procedures

### Emergency Rollback
```bash
# Stop current container
docker stop odiadev-tts

# Run previous version
docker run -d --name odiadev-tts-rollback \
  --env-file config/.env \
  -p 3000:3000 \
  [ECR_URI]:v0.0.9

# Update Caddy configuration if needed
sudo systemctl reload caddy
```

### Database Rollback
```sql
-- Revert schema changes if needed
-- Backup before any migrations
```

---

## 📈 Performance Specifications

### Hardware Requirements
- **CPU:** 2 vCPUs (t3.small)
- **Memory:** 2 GB RAM
- **Storage:** 20 GB EBS gp3
- **Network:** Up to 5 Gbps

### Performance Targets
- **TTS Generation:** < 3s for 200 characters
- **Health Check:** < 100ms
- **API Key Validation:** < 50ms
- **Cache Hit Ratio:** > 60%

### Rate Limits
- Default: 60 requests/minute per API key
- Admin: Configurable per key
- Global: 1000 requests/minute per instance

---

## 🛠️ Maintenance

### Regular Tasks
- **Daily:** Monitor logs and error rates
- **Weekly:** Review usage metrics and scaling needs
- **Monthly:** Update dependencies and security patches
- **Quarterly:** Review and optimize costs

### Backup Strategy
- **Database:** Supabase automatic backups
- **Configuration:** Environment files in secure storage
- **Docker Images:** ECR with retention policy

---

## 📞 Support & Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check logs
docker logs odiadev-tts

# Verify environment
docker exec odiadev-tts env | grep -E 'ADMIN_TOKEN|SUPABASE'

# Restart with fresh configuration
docker compose -f infra/docker-compose.yml down
docker compose -f infra/docker-compose.yml up -d
```

#### API Key Issues
```bash
# Verify admin token
cat secrets/ADMIN_TOKEN.txt

# Test admin endpoint
curl -X POST http://localhost:8080/admin/keys/issue \
  -H "x-admin-token: $(cat secrets/ADMIN_TOKEN.txt)" \
  -H "Content-Type: application/json" \
  -d '{"label": "debug-key"}'
```

#### TTS Generation Failures
```bash
# Check Coqui model download
docker exec odiadev-tts ls -la /root/.local/share/tts/

# Test with minimal text
curl -X POST http://localhost:8080/v1/tts \
  -H "x-api-key: [KEY]" \
  -H "Content-Type: application/json" \
  -d '{"text": "test", "voice": "naija_female"}'
```

### Contact Information
- **Team:** ODIADEV Engineering
- **Repository:** [GitHub Repository URL]
- **Documentation:** docs/PLAYBOOK.md
- **Integration Guide:** API_INTEGRATION_GUIDE.md

---

## 📋 Deployment Checklist

### Pre-deployment ✅
- [x] Environment variables configured
- [x] Admin token generated
- [x] Test suite created
- [x] Docker configuration validated

### Deployment (In Progress)
- [ ] Docker installed and running
- [ ] AWS CLI configured
- [ ] ECR repository created
- [ ] Image built and pushed
- [ ] EC2 instance launched
- [ ] Application deployed
- [ ] SSL certificate obtained
- [ ] DNS configured
- [ ] Health checks passing

### Post-deployment
- [ ] End-to-end testing completed
- [ ] Performance benchmarks met
- [ ] Monitoring configured
- [ ] Backup verification
- [ ] Documentation updated
- [ ] Team notification sent

---

*This deployment report will be updated as the deployment progresses.*

**Status:** 🚧 **In Progress** - Local setup completed, awaiting Docker and AWS deployment.

**Next Steps:**
1. Install Docker Desktop and start engine
2. Complete local testing with `.\tests\test-endpoints.ps1`
3. Install and configure AWS CLI
4. Execute ECR and EC2 deployment
5. Configure DNS and verify HTTPS endpoints