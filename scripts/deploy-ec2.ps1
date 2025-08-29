# scripts\deploy-ec2.ps1
# EC2 Deployment Script for ODIADEV TTS API with Caddy reverse proxy

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageUri,
    [string]$Region = "af-south-1",
    [string]$ProfileName = "odiadev",
    [string]$InstanceType = "t3.small",
    [string]$KeyPairName = "odiadev-tts-keypair",
    [string]$SecurityGroupName = "odiadev-tts-sg",
    [string]$Domain = "",
    [string]$InstanceName = "odiadev-tts-api",
    [switch]$CreateKeyPair = $true,
    [switch]$CreateSecurityGroup = $true
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 ODIADEV TTS API - EC2 Deployment" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Instance Type: $InstanceType" -ForegroundColor Yellow
Write-Host "Image URI: $ImageUri" -ForegroundColor Yellow
Write-Host "Domain: $(if($Domain) { $Domain } else { 'Not specified (will use IP)' })" -ForegroundColor Yellow
Write-Host "=" * 60

# Check prerequisites
Write-Host "`n🔍 Checking prerequisites..." -ForegroundColor Cyan

# Check AWS CLI
try {
    $awsVersion = aws --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ AWS CLI: $awsVersion" -ForegroundColor Green
    } else {
        throw "AWS CLI not found"
    }
} catch {
    Write-Host "❌ AWS CLI not found" -ForegroundColor Red
    exit 1
}

# Check credentials
try {
    $identity = aws sts get-caller-identity --profile $ProfileName --output json | ConvertFrom-Json
    Write-Host "✅ AWS Account: $($identity.Account)" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS credentials invalid for profile: $ProfileName" -ForegroundColor Red
    exit 1
}

# Get latest Ubuntu 22.04 AMI
Write-Host "`n🖼️ Finding Ubuntu 22.04 LTS AMI..." -ForegroundColor Cyan
try {
    $amiResult = aws ec2 describe-images `
        --owners 099720109477 `
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" `
        --query 'Images[*].[ImageId,Name,CreationDate]' `
        --output text `
        --region $Region `
        --profile $ProfileName | Sort-Object { $_[2] } -Descending | Select-Object -First 1
    
    $amiId = ($amiResult -split "`t")[0]
    $amiName = ($amiResult -split "`t")[1]
    
    Write-Host "✅ Found AMI: $amiId" -ForegroundColor Green
    Write-Host "   Name: $amiName" -ForegroundColor White
} catch {
    Write-Host "❌ Failed to find Ubuntu AMI" -ForegroundColor Red
    exit 1
}

# Create or check key pair
if ($CreateKeyPair) {
    Write-Host "`n🔑 Setting up EC2 Key Pair..." -ForegroundColor Cyan
    try {
        $keyCheck = aws ec2 describe-key-pairs --key-names $KeyPairName --region $Region --profile $ProfileName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Key pair already exists: $KeyPairName" -ForegroundColor Green
        } else {
            Write-Host "Creating new key pair..." -ForegroundColor Yellow
            $keyResult = aws ec2 create-key-pair --key-name $KeyPairName --region $Region --profile $ProfileName --output json | ConvertFrom-Json
            
            # Save private key
            $keyResult.KeyMaterial | Out-File -FilePath "$KeyPairName.pem" -Encoding ascii
            Write-Host "✅ Key pair created: $KeyPairName" -ForegroundColor Green
            Write-Host "   Private key saved to: $KeyPairName.pem" -ForegroundColor White
            Write-Host "   Keep this file secure!" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Failed to create key pair" -ForegroundColor Red
        exit 1
    }
}

# Create or check security group
if ($CreateSecurityGroup) {
    Write-Host "`n🛡️ Setting up Security Group..." -ForegroundColor Cyan
    try {
        $sgCheck = aws ec2 describe-security-groups --group-names $SecurityGroupName --region $Region --profile $ProfileName 2>$null
        if ($LASTEXITCODE -eq 0) {
            $sgInfo = $sgCheck | ConvertFrom-Json
            $securityGroupId = $sgInfo.SecurityGroups[0].GroupId
            Write-Host "✅ Security group already exists: $SecurityGroupName ($securityGroupId)" -ForegroundColor Green
        } else {
            Write-Host "Creating new security group..." -ForegroundColor Yellow
            
            # Get default VPC
            $vpcResult = aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region $Region --profile $ProfileName --output json | ConvertFrom-Json
            $vpcId = $vpcResult.Vpcs[0].VpcId
            
            # Create security group
            $sgResult = aws ec2 create-security-group --group-name $SecurityGroupName --description "ODIADEV TTS API Security Group" --vpc-id $vpcId --region $Region --profile $ProfileName --output json | ConvertFrom-Json
            $securityGroupId = $sgResult.GroupId
            
            # Add rules
            aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $Region --profile $ProfileName | Out-Null
            aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $Region --profile $ProfileName | Out-Null
            aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $Region --profile $ProfileName | Out-Null
            
            Write-Host "✅ Security group created: $SecurityGroupName ($securityGroupId)" -ForegroundColor Green
            Write-Host "   Ports opened: 22 (SSH), 80 (HTTP), 443 (HTTPS)" -ForegroundColor White
        }
    } catch {
        Write-Host "❌ Failed to create security group" -ForegroundColor Red
        exit 1
    }
}

