# scripts\deploy-ecr.ps1
# ECR Deployment Script for ODIADEV TTS API

param(
    [string]$Region = "af-south-1",
    [string]$ProfileName = "odiadev",
    [string]$RepositoryName = "odiadev/tts",
    [string]$ImageTag = "v0.1.0",
    [string]$LocalImageName = "odiadev/tts:local",
    [switch]$CreateRepo = $true,
    [switch]$PushImage = $true
)

$ErrorActionPreference = "Stop"

Write-Host "🐳 ODIADEV TTS API - ECR Deployment" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Repository: $RepositoryName" -ForegroundColor Yellow
Write-Host "Tag: $ImageTag" -ForegroundColor Yellow
Write-Host "=" * 50

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
    Write-Host "❌ AWS CLI not found or not configured" -ForegroundColor Red
    Write-Host "   Please install AWS CLI and run .\scripts\setup-aws.ps1" -ForegroundColor Yellow
    exit 1
}

# Check Docker
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
    } else {
        throw "Docker not found"
    }
} catch {
    Write-Host "❌ Docker not found or not running" -ForegroundColor Red
    Write-Host "   Please install Docker Desktop and ensure it's running" -ForegroundColor Yellow
    exit 1
}

# Check AWS credentials
Write-Host "`n🔑 Verifying AWS credentials..." -ForegroundColor Cyan
try {
    $identity = aws sts get-caller-identity --profile $ProfileName --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ AWS Profile: $ProfileName" -ForegroundColor Green
        Write-Host "   Account: $($identity.Account)" -ForegroundColor White
        Write-Host "   User: $($identity.Arn)" -ForegroundColor White
    } else {
        throw "AWS credentials invalid"
    }
} catch {
    Write-Host "❌ AWS credentials not valid for profile: $ProfileName" -ForegroundColor Red
    Write-Host "   Please run .\scripts\setup-aws.ps1 to configure" -ForegroundColor Yellow
    exit 1
}

# Check if local Docker image exists
Write-Host "`n🖼️ Checking local Docker image..." -ForegroundColor Cyan
try {
    $imageCheck = docker image inspect $LocalImageName 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Local image found: $LocalImageName" -ForegroundColor Green
        $imageSize = [math]::Round($imageCheck.Size / 1MB, 1)
        Write-Host "   Size: ${imageSize}MB" -ForegroundColor White
        Write-Host "   Created: $($imageCheck.Created)" -ForegroundColor White
    } else {
        throw "Local image not found"
    }
} catch {
    Write-Host "❌ Local Docker image not found: $LocalImageName" -ForegroundColor Red
    Write-Host "   Please build the image first:" -ForegroundColor Yellow
    Write-Host "   docker build -t $LocalImageName -f server/Dockerfile ." -ForegroundColor Gray
    exit 1
}

# Get AWS account ID and construct ECR URI
$accountId = $identity.Account
$ecrUri = "$accountId.dkr.ecr.$Region.amazonaws.com/$RepositoryName"

Write-Host "`n📦 ECR Configuration:" -ForegroundColor Cyan
Write-Host "   Account ID: $accountId" -ForegroundColor White
Write-Host "   ECR URI: $ecrUri" -ForegroundColor White
Write-Host "   Full Image URI: ${ecrUri}:${ImageTag}" -ForegroundColor White

# Create ECR repository if requested
if ($CreateRepo) {
    Write-Host "`n🏗️ Creating ECR repository..." -ForegroundColor Cyan
    try {
        $repoCheck = aws ecr describe-repositories --repository-names $RepositoryName --region $Region --profile $ProfileName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ ECR repository already exists" -ForegroundColor Green
        } else {
            # Create repository
            Write-Host "Creating new ECR repository..." -ForegroundColor Yellow
            $createResult = aws ecr create-repository --repository-name $RepositoryName --region $Region --profile $ProfileName --output json | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ ECR repository created successfully" -ForegroundColor Green
                Write-Host "   Repository URI: $($createResult.repository.repositoryUri)" -ForegroundColor White
            } else {
                throw "Failed to create ECR repository"
            }
        }
    } catch {
        Write-Host "❌ Failed to create ECR repository" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Please check your AWS permissions" -ForegroundColor Yellow
        exit 1
    }
}

