# ODIADEV TTS API

A production-ready Text-to-Speech API service built with Flask, featuring OpenAI TTS integration, client management, and comprehensive logging.

## Features

- **Text-to-Speech Generation**: OpenAI TTS integration with multiple voice options
- **Client Management**: Complete signup and deployment tracking system
- **Comprehensive Logging**: Detailed logging for all operations
- **RESTful API**: Clean, well-documented API endpoints
- **Production Ready**: CORS enabled, error handling, and health checks

## Quick Start

1. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set Environment Variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run the Application**
   ```bash
   python main.py
   ```

4. **Test the API**
   ```bash
   python tests/test_api.py
   ```

## API Endpoints

### Health Check
```
GET /health
```

### Text-to-Speech
```
POST /api/tts
Content-Type: application/json

{
  "text": "Hello, world!",
  "voice": "alloy",
  "provider": "openai"
}
```

### Client Signup
```
POST /api/signup
Content-Type: application/json

{
  "full_name": "John Doe",
  "phone": "08123456789",
  "business_name": "My Business",
  "plan_tier": "starter",
  "voice_option": true
}
```

### Client Status
```
GET /api/status/{client_id}
```

### System Logs
```
GET /api/logs?limit=100&source=tts
```

## Configuration

The application uses environment variables for configuration:

- `OPENAI_API_KEY`: OpenAI API key (automatically configured)
- `SECRET_KEY`: Flask secret key
- `FLASK_ENV`: Environment (development/production)

## Testing

Run the comprehensive test suite:

```bash
python tests/test_api.py
```

This will test all endpoints and verify TTS functionality.

## Deployment

The application is configured for production deployment with:

- CORS enabled for cross-origin requests
- Host binding to `0.0.0.0` for external access
- Comprehensive error handling
- Health check endpoint for monitoring

## Architecture

```
odiadev-tts-api/
├── main.py                 # Flask application entry point
├── src/
│   ├── models/            # Database models
│   │   ├── user.py        # User model and database setup
│   │   └── client.py      # Client, Deployment, Log models
│   └── routes/            # API route handlers
│       ├── user.py        # User management routes
│       └── odiadev.py     # Main ODIADEV functionality
├── tests/                 # Test files
│   └── test_api.py        # API endpoint tests
├── database/              # SQLite database storage
├── static/                # Static files (if any)
└── requirements.txt       # Python dependencies
```

## License

This project is part of the ODIADEV ecosystem at odia.dev.

