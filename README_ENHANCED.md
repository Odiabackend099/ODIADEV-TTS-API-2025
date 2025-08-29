# 🚀 ODIADEV TTS API - Enhanced Edition

**Built for Nigeria, Optimized for the World** 🇳🇬

A production-ready Text-to-Speech API service built with Flask, featuring OpenAI TTS integration, comprehensive client management, and Nigerian network optimizations.

## 🌟 Key Features

### 🎯 Core Functionality
- **Text-to-Speech Generation**: OpenAI TTS integration with multiple voice options
- **Client Management**: Complete signup and deployment tracking system
- **Comprehensive Logging**: Detailed logging for all operations with request tracking
- **RESTful API**: Clean, well-documented API endpoints
- **Production Ready**: CORS enabled, error handling, and health checks

### 🇳🇬 Nigerian Network Optimizations
- **3-Tier Exponential Backoff**: 250ms/500ms/1000ms retry delays for MTN/Airtel
- **Enhanced Timeouts**: 30-second timeouts for slow connections
- **Request Size Limits**: 1MB limit optimized for Nigerian networks
- **Phone Number Validation**: Nigerian mobile number patterns (080, 081, 070, 071, 090, 091)
- **Network Diagnostics**: Built-in network testing endpoint
- **Offline-First Design**: Graceful degradation when services are unavailable

### 🛡️ Security & Reliability
- **Input Sanitization**: Protection against XSS and injection attacks
- **Rate Limiting**: Request throttling for API protection
- **Request ID Tracking**: Unique request IDs for debugging and monitoring
- **Comprehensive Error Handling**: Detailed error messages with context
- **Duplicate Prevention**: Phone number uniqueness validation

## 🚀 Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Set Environment Variables
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
OPENAI_API_KEY=your_openai_api_key_here
SECRET_KEY=your_secret_key_here
FLASK_ENV=development
```

### 3. Run the Application
```bash
# Development mode
python main.py

# Production mode (port 5001)
python main_5001.py
```

### 4. Test the API
```bash
# Run comprehensive tests
python -m pytest tests/test_enhanced_api.py -v

# Test individual endpoints
curl http://localhost:5000/health
```

## 📋 API Endpoints

### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "ODIADEV TTS API",
  "version": "1.0.0",
  "request_id": "abc12345",
  "timestamp": "2025-01-15T10:30:00"
}
```

### Text-to-Speech
```http
POST /api/tts
Content-Type: application/json

{
  "text": "Hello, world!",
  "voice": "alloy",
  "provider": "openai"
}
```

**Response:**
```json
{
  "success": true,
  "message": "TTS generation successful",
  "data": {
    "audio_base64": "base64_encoded_audio_data",
    "format": "mp3",
    "text": "Hello, world!",
    "voice": "alloy",
    "request_id": "abc12345",
    "provider": "openai",
    "size_bytes": 12345
  },
  "request_id": "abc12345",
  "timestamp": "2025-01-15T10:30:00"
}
```

### Client Signup
```http
POST /api/signup
Content-Type: application/json

{
  "full_name": "John Doe",
  "phone": "08012345678",
  "business_name": "My Business",
  "plan_tier": "starter",
  "voice_option": true
}
```

**Response:**
```json
{
  "success": true,
  "status": "success",
  "message": "Signup completed successfully",
  "client_id": 1,
  "deployment_status": "completed",
  "tts_generated": true,
  "request_id": "abc12345",
  "timestamp": "2025-01-15T10:30:00",
  "plan_details": {
    "tier": "starter",
    "price_naira": 8000,
    "features": [
      "Basic AI Agent",
      "Text-to-Speech (5 hours/month)",
      "Email Support",
      "Standard Response Time"
    ]
  },
  "welcome_audio": {
    "success": true,
    "audio_base64": "base64_encoded_welcome_audio",
    "format": "mp3",
    "text": "Welcome to ODIADEV, John Doe!...",
    "voice": "alloy",
    "request_id": "def67890",
    "provider": "openai"
  }
}
```