# Login to ECR
Write-Host "`n🔐 Logging into ECR..." -ForegroundColor Cyan
try {
    $loginResult = aws ecr get-login-password --region $Region --profile $ProfileName | docker login --username AWS --password-stdin $accountId.dkr.ecr.$Region.amazonaws.com 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ECR login successful" -ForegroundColor Green
    } else {
        throw "ECR login failed: $loginResult"
    }
} catch {
    Write-Host "❌ Failed to login to ECR" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Tag the image for ECR
Write-Host "`n🏷️ Tagging image for ECR..." -ForegroundColor Cyan
$fullImageUri = "${ecrUri}:${ImageTag}"
try {
    docker tag $LocalImageName $fullImageUri 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Image tagged: $fullImageUri" -ForegroundColor Green
    } else {
        throw "Failed to tag image"
    }
} catch {
    Write-Host "❌ Failed to tag image" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Push image to ECR
if ($PushImage) {
    Write-Host "`n🚀 Pushing image to ECR..." -ForegroundColor Cyan
    Write-Host "This may take several minutes depending on image size and connection speed..." -ForegroundColor Yellow
    
    try {
        $pushOutput = docker push $fullImageUri 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Image pushed successfully to ECR!" -ForegroundColor Green
            Write-Host "   Image URI: $fullImageUri" -ForegroundColor White
        } else {
            throw "Failed to push image: $pushOutput"
        }
    } catch {
        Write-Host "❌ Failed to push image to ECR" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify image in ECR
Write-Host "`n✅ Verifying image in ECR..." -ForegroundColor Cyan
try {
    $images = aws ecr list-images --repository-name $RepositoryName --region $Region --profile $ProfileName --output json | ConvertFrom-Json
    $targetImage = $images.imageIds | Where-Object { $_.imageTag -eq $ImageTag }
    
    if ($targetImage) {
        Write-Host "✅ Image verified in ECR" -ForegroundColor Green
        Write-Host "   Tag: $($targetImage.imageTag)" -ForegroundColor White
        Write-Host "   Digest: $($targetImage.imageDigest)" -ForegroundColor White
        
        # Get image details
        $imageDetails = aws ecr describe-images --repository-name $RepositoryName --image-ids imageTag=$ImageTag --region $Region --profile $ProfileName --output json | ConvertFrom-Json
        $imageSizeMB = [math]::Round($imageDetails.imageDetails[0].imageSizeInBytes / 1MB, 1)
        Write-Host "   Size: ${imageSizeMB}MB" -ForegroundColor White
        Write-Host "   Pushed: $($imageDetails.imageDetails[0].imagePushedAt)" -ForegroundColor White
    } else {
        Write-Host "⚠️  Image not found in ECR (push may have failed)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not verify image in ECR" -ForegroundColor Yellow
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Output summary
Write-Host "`n🎯 ECR Deployment Summary:" -ForegroundColor Cyan
Write-Host "=" * 50
Write-Host "✅ ECR Repository: $RepositoryName" -ForegroundColor Green
Write-Host "✅ Image URI: $fullImageUri" -ForegroundColor Green
Write-Host "✅ Region: $Region" -ForegroundColor Green
Write-Host "✅ Account: $accountId" -ForegroundColor Green

# Save deployment info for later use
$deploymentInfo = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    region = $Region
    accountId = $accountId
    repositoryName = $RepositoryName
    imageTag = $ImageTag
    imageUri = $fullImageUri
    ecrUri = $ecrUri
} | ConvertTo-Json -Depth 3

$deploymentInfo | Out-File -FilePath "deployment-info.json" -Encoding utf8
Write-Host "`n📄 Deployment info saved to: deployment-info.json" -ForegroundColor Cyan

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run EC2 deployment script:" -ForegroundColor White
Write-Host "     .\scripts\deploy-ec2.ps1 -ImageUri '$fullImageUri'" -ForegroundColor Gray
Write-Host "  2. Configure DNS and SSL" -ForegroundColor White
Write-Host "  3. Run end-to-end tests" -ForegroundColor White
Write-Host ""

# Clean up local tagged image to save space
Write-Host "🧹 Cleaning up local tagged image..." -ForegroundColor Gray
try {
    docker rmi $fullImageUri 2>$null
    Write-Host "Local ECR-tagged image removed (original local image preserved)" -ForegroundColor Gray
} catch {
    # Ignore cleanup errors
}

Write-Host "`n🎉 ECR deployment completed successfully!" -ForegroundColor Green