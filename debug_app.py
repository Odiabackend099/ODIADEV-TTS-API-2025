import os
import sys
from dotenv import load_dotenv

# Load environment variables from config folder
config_path = os.path.join(os.path.dirname(__file__), 'config', '.env')
print(f"Loading .env from: {config_path}")
load_dotenv(config_path)

# Check if .env loaded
print(f"Flask ENV: {os.getenv('FLASK_ENV', 'Not set')}")

# DON'T CHANGE THIS !!!
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS

# Simple debug version
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'debug-key-123')

# Enable CORS for all routes
CORS(app, origins="*")

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "ODIADEV TTS API",
        "version": "1.0.0",
        "env_loaded": os.getenv('FLASK_ENV', 'Not set')
    })

@app.route('/debug')
def debug_info():
    """Debug information"""
    return jsonify({
        "python_path": sys.path[:3],
        "working_directory": os.getcwd(),
        "config_path": config_path,
        "config_exists": os.path.exists(config_path),
        "env_vars": {
            "FLASK_ENV": os.getenv('FLASK_ENV', 'Not set'),
            "SECRET_KEY": "***" if os.getenv('SECRET_KEY') else 'Not set',
            "OPENAI_API_KEY": "***" if os.getenv('OPENAI_API_KEY') else 'Not set'
        }
    })

@app.route('/test-tts', methods=['POST'])
def test_tts():
    """Simple test TTS endpoint"""
    from flask import request
    import base64
    
    data = request.get_json() or {}
    text = data.get('text', 'Hello World')
    
    # Mock response for testing
    mock_audio_data = f"MOCK_AUDIO_{text}"
    audio_base64 = base64.b64encode(mock_audio_data.encode()).decode('utf-8')
    
    return jsonify({
        "success": True,
        "message": "Mock TTS response - system is working",
        "data": {
            "text": text,
            "audio_base64": audio_base64,
            "mock": True,
            "provider": "debug"
        }
    })

if __name__ == '__main__':
    print("Starting debug Flask app...")
    print(f"Working directory: {os.getcwd()}")
    print(f"Config file exists: {os.path.exists(config_path)}")
    app.run(host='127.0.0.1', port=5001, debug=True)