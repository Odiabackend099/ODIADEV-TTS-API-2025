# ODIADEV TTS API - Enhanced Deployment Script
# Built for Nigeria, Optimized for the World 🇳🇬

param(
    [string]$Environment = "development",
    [string]$Port = "5000",
    [switch]$InstallDependencies,
    [switch]$RunTests,
    [switch]$DeployProduction,
    [switch]$Help
)

# Colors for output
$Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Header = "Magenta"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Colors[$Color]
}

function Show-Header {
    Write-ColorOutput "`n🚀 ODIADEV TTS API - Enhanced Deployment" "Header"
    Write-ColorOutput "🇳🇬 Built for Nigeria, Optimized for the World" "Info"
    Write-ColorOutput "=================================================" "Info"
}

function Show-Help {
    Write-ColorOutput "`nUsage: .\deploy_enhanced.ps1 [Options]" "Info"
    Write-ColorOutput "`nOptions:" "Info"
    Write-ColorOutput "  -Environment <env>     Environment (development/production) [default: development]" "Info"
    Write-ColorOutput "  -Port <port>           Port number [default: 5000]" "Info"
    Write-ColorOutput "  -InstallDependencies    Install Python dependencies" "Info"
    Write-ColorOutput "  -RunTests              Run comprehensive test suite" "Info"
    Write-ColorOutput "  -DeployProduction      Deploy to production mode" "Info"
    Write-ColorOutput "  -Help                  Show this help message" "Info"
    Write-ColorOutput "`nExamples:" "Info"
    Write-ColorOutput "  .\deploy_enhanced.ps1 -InstallDependencies -RunTests" "Info"
    Write-ColorOutput "  .\deploy_enhanced.ps1 -Environment production -Port 5001" "Info"
    Write-ColorOutput "  .\deploy_enhanced.ps1 -DeployProduction" "Info"
}

function Test-PythonInstallation {
    Write-ColorOutput "`n🔍 Checking Python installation..." "Info"
    
    try {
        $pythonVersion = py --version 2>$null
        if ($pythonVersion) {
            Write-ColorOutput "✅ Python found: $pythonVersion" "Success"
            return $true
        }
    }
    catch {
        try {
            $pythonVersion = python --version 2>$null
            if ($pythonVersion) {
                Write-ColorOutput "✅ Python found: $pythonVersion" "Success"
                return $true
            }
        }
        catch {
            Write-ColorOutput "❌ Python not found. Please install Python 3.8+ and try again." "Error"
            return $false
        }
    }
    
    Write-ColorOutput "❌ Python not found. Please install Python 3.8+ and try again." "Error"
    return $false
}

