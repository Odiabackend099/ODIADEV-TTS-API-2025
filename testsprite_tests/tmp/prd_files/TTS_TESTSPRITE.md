# ODIADEV TTS API - TestSprite Testing Requirements

## Project Overview
ODIADEV TTS API is a production-ready Text-to-Speech service designed to make voice AI affordable and accessible for Nigerian businesses. The API provides seamless integration with OpenAI's TTS capabilities while supporting client management, logging, and scalable deployment.

## Core Functionality to Test

### 1. Health Monitoring
- **Endpoint**: `GET /health`
- **Expected Response**: JSON with status "healthy", service name, and version
- **Test Requirements**: 
  - Should return 200 status code
  - Should contain required fields: status, service, version
  - Should respond within 5 seconds

### 2. Debug Information
- **Endpoint**: `GET /debug`
- **Expected Response**: JSON with environment configuration details
- **Test Requirements**:
  - Should return 200 status code
  - Should contain config_exists, env_vars, working_directory
  - Should mask sensitive information with "***"

### 3. Text-to-Speech Generation
- **Endpoint**: `POST /test-tts`
- **Input**: JSON with text and optional voice parameters
- **Expected Response**: JSON with success flag and audio data
- **Test Requirements**:
  - Should accept valid text input
  - Should return base64 encoded audio data
  - Should handle different voice options
  - Should validate input length limits
  - Should return appropriate error messages for invalid input

## Test Scenarios to Implement

### Basic Functionality Tests
1. **Health Check Test**
   - Verify API is accessible
   - Confirm all required response fields
   - Test response time performance

2. **TTS Core Functionality**
   - Test with simple text: "Hello World"
   - Test with Nigerian business context: "Welcome to ODIADEV"
   - Test with longer text (company pitch)
   - Test with empty input (should fail gracefully)
   - Test with excessive length input (should return error)

3. **Voice Parameter Tests**
   - Test default voice (alloy)
   - Test with different voice options
   - Test with invalid voice parameters

### Nigerian Context Tests
4. **Network Resilience Tests**
   - Test with slower network conditions
   - Test timeout handling
   - Test retry mechanisms

5. **Business Use Cases**
   - Test generating customer service messages
   - Test generating educational content
   - Test generating marketing announcements
   - Test generating multilingual content

### Performance Tests
6. **Load Testing**
   - Test multiple concurrent requests
   - Test response time consistency
   - Test memory usage during bulk operations

7. **Audio Quality Tests**
   - Verify audio data is properly encoded
   - Test different text lengths produce appropriate audio sizes
   - Verify mock responses are consistent

## Expected API Behavior

### Success Responses
```json
{
  "success": true,
  "message": "TTS generation successful", 
  "data": {
    "text": "input text",
    "audio_base64": "base64 encoded audio",
    "voice": "alloy",
    "provider": "debug|openai|mock",
    "format": "mp3"
  }
}
```

### Error Responses
```json
{
  "success": false,
  "error": "Error description",
  "request_id": "unique_id"
}
```

## Performance Requirements
- Health check should respond within 2 seconds
- TTS generation should complete within 30 seconds
- API should handle at least 10 concurrent requests
- Memory usage should remain stable under load

## Security Requirements
- No sensitive data should be exposed in responses
- API keys should be masked in debug output
- Input should be sanitized and validated

## Nigerian Business Context
- API should work reliably with Nigerian internet conditions
- Should support Nigerian business names and terminology  
- Should handle common Nigerian phrases and expressions
- Pricing should be in Naira (8,000 - 75,000 range)

## Success Criteria
- All endpoints return expected response formats
- TTS generation produces valid audio output
- Error handling is graceful and informative
- Performance meets stated requirements
- API demonstrates readiness for Nigerian market deployment

## Test Environment
- **Base URL**: http://localhost:5001
- **Framework**: Flask with CORS enabled
- **Database**: SQLite (for logging)
- **Authentication**: Public (no auth required for testing)

## Additional Notes
- The system includes fallback mechanisms for network issues
- Mock responses are provided when OpenAI API is not available
- All audio files are generated as base64 encoded MP3 format
- The API is optimized for Nigerian network conditions