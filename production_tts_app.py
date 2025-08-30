import os
import sys
import base64
import time
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from config folder
config_path = os.path.join(os.path.dirname(__file__), 'config', '.env')
print(f"Loading .env from: {config_path}")
load_dotenv(config_path)

# Verify OpenAI API key is loaded
openai_key = os.getenv('OPENAI_API_KEY')
if not openai_key or openai_key.startswith('#'):
    print("❌ OpenAI API key not found in environment variables!")
    sys.exit(1)

print(f"✅ OpenAI API key loaded: {openai_key[:20]}...")

from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'production-key-123')

# Enable CORS for all routes
CORS(app, origins="*")

def generate_real_tts(text, voice="alloy"):
    """Generate TTS using real OpenAI API"""
    try:
        # Import OpenAI client
        from openai import OpenAI
        client = OpenAI(api_key=openai_key)
        
        print(f"🎙️ Generating TTS for: {text[:50]}{'...' if len(text) > 50 else ''}")
        print(f"   Voice: {voice}")
        
        # Generate TTS
        response = client.audio.speech.create(
            model="tts-1",
            voice=voice,
            input=text,
            response_format="mp3"
        )
        
        # Convert response to base64 for easy transmission
        audio_data = response.content
        audio_base64 = base64.b64encode(audio_data).decode('utf-8')
        
        print(f"✅ TTS generated successfully: {len(audio_data)} bytes")
        
        return {
            "success": True,
            "audio_base64": audio_base64,
            "format": "mp3",
            "text": text,
            "voice": voice,
            "provider": "openai",
            "size_bytes": len(audio_data),
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"❌ TTS generation failed: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "provider": "openai"
        }

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "ODIADEV TTS API - Production",
        "version": "1.0.0",
        "openai_configured": bool(openai_key and not openai_key.startswith('#'))
    })

@app.route('/tts', methods=['POST'])
def text_to_speech():
    """Production TTS endpoint using real OpenAI API"""
    try:
        data = request.get_json()
        
        if not data or not data.get('text'):
            return jsonify({
                "success": False,
                "error": "Text is required"
            }), 400
        
        text = str(data.get('text', '')).strip()
        voice = str(data.get('voice', 'alloy'))
        
        # Validate input
        if not text:
            return jsonify({
                "success": False,
                "error": "Text cannot be empty"
            }), 400
        
        if len(text) > 4096:
            return jsonify({
                "success": False,
                "error": "Text too long (max 4096 characters)"
            }), 400
        
        # Validate voice options
        valid_voices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']
        if voice not in valid_voices:
            voice = 'alloy'  # Default to alloy if invalid
        
        # Generate TTS
        result = generate_real_tts(text, voice)
        
        if result.get('success'):
            return jsonify({
                "success": True,
                "message": "TTS generation successful",
                "data": result
            }), 200
        else:
            return jsonify({
                "success": False,
                "error": result.get('error', 'TTS generation failed')
            }), 500
            
    except Exception as e:
        print(f"❌ TTS endpoint error: {str(e)}")
        return jsonify({
            "success": False,
            "error": "Internal server error"
        }), 500

if __name__ == '__main__':
    print("🚀 Starting ODIADEV TTS API - Production Mode")
    print(f"   OpenAI API Key: {'✅ Configured' if openai_key and not openai_key.startswith('#') else '❌ Missing'}")
    print(f"   Environment: {os.getenv('FLASK_ENV', 'production')}")
    print("   Starting server on http://127.0.0.1:5003")
    app.run(host='127.0.0.1', port=5003, debug=False)