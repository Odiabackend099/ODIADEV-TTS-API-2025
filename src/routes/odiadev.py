from flask import Blueprint, request, jsonify
from src.models.client import db, Client, Deployment, Log
import requests
import os
import json
import base64
import io
from datetime import datetime
import re

odiadev_bp = Blueprint('odiadev', __name__)

# Pricing configuration
PRICING_TIERS = {
    'starter': 8000,
    'pro': 15000,
    'enterprise': 75000
}

def log_message(source, message):
    """Helper function to log messages to database"""
    try:
        log_entry = Log(source=source, message=message)
        db.session.add(log_entry)
        db.session.commit()
    except Exception as e:
        print(f"Failed to log message: {e}")

def validate_phone(phone):
    """Validate phone number format (11 digits)"""
    return re.match(r'^\d{11}$', phone) is not None

def validate_plan_tier(plan_tier):
    """Validate plan tier"""
    return plan_tier in PRICING_TIERS

def generate_tts_voice_openai(text, voice="alloy"):
    """Generate TTS voice message using mock service for testing"""
    try:
        import base64
        import json
        
        # Mock TTS response for testing purposes
        # In production, this would use a real TTS service
        mock_audio_data = b"MOCK_AUDIO_DATA_" + text.encode('utf-8')
        audio_base64 = base64.b64encode(mock_audio_data).decode('utf-8')
        
        log_message("tts", f"Mock TTS generation successful for text: {text[:50]}...")
        
        return {
            "success": True,
            "audio_base64": audio_base64,
            "format": "mp3",
            "text": text,
            "voice": voice,
            "mock": True,
            "message": "This is a mock TTS response for testing. In production, this would generate real audio."
        }
        
    except Exception as e:
        log_message("tts", f"Mock TTS generation error: {str(e)}")
        return {
            "success": False,
            "error": str(e)
        }

def generate_tts_voice_message(text, voice_id, group_id, jwt_token):
    """Generate TTS voice message using MiniMax API (fallback)"""
    try:
        url = "https://api.minimax.chat/v1/t2a_v2"
        headers = {
            "Authorization": f"Bearer {jwt_token}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "group_id": group_id,
            "voice_id": voice_id,
            "text": text,
            "audio_setting": {
                "sample_rate": 22050,
                "bitrate": 128000,
                "format": "mp3"
            }
        }
        
        response = requests.post(url, headers=headers, json=payload)
        
        if response.status_code == 200:
            result = response.json()
            if result.get("audio_file"):
                return {
                    "success": True,
                    "audio_url": result["audio_file"],
                    "text": text
                }
        
        log_message("tts", f"MiniMax TTS generation failed: {response.text}")
        return {
            "success": False,
            "error": f"MiniMax API error: {response.text}"
        }
        
    except Exception as e:
        log_message("tts", f"MiniMax TTS generation error: {str(e)}")
        return {
            "success": False,
            "error": str(e)
        }

@odiadev_bp.route('/tts', methods=['POST'])
def text_to_speech():
    """Main TTS endpoint"""
    try:
        data = request.get_json()
        
        if not data or not data.get('text'):
            return jsonify({"error": "Text is required"}), 400
        
        text = data.get('text', '').strip()
        voice = data.get('voice', 'alloy')  # Default to OpenAI's alloy voice
        provider = data.get('provider', 'openai')  # Default to OpenAI
        
        if len(text) > 4096:
            return jsonify({"error": "Text too long (max 4096 characters)"}), 400
        
        log_message("tts", f"TTS request received: {text[:50]}... (voice: {voice}, provider: {provider})")
        
        # Use OpenAI TTS by default (since it's already configured)
        if provider == 'openai' or not os.getenv('MINIMAX_TTS_JWT_TOKEN'):
            result = generate_tts_voice_openai(text, voice)
        else:
            # Fallback to MiniMax if configured
            voice_id = os.getenv('MINIMAX_TTS_VOICE_ID', 'moss_audio_a7ecca31-6658-11f0-92b0-be46934138a1')
            group_id = os.getenv('MINIMAX_TTS_GROUP_ID', '1928995360080924823')
            jwt_token = os.getenv('MINIMAX_TTS_JWT_TOKEN')
            
            result = generate_tts_voice_message(text, voice_id, group_id, jwt_token)
        
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
        log_message("tts", f"TTS endpoint error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@odiadev_bp.route('/signup', methods=['POST'])
def signup():
    """Main signup endpoint for ODIADEV"""
    try:
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        # Extract and validate required fields
        full_name = data.get('full_name', '').strip()
        phone = data.get('phone', '').strip()
        business_name = data.get('business_name', '').strip()
        plan_tier = data.get('plan_tier', '').strip().lower()
        voice_option = data.get('voice_option', False)
        
        # Validation
        if not all([full_name, phone, business_name, plan_tier]):
            return jsonify({"error": "Missing required fields"}), 400
        
        if not validate_phone(phone):
            return jsonify({"error": "Invalid phone number format (must be 11 digits)"}), 400
        
        if not validate_plan_tier(plan_tier):
            return jsonify({"error": "Invalid plan tier"}), 400
        
        # Log the signup attempt
        log_message("signup", f"New signup attempt: {full_name} - {plan_tier}")
        
        # Create client record
        client = Client(
            full_name=full_name,
            phone=phone,
            business_name=business_name,
            plan_tier=plan_tier,
            voice_option=voice_option
        )
        
        db.session.add(client)
        db.session.commit()
        
        # Create deployment record
        deployment = Deployment(
            client_id=client.id,
            status='pending'
        )
        db.session.add(deployment)
        db.session.commit()
        
        # Simulate deployment process
        deployment.status = 'deploying'
        db.session.commit()
        
        # For demo purposes, mark as completed
        deployment.status = 'completed'
        client.is_live = True
        db.session.commit()
        
        # Generate welcome TTS message if requested
        tts_result = None
        if voice_option:
            welcome_text = f"Welcome to ODIADEV, {full_name}! Your {plan_tier.title()} plan AI agent is being deployed for {business_name}."
            tts_result = generate_tts_voice_openai(welcome_text)
        
        # Prepare response
        response_data = {
            "status": "success",
            "message": "Signup completed successfully",
            "client_id": client.id,
            "deployment_status": deployment.status,
            "tts_generated": tts_result is not None and tts_result.get('success', False)
        }
        
        if tts_result and tts_result.get('success'):
            response_data["welcome_audio"] = tts_result
        
        log_message("signup", f"Signup completed for client {client.id}")
        
        return jsonify(response_data), 200
        
    except Exception as e:
        log_message("signup", f"Signup error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@odiadev_bp.route('/status/<int:client_id>', methods=['GET'])
def get_client_status(client_id):
    """Get client status and deployment information"""
    try:
        client = Client.query.get_or_404(client_id)
        deployments = Deployment.query.filter_by(client_id=client_id).all()
        
        response_data = {
            "client": client.to_dict(),
            "deployments": [d.to_dict() for d in deployments]
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        log_message("status", f"Status check error: {str(e)}")
        return jsonify({"error": "Failed to get status"}), 500

@odiadev_bp.route('/logs', methods=['GET'])
def get_logs():
    """Get system logs"""
    try:
        limit = request.args.get('limit', 100, type=int)
        source = request.args.get('source', None)
        
        query = Log.query
        if source:
            query = query.filter_by(source=source)
        
        logs = query.order_by(Log.timestamp.desc()).limit(limit).all()
        
        response_data = {
            "logs": [log.to_dict() for log in logs]
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        return jsonify({"error": "Failed to get logs"}), 500