### Client Status
```http
GET /api/status/{client_id}
```

### System Logs
```http
GET /api/logs?limit=100&source=tts
```

### Network Diagnostics
```http
GET /api/network-test
```

**Response:**
```json
{
  "success": true,
  "network_test": {
    "https://api.openai.com/v1/models": {
      "status": 200,
      "response_time_ms": 1250.5,
      "success": true
    },
    "https://httpbin.org/get": {
      "status": 200,
      "response_time_ms": 850.2,
      "success": true
    }
  },
  "request_id": "abc12345",
  "timestamp": "2025-01-15T10:30:00",
  "nigerian_optimizations": {
    "retry_delays": [250, 500, 1000],
    "timeout": 30,
    "max_retries": 3,
    "request_size_limit": 1048576
  }
}
```

## 🏗️ Architecture

```
odiadev-tts-api/
├── main.py                 # Flask application entry point (port 5000)
├── main_5001.py            # Production entry point (port 5001)
├── src/
│   ├── models/            # Database models
│   │   ├── user.py        # User model and database setup
│   │   └── client.py      # Client, Deployment, Log models
│   └── routes/            # API route handlers
│       ├── user.py        # User management routes
│       └── odiadev.py     # Enhanced ODIADEV functionality
├── tests/
│   ├── test_api.py        # Basic API tests
│   └── test_enhanced_api.py # Comprehensive test suite
├── database/              # SQLite database storage
├── static/                # Static files
├── requirements.txt       # Python dependencies
└── README_ENHANCED.md     # This file
```

## 🇳🇬 Nigerian Network Optimizations

### Network Handling
- **Exponential Backoff**: Retry delays of 250ms, 500ms, and 1000ms
- **Increased Timeouts**: 30-second timeouts for slow connections
- **Request Size Limits**: 1MB maximum for Nigerian network conditions
- **Connection Pooling**: Efficient connection reuse

### Phone Number Validation
Supports all Nigerian mobile number patterns:
- **MTN**: 080, 081
- **Airtel**: 070, 071
- **9mobile**: 090, 091

### Error Handling
- **Graceful Degradation**: Fallback to mock services when external APIs fail
- **Detailed Logging**: Request ID tracking for debugging
- **User-Friendly Messages**: Clear error messages for Nigerian users

## 🧪 Testing

### Run All Tests
```bash
python -m pytest tests/ -v
```

### Run Specific Test Categories
```bash
# Functional tests
python -m pytest tests/test_enhanced_api.py::TestEnhancedODIADEVAPI -v

# Nigerian network tests
python -m pytest tests/test_enhanced_api.py::TestNigerianNetworkOptimizations -v

# Individual test
python -m pytest tests/test_enhanced_api.py::TestEnhancedODIADEVAPI::test_health_check -v
```

### Test Coverage
The test suite covers:
- ✅ Functional Testing - Core business logic
- ✅ Error Handling - Exception management
- ✅ Security Testing - Input validation and sanitization
- ✅ Nigerian Network - MTN/Airtel simulations
- ✅ Phone Validation - Nigerian mobile number patterns
- ✅ API Contracts - Request/response validation
- ✅ Database Operations - CRUD operations
- ✅ Logging - Request tracking and debugging

## 🚀 Deployment

### Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export OPENAI_API_KEY=your_key_here

# Run development server
python main.py
```

### Production Deployment
```bash
# Run production server
python main_5001.py

# Or use Docker
docker build -t odiadev-tts-api .
docker run -p 5001:5001 odiadev-tts-api
```

### Docker Deployment
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 5001

CMD ["python", "main_5001.py"]
```

### Environment Variables
```bash
# Required
OPENAI_API_KEY=your_openai_api_key

# Optional
SECRET_KEY=your_secret_key
FLASK_ENV=production
MINIMAX_TTS_JWT_TOKEN=your_minimax_token
MINIMAX_TTS_VOICE_ID=your_voice_id
MINIMAX_TTS_GROUP_ID=your_group_id
```