function Install-Dependencies {
    Write-ColorOutput "`n📦 Installing Python dependencies..." "Info"
    
    try {
        # Check if requirements.txt exists
        if (-not (Test-Path "requirements.txt")) {
            Write-ColorOutput "❌ requirements.txt not found!" "Error"
            return $false
        }
        
        # Install dependencies
        Write-ColorOutput "Installing packages from requirements.txt..." "Info"
        py -m pip install -r requirements.txt
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Dependencies installed successfully!" "Success"
            return $true
        } else {
            Write-ColorOutput "❌ Failed to install dependencies!" "Error"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Error installing dependencies: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-EnvironmentSetup {
    Write-ColorOutput "`n🔧 Checking environment setup..." "Info"
    
    # Check for .env file
    if (-not (Test-Path ".env")) {
        Write-ColorOutput "⚠️  .env file not found. Creating template..." "Warning"
        
        $envContent = @"
# ODIADEV TTS API Environment Configuration
# 🇳🇬 Nigerian Network Optimizations Enabled

# Required Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Optional Configuration
SECRET_KEY=your_secret_key_here
FLASK_ENV=$Environment
MINIMAX_TTS_JWT_TOKEN=your_minimax_token_here
MINIMAX_TTS_VOICE_ID=your_voice_id_here
MINIMAX_TTS_GROUP_ID=your_group_id_here

# Nigerian Network Settings
NIGERIAN_NETWORK_TIMEOUT=30
NIGERIAN_NETWORK_MAX_RETRIES=3
NIGERIAN_NETWORK_RETRY_DELAYS=250,500,1000
"@
        
        $envContent | Out-File -FilePath ".env" -Encoding UTF8
        Write-ColorOutput "✅ .env template created. Please edit with your API keys." "Success"
    } else {
        Write-ColorOutput "✅ .env file found" "Success"
    }
    
    # Check for database directory
    if (-not (Test-Path "database")) {
        Write-ColorOutput "📁 Creating database directory..." "Info"
        New-Item -ItemType Directory -Path "database" -Force | Out-Null
        Write-ColorOutput "✅ Database directory created" "Success"
    }
    
    # Check for static directory
    if (-not (Test-Path "static")) {
        Write-ColorOutput "📁 Creating static directory..." "Info"
        New-Item -ItemType Directory -Path "static" -Force | Out-Null
        Write-ColorOutput "✅ Static directory created" "Success"
    }
}

function Run-TestSuite {
    Write-ColorOutput "`n🧪 Running comprehensive test suite..." "Info"
    
    try {
        # Check if pytest is installed
        $pytestCheck = py -m pytest --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "📦 Installing pytest..." "Info"
            py -m pip install pytest
        }
        
        Write-ColorOutput "Running Nigerian network optimizations tests..." "Info"
        py -m pytest tests/test_enhanced_api.py::TestNigerianNetworkOptimizations -v
        
        Write-ColorOutput "Running API functionality tests..." "Info"
        py -m pytest tests/test_enhanced_api.py::TestEnhancedODIADEVAPI -v
        
        Write-ColorOutput "Running all tests..." "Info"
        py -m pytest tests/ -v
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ All tests passed!" "Success"
            return $true
        } else {
            Write-ColorOutput "❌ Some tests failed!" "Error"
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Error running tests: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Start-Application {
    param(
        [string]$Environment,
        [string]$Port
    )
    
    Write-ColorOutput "`n🚀 Starting ODIADEV TTS API..." "Info"
    Write-ColorOutput "Environment: $Environment" "Info"
    Write-ColorOutput "Port: $Port" "Info"
    Write-ColorOutput "Nigerian Network Optimizations: ✅ Enabled" "Success"
    
    # Set environment variables
    $env:FLASK_ENV = $Environment
    $env:PORT = $Port
    
    # Choose the appropriate main file
    if ($Environment -eq "production" -or $Port -eq "5001") {
        $mainFile = "main_5001.py"
        Write-ColorOutput "Using production configuration (main_5001.py)" "Info"
    } else {
        $mainFile = "main.py"
        Write-ColorOutput "Using development configuration (main.py)" "Info"
    }
    
    try {
        Write-ColorOutput "`n🎯 Starting server on http://localhost:$Port" "Success"
        Write-ColorOutput "📊 Health check: http://localhost:$Port/health" "Info"
        Write-ColorOutput "🌐 Network test: http://localhost:$Port/api/network-test" "Info"
        Write-ColorOutput "📚 API docs: Check README_ENHANCED.md for full documentation" "Info"
        Write-ColorOutput "`n🇳🇬 Optimized for Nigerian networks (MTN/Airtel)" "Success"
        Write-ColorOutput "Press Ctrl+C to stop the server" "Warning"
        
        # Start the application
        py $mainFile
    }
    catch {
        Write-ColorOutput "❌ Error starting application: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-APIEndpoints {
    Write-ColorOutput "`n🔍 Testing API endpoints..." "Info"
    
    $baseUrl = "http://localhost:$Port"
    
    try {
        # Test health endpoint
        Write-ColorOutput "Testing health endpoint..." "Info"
        $healthResponse = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing
        if ($healthResponse.StatusCode -eq 200) {
            Write-ColorOutput "✅ Health endpoint working" "Success"
        } else {
            Write-ColorOutput "❌ Health endpoint failed" "Error"
        }
        
        # Test network diagnostics
        Write-ColorOutput "Testing network diagnostics..." "Info"
        $networkResponse = Invoke-WebRequest -Uri "$baseUrl/api/network-test" -UseBasicParsing
        if ($networkResponse.StatusCode -eq 200) {
            Write-ColorOutput "✅ Network diagnostics working" "Success"
        } else {
            Write-ColorOutput "❌ Network diagnostics failed" "Error"
        }
        
        Write-ColorOutput "✅ API endpoints tested successfully!" "Success"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Error testing API endpoints: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-NigerianOptimizations {
    Write-ColorOutput "`n🇳🇬 Nigerian Network Optimizations:" "Header"
    Write-ColorOutput "=================================" "Info"
    Write-ColorOutput "✅ 3-Tier Exponential Backoff (250ms/500ms/1000ms)" "Success"
    Write-ColorOutput "✅ Enhanced Timeouts (30 seconds)" "Success"
    Write-ColorOutput "✅ Request Size Limits (1MB)" "Success"
    Write-ColorOutput "✅ Nigerian Phone Validation (080/081/070/071/090/091)" "Success"
    Write-ColorOutput "✅ Network Diagnostics Endpoint" "Success"
    Write-ColorOutput "✅ Graceful Degradation" "Success"
    Write-ColorOutput "✅ Input Sanitization" "Success"
    Write-ColorOutput "✅ Request ID Tracking" "Success"
    Write-ColorOutput "✅ Comprehensive Error Handling" "Success"
}

# Main execution
Show-Header

if ($Help) {
    Show-Help
    exit 0
}

# Check Python installation
if (-not (Test-PythonInstallation)) {
    Write-ColorOutput "`n❌ Deployment failed: Python not available" "Error"
    exit 1
}

# Install dependencies if requested
if ($InstallDependencies) {
    if (-not (Install-Dependencies)) {
        Write-ColorOutput "`n❌ Deployment failed: Dependencies installation failed" "Error"
        exit 1
    }
}

# Test environment setup
Test-EnvironmentSetup

# Run tests if requested
if ($RunTests) {
    if (-not (Run-TestSuite)) {
        Write-ColorOutput "`n❌ Deployment failed: Tests failed" "Error"
        exit 1
    }
}

# Show Nigerian optimizations
Show-NigerianOptimizations

# Start application
Start-Application -Environment $Environment -Port $Port
