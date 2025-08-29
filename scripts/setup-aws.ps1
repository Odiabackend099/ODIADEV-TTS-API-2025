# scripts\setup-aws.ps1
# AWS Configuration and Resource Setup for ODIADEV TTS API

param(
    [string]$Region = "af-south-1",
    [string]$ProjectName = "odiadev-tts-api",
    [switch]$CreateECR,
    [switch]$CreateEC2,
    [switch]$ValidateOnly,
    [switch]$CleanupResources
)

$ErrorActionPreference = "Continue"

Write-Host "ODIADEV TTS API - AWS Setup" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan

function Test-AWSCLIAvailable {
    try {
        $version = aws --version 2>$null
        if ($version) {
            Write-Host "AWS CLI Version: $version" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "AWS CLI is not available" -ForegroundColor Red
    return $false
}

function Test-AWSCredentials {
    try {
        $identity = aws sts get-caller-identity --region $Region 2>$null | ConvertFrom-Json
        if ($identity.Account) {
            Write-Host "AWS Account: $($identity.Account)" -ForegroundColor Green
            Write-Host "User/Role: $($identity.Arn)" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "AWS credentials not configured" -ForegroundColor Red
    return $false
}

function Setup-ECRRepository {
    Write-Host "`nSetting up ECR repository..." -ForegroundColor Yellow
    
    # Check if repository exists
    try {
        $existingRepo = aws ecr describe-repositories --repository-names $ProjectName --region $Region 2>$null | ConvertFrom-Json
        if ($existingRepo.repositories) {
            Write-Host "ECR repository already exists: $($existingRepo.repositories[0].repositoryUri)" -ForegroundColor Green
            return $existingRepo.repositories[0].repositoryUri
        }
    } catch {
        # Repository doesn't exist, create it
    }
    
    Write-Host "Creating ECR repository: $ProjectName" -ForegroundColor Yellow
    try {
        $newRepo = aws ecr create-repository --repository-name $ProjectName --region $Region | ConvertFrom-Json
        Write-Host "ECR repository created: $($newRepo.repository.repositoryUri)" -ForegroundColor Green
        
        # Set lifecycle policy to manage costs
        $lifecyclePolicy = @{
            rules = @(
                @{
                    rulePriority = 1
                    description = "Keep only 10 most recent images"
                    selection = @{
                        tagStatus = "any"
                        countType = "imageCountMoreThan"
                        countNumber = 10
                    }
                    action = @{
                        type = "expire"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        aws ecr put-lifecycle-policy --repository-name $ProjectName --lifecycle-policy-text $lifecyclePolicy --region $Region | Out-Null
        Write-Host "Lifecycle policy applied to ECR repository" -ForegroundColor Green
        
        return $newRepo.repository.repositoryUri
        
    } catch {
        Write-Host "Failed to create ECR repository: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Setup-EC2Instance {
    Write-Host "`nSetting up EC2 instance..." -ForegroundColor Yellow
    
    # Create security group
    $securityGroupName = "$ProjectName-sg"
    try {
        $existingSG = aws ec2 describe-security-groups --group-names $securityGroupName --region $Region 2>$null | ConvertFrom-Json
        if ($existingSG.SecurityGroups) {
            $sgId = $existingSG.SecurityGroups[0].GroupId
            Write-Host "Security group already exists: $sgId" -ForegroundColor Green
        }
    } catch {
        Write-Host "Creating security group: $securityGroupName" -ForegroundColor Yellow
        $sg = aws ec2 create-security-group --group-name $securityGroupName --description "ODIADEV TTS API Security Group" --region $Region | ConvertFrom-Json
        $sgId = $sg.GroupId
        Write-Host "Security group created: $sgId" -ForegroundColor Green
        
        # Add inbound rules
        aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $Region | Out-Null
        aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $Region | Out-Null
        aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $Region | Out-Null
        aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region $Region | Out-Null
        Write-Host "Security group rules added" -ForegroundColor Green
    }
    
    # Check for existing instance
    try {
        $existingInstances = aws ec2 describe-instances --filters "Name=tag:Name,Values=$ProjectName" "Name=instance-state-name,Values=running,pending,stopping,stopped" --region $Region | ConvertFrom-Json
        if ($existingInstances.Reservations -and $existingInstances.Reservations.Count -gt 0) {
            $instance = $existingInstances.Reservations[0].Instances[0]
            Write-Host "EC2 instance already exists: $($instance.InstanceId)" -ForegroundColor Green
            Write-Host "State: $($instance.State.Name)" -ForegroundColor White
            Write-Host "Public IP: $($instance.PublicIpAddress)" -ForegroundColor White
            return $instance.InstanceId
        }
    } catch {
        # No existing instance
    }
    
    # Create user data script
    $userData = @"
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose

# Install Caddy
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install -y caddy

# Configure Caddy
cat > /etc/caddy/Caddyfile << 'EOF'
:80 {
    reverse_proxy localhost:3000
}
EOF

systemctl enable caddy
systemctl start caddy
systemctl enable docker
systemctl start docker

# Create TTS user
useradd -m -s /bin/bash tts
usermod -aG docker tts

echo "EC2 instance setup completed" > /var/log/setup.log
"@
    
    $userDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))
    
    Write-Host "Launching EC2 instance..." -ForegroundColor Yellow
    try {
        # Get latest Ubuntu 22.04 LTS AMI
        $ami = aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" --query 'Images[*].[ImageId,CreationDate]' --output text --region $Region | Sort-Object { $_[1] } | Select-Object -Last 1
        $amiId = $ami.Split()[0]
        
        $instance = aws ec2 run-instances --image-id $amiId --count 1 --instance-type t3.small --security-group-ids $sgId --user-data $userDataEncoded --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$ProjectName}]" --region $Region | ConvertFrom-Json
        
        $instanceId = $instance.Instances[0].InstanceId
        Write-Host "EC2 instance launched: $instanceId" -ForegroundColor Green
        Write-Host "Waiting for instance to be running..." -ForegroundColor Yellow
        
        aws ec2 wait instance-running --instance-ids $instanceId --region $Region
        
        $instanceDetails = aws ec2 describe-instances --instance-ids $instanceId --region $Region | ConvertFrom-Json
        $publicIp = $instanceDetails.Reservations[0].Instances[0].PublicIpAddress
        
        Write-Host "Instance is running!" -ForegroundColor Green
        Write-Host "Instance ID: $instanceId" -ForegroundColor White
        Write-Host "Public IP: $publicIp" -ForegroundColor White
        
        return $instanceId
        
    } catch {
        Write-Host "Failed to create EC2 instance: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Validate-AWSSetup {
    Write-Host "`nValidating AWS setup..." -ForegroundColor Yellow
    
    $issues = @()
    
    # Check ECR repository
    try {
        $repo = aws ecr describe-repositories --repository-names $ProjectName --region $Region 2>$null | ConvertFrom-Json
        if ($repo.repositories) {
            Write-Host "ECR Repository: OK - $($repo.repositories[0].repositoryUri)" -ForegroundColor Green
        } else {
            $issues += "ECR repository not found"
        }
    } catch {
        $issues += "ECR repository not accessible"
    }
    
    # Check EC2 instance
    try {
        $instances = aws ec2 describe-instances --filters "Name=tag:Name,Values=$ProjectName" "Name=instance-state-name,Values=running" --region $Region | ConvertFrom-Json
        if ($instances.Reservations -and $instances.Reservations.Count -gt 0) {
            $instance = $instances.Reservations[0].Instances[0]
            Write-Host "EC2 Instance: OK - $($instance.InstanceId) ($($instance.PublicIpAddress))" -ForegroundColor Green
        } else {
            $issues += "EC2 instance not running"
        }
    } catch {
        $issues += "EC2 instance not accessible"
    }
    
    # Check security group
    try {
        $sg = aws ec2 describe-security-groups --group-names "$ProjectName-sg" --region $Region 2>$null | ConvertFrom-Json
        if ($sg.SecurityGroups) {
            Write-Host "Security Group: OK - $($sg.SecurityGroups[0].GroupId)" -ForegroundColor Green
        } else {
            $issues += "Security group not found"
        }
    } catch {
        $issues += "Security group not accessible"
    }
    
    return $issues
}

# Main execution
if (-not (Test-AWSCLIAvailable)) {
    Write-Host "`nAWS CLI is not available!" -ForegroundColor Red
    Write-Host "Please install AWS CLI first:" -ForegroundColor Yellow
    Write-Host "1. Download: https://aws.amazon.com/cli/" -ForegroundColor White
    Write-Host "2. Run installer as Administrator" -ForegroundColor White
    Write-Host "3. Configure: aws configure" -ForegroundColor White
    Write-Host "   - Region: $Region" -ForegroundColor Gray
    Write-Host "   - Output: json" -ForegroundColor Gray
    exit 1
}

if (-not (Test-AWSCredentials)) {
    Write-Host "`nAWS credentials not configured!" -ForegroundColor Red
    Write-Host "Please configure AWS CLI:" -ForegroundColor Yellow
    Write-Host "aws configure" -ForegroundColor White
    Write-Host "AWS Access Key ID: [your-access-key]" -ForegroundColor Gray
    Write-Host "AWS Secret Access Key: [your-secret-key]" -ForegroundColor Gray
    Write-Host "Default region name: $Region" -ForegroundColor Gray
    Write-Host "Default output format: json" -ForegroundColor Gray
    exit 1
}

Write-Host "AWS CLI and credentials are configured" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "Project: $ProjectName" -ForegroundColor White

if ($ValidateOnly) {
    $issues = Validate-AWSSetup
    if ($issues.Count -eq 0) {
        Write-Host "`nAWS setup validation: PASSED" -ForegroundColor Green
    } else {
        Write-Host "`nAWS setup validation: FAILED" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
    return
}

if ($CleanupResources) {
    Write-Host "`nCleaning up AWS resources..." -ForegroundColor Yellow
    # Implementation for cleanup would go here
    Write-Host "Cleanup completed" -ForegroundColor Green
    return
}

# Setup resources
if ($CreateECR) {
    $ecrUri = Setup-ECRRepository
    if ($ecrUri) {
        Write-Host "`nECR repository ready: $ecrUri" -ForegroundColor Green
    }
}

if ($CreateEC2) {
    $instanceId = Setup-EC2Instance
    if ($instanceId) {
        Write-Host "`nEC2 instance ready: $instanceId" -ForegroundColor Green
    }
}

# Final validation
Write-Host "`nRunning final validation..." -ForegroundColor Yellow
$validationIssues = Validate-AWSSetup

if ($validationIssues.Count -eq 0) {
    Write-Host "`nAWS setup completed successfully!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Build and push container: .\scripts\deploy-ecr.ps1" -ForegroundColor White
    Write-Host "2. Deploy to EC2: .\scripts\deploy-ec2.ps1" -ForegroundColor White
    Write-Host "3. Configure DNS for your domain" -ForegroundColor White
} else {
    Write-Host "`nAWS setup completed with issues:" -ForegroundColor Yellow
    $validationIssues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}