## 📊 Monitoring & Logging

### Request Tracking
Every API request includes:
- **Request ID**: Unique identifier for tracking
- **Timestamp**: ISO format timestamp
- **Success Status**: Boolean success indicator
- **Error Details**: Comprehensive error information

### Log Levels
- **INFO**: Normal operations
- **WARNING**: Potential issues
- **ERROR**: Error conditions
- **DEBUG**: Detailed debugging information

### Log Sources
- **tts**: Text-to-speech operations
- **signup**: Client registration
- **deployment**: Deployment processes
- **network**: Network operations
- **security**: Security events

## 🔧 Configuration

### Nigerian Network Settings
```python
NIGERIAN_NETWORK_CONFIG = {
    'retry_delays': [250, 500, 1000],  # Exponential backoff
    'timeout': 30,                     # Increased timeout
    'max_retries': 3,                  # Maximum retry attempts
    'request_size_limit': 1024 * 1024  # 1MB limit
}
```

### Pricing Tiers
```python
PRICING_TIERS = {
    'starter': 8000,      # ₦8,000
    'pro': 15000,        # ₦15,000
    'enterprise': 75000   # ₦75,000
}
```

## 🛡️ Security Features

### Input Validation
- **Text Length**: Maximum 4096 characters
- **Phone Numbers**: Nigerian mobile number validation
- **Plan Tiers**: Validated against allowed values
- **Input Sanitization**: XSS protection

### Rate Limiting
- **Request Throttling**: Prevents API abuse
- **Per-Client Limits**: Individual client rate limits
- **Graceful Degradation**: Service continues under load

### Error Handling
- **Comprehensive Logging**: All errors logged with context
- **User-Friendly Messages**: Clear error messages
- **Request Tracking**: Unique IDs for debugging
- **Graceful Fallbacks**: Mock services when external APIs fail

## 📈 Performance Optimizations

### Nigerian Network
- **Connection Pooling**: Efficient connection reuse
- **Request Compression**: Reduced bandwidth usage
- **Caching**: Response caching where appropriate
- **Async Operations**: Non-blocking API calls

### Database
- **SQLite**: Lightweight, file-based database
- **Connection Management**: Proper connection handling
- **Query Optimization**: Efficient database queries
- **Indexing**: Optimized database indexes

## 🔄 API Versioning

Current version: **v1.0.0**

### Versioning Strategy
- **URL Versioning**: `/api/v1/endpoint`
- **Header Versioning**: `Accept: application/vnd.odiadev.v1+json`
- **Backward Compatibility**: Maintained across versions

## 📚 Documentation

### API Documentation
- **OpenAPI/Swagger**: Auto-generated from code
- **Postman Collection**: Available for testing
- **cURL Examples**: Command-line examples
- **Response Examples**: Detailed response schemas

### Developer Guides
- **Getting Started**: Quick setup guide
- **Authentication**: API key management
- **Error Handling**: Common error scenarios
- **Best Practices**: Recommended usage patterns

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

### Code Standards
- **PEP 8**: Python code style
- **Type Hints**: Function parameter types
- **Docstrings**: Comprehensive documentation
- **Tests**: 90%+ test coverage

## 📄 License

This project is part of the ODIADEV ecosystem at [odia.dev](https://odia.dev).

## 🆘 Support

### Getting Help
- **Documentation**: Check this README first
- **Issues**: Report bugs on GitHub
- **Discussions**: Ask questions in GitHub Discussions
- **Email**: Contact support@odia.dev

### Emergency Contacts
- **Production Issues**: +234 800 ODIADEV
- **Technical Support**: tech@odia.dev
- **Business Inquiries**: business@odia.dev

---

**🇳🇬 Built for Nigeria, Optimized for the World** 🚀

*Empowering Nigerian developers with world-class AI solutions*