# Create user data script
Write-Host "`n📝 Preparing user data script..." -ForegroundColor Cyan

$userData = @"
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# Install Caddy
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy -y

# Create application directory
mkdir -p /opt/odiadev-tts
cd /opt/odiadev-tts

# Create environment file
cat > .env << 'EOF'
PORT=3000
LOG_LEVEL=info
ALLOWED_ORIGINS=https://*
ADMIN_TOKEN=PLACEHOLDER_ADMIN_TOKEN
SUPABASE_URL=PLACEHOLDER_SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=PLACEHOLDER_SUPABASE_KEY
AWS_REGION=af-south-1
S3_BUCKET_TTS=odiadev-tts-artifacts-af-south-1
TTS_ENGINE=coqui
COQUI_MODEL_NAME=tts_models/en/vctk/vits
EOF

# Configure Caddy
if [ -n "$DOMAIN_PLACEHOLDER" ]; then
cat > /etc/caddy/Caddyfile << 'EOF'
$DOMAIN_PLACEHOLDER {
    reverse_proxy localhost:3000
    
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Rate limiting
    rate_limit {
        zone api {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF
else
cat > /etc/caddy/Caddyfile << 'EOF'
:80, :443 {
    reverse_proxy localhost:3000
    
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Rate limiting
    rate_limit {
        zone api {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF
fi

# Create log directory
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy

# Login to ECR and pull image
aws ecr get-login-password --region af-south-1 | docker login --username AWS --password-stdin $ECR_REGISTRY_PLACEHOLDER

# Pull and run the TTS API container
docker pull $IMAGE_URI_PLACEHOLDER

# Create docker-compose file for easier management
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  tts-api:
    image: $IMAGE_URI_PLACEHOLDER
    container_name: odiadev-tts
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
EOF

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start services
systemctl enable caddy
systemctl start caddy

# Start TTS API container
docker-compose up -d

# Wait for container to be healthy
echo "Waiting for TTS API to be ready..."
timeout 120 bash -c 'until docker exec odiadev-tts curl -f http://localhost:3000/health; do sleep 5; done'

# Create deployment info
cat > /opt/odiadev-tts/deployment-info.json << 'EOF'
{
  "deployment_time": "\$(date -Iseconds)",
  "image_uri": "$IMAGE_URI_PLACEHOLDER",
  "domain": "$DOMAIN_PLACEHOLDER",
  "instance_type": "$INSTANCE_TYPE_PLACEHOLDER",
  "region": "af-south-1",
  "services": {
    "caddy": "running",
    "docker": "running",
    "tts-api": "running"
  }
}
EOF

echo "🎉 ODIADEV TTS API deployment completed successfully!"
echo "📊 Check deployment status: cat /opt/odiadev-tts/deployment-info.json"
echo "📝 View logs: docker logs odiadev-tts"
echo "🔍 Test health: curl http://localhost:3000/health"
"@

# Replace placeholders
$userData = $userData.Replace('$IMAGE_URI_PLACEHOLDER', $ImageUri)
$userData = $userData.Replace('$DOMAIN_PLACEHOLDER', $Domain)
$userData = $userData.Replace('$INSTANCE_TYPE_PLACEHOLDER', $InstanceType)
$userData = $userData.Replace('$ECR_REGISTRY_PLACEHOLDER', ($ImageUri -split '/')[0])

# Encode user data
$userDataEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userData))

# Launch EC2 instance
Write-Host "`n🚀 Launching EC2 instance..." -ForegroundColor Cyan
try {
    $runResult = aws ec2 run-instances `
        --image-id $amiId `
        --count 1 `
        --instance-type $InstanceType `
        --key-name $KeyPairName `
        --security-groups $SecurityGroupName `
        --user-data $userDataEncoded `
        --region $Region `
        --profile $ProfileName `
        --output json | ConvertFrom-Json
    
    $instanceId = $runResult.Instances[0].InstanceId
    Write-Host "✅ Instance launched: $instanceId" -ForegroundColor Green
    
    # Tag the instance
    aws ec2 create-tags --resources $instanceId --tags Key=Name,Value=$InstanceName --region $Region --profile $ProfileName | Out-Null
    aws ec2 create-tags --resources $instanceId --tags Key=Project,Value="ODIADEV-TTS" --region $Region --profile $ProfileName | Out-Null
    
    Write-Host "✅ Instance tagged with name: $InstanceName" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to launch EC2 instance" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Wait for instance to be running
Write-Host "`n⏳ Waiting for instance to be running..." -ForegroundColor Cyan
do {
    Start-Sleep 10
    $instanceState = aws ec2 describe-instances --instance-ids $instanceId --region $Region --profile $ProfileName --query 'Reservations[0].Instances[0].State.Name' --output text
    Write-Host "   Instance state: $instanceState" -ForegroundColor Gray
} while ($instanceState -ne "running")

# Get instance details
$instanceInfo = aws ec2 describe-instances --instance-ids $instanceId --region $Region --profile $ProfileName --output json | ConvertFrom-Json
$instance = $instanceInfo.Reservations[0].Instances[0]
$publicIp = $instance.PublicIpAddress
$privateIp = $instance.PrivateIpAddress

Write-Host "`n🎯 Instance Details:" -ForegroundColor Cyan
Write-Host "   Instance ID: $instanceId" -ForegroundColor White
Write-Host "   Public IP: $publicIp" -ForegroundColor White
Write-Host "   Private IP: $privateIp" -ForegroundColor White
Write-Host "   Instance Type: $InstanceType" -ForegroundColor White
Write-Host "   Security Group: $SecurityGroupName" -ForegroundColor White

# Wait for initialization to complete
Write-Host "`n⏳ Waiting for application deployment (this may take 5-10 minutes)..." -ForegroundColor Cyan
Write-Host "   Installing Docker, Caddy, and TTS API..." -ForegroundColor Yellow

$deploymentReady = $false
$maxAttempts = 30
$attempt = 1

while (-not $deploymentReady -and $attempt -le $maxAttempts) {
    try {
        Start-Sleep 20
        $healthCheck = Invoke-RestMethod -Uri "http://${publicIp}/health" -TimeoutSec 5 -ErrorAction Stop
        if ($healthCheck.status -eq "ok") {
            $deploymentReady = $true
            Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
        }
    } catch {
        Write-Host "   Attempt $attempt/$maxAttempts - Still deploying..." -ForegroundColor Gray
        $attempt++
    }
}

if (-not $deploymentReady) {
    Write-Host "`n⚠️  Deployment may still be in progress" -ForegroundColor Yellow
    Write-Host "   Check manually: http://${publicIp}/health" -ForegroundColor White
    Write-Host "   SSH to debug: ssh -i $KeyPairName.pem ubuntu@$publicIp" -ForegroundColor White
}

# Save deployment information
$deploymentData = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    instanceId = $instanceId
    publicIp = $publicIp
    privateIp = $privateIp
    domain = $Domain
    imageUri = $ImageUri
    region = $Region
    instanceType = $InstanceType
    keyPair = $KeyPairName
    securityGroup = $SecurityGroupName
    healthEndpoint = "http://${publicIp}/health"
    httpsEndpoint = if ($Domain) { "https://$Domain" } else { "https://$publicIp" }
} | ConvertTo-Json -Depth 3

$deploymentData | Out-File -FilePath "ec2-deployment.json" -Encoding utf8

Write-Host "`n🎯 Deployment Summary:" -ForegroundColor Cyan
Write-Host "=" * 50
Write-Host "✅ Instance ID: $instanceId" -ForegroundColor Green
Write-Host "✅ Public IP: $publicIp" -ForegroundColor Green
Write-Host "✅ Health Check: http://${publicIp}/health" -ForegroundColor Green
if ($Domain) {
    Write-Host "✅ Domain: https://$Domain" -ForegroundColor Green
} else {
    Write-Host "✅ HTTPS: https://$publicIp" -ForegroundColor Green
}
Write-Host "✅ SSH Access: ssh -i $KeyPairName.pem ubuntu@$publicIp" -ForegroundColor Green

Write-Host "`n📄 Deployment info saved to: ec2-deployment.json" -ForegroundColor Cyan

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure DNS A record (if using domain):" -ForegroundColor White
Write-Host "     $Domain -> $publicIp" -ForegroundColor Gray
Write-Host "  2. Test API endpoints:" -ForegroundColor White
Write-Host "     curl http://${publicIp}/health" -ForegroundColor Gray
Write-Host "  3. Configure environment variables via SSH if needed" -ForegroundColor White
Write-Host "  4. Run end-to-end tests" -ForegroundColor White
Write-Host ""

Write-Host "🎉 EC2 deployment completed!" -ForegroundColor Green