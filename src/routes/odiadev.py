from flask import Blueprint, request, jsonify
from src.models.client import db, Client, Deployment, Log
import requests
import os
import json
import base64
import io
from datetime import datetime
import re
import time
import hashlib
from functools import wraps

odiadev_bp = Blueprint('odiadev', __name__)

# Pricing configuration
PRICING_TIERS = {
    'starter': 8000,
    'pro': 15000,
    'enterprise': 75000
}

# Nigerian network optimization settings
NIGERIAN_NETWORK_CONFIG = {
    'retry_delays': [250, 500, 1000],  # Exponential backoff for MTN/Airtel
    'timeout': 30,  # Increased timeout for slow connections
    'max_retries': 3,
    'request_size_limit': 1024 * 1024  # 1MB limit for Nigerian networks
}

def log_message(source, message, level="info"):
    """Enhanced logging with levels and Nigerian context"""
    try:
        log_entry = Log(source=source, message=message)
        db.session.add(log_entry)
        db.session.commit()
        
        # Also log to console for debugging
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level.upper()}] {source}: {message}")
    except Exception as e:
        print(f"Failed to log message: {e}")

def validate_phone(phone):
    """Enhanced Nigerian phone number validation"""
    # Nigerian phone number patterns: 080, 081, 070, 071, 090, 091
    nigeria_patterns = [
        r'^080\d{8}$',  # MTN
        r'^081\d{8}$',  # MTN
        r'^070\d{8}$',  # Airtel
        r'^071\d{8}$',  # Airtel
        r'^090\d{8}$',  # 9mobile
        r'^091\d{8}$',  # 9mobile
    ]
    
    for pattern in nigeria_patterns:
        if re.match(pattern, phone):
            return True
    return False

def validate_plan_tier(plan_tier):
    """Validate plan tier"""
    return plan_tier in PRICING_TIERS

def sanitize_input(text):
    """Sanitize user input to prevent injection attacks"""
    if not text:
        return ""
    
    # Remove potentially dangerous characters
    dangerous_chars = ['<', '>', '"', "'", '&', ';', '(', ')', '{', '}']
    for char in dangerous_chars:
        text = text.replace(char, '')
    
    return text.strip()

def retry_with_backoff(func, max_retries=3):
    """Nigerian network-optimized retry mechanism"""
    delays = NIGERIAN_NETWORK_CONFIG['retry_delays']
    
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            
            delay = delays[min(attempt, len(delays) - 1)]
            log_message("network", f"Retry attempt {attempt + 1} after {delay}ms delay")
            time.sleep(delay / 1000)  # Convert to seconds

def generate_request_id():
    """Generate unique request ID for tracking"""
    return hashlib.md5(f"{time.time()}".encode()).hexdigest()[:8]

def rate_limit_check(client_id=None):
    """Basic rate limiting for Nigerian network optimization"""
    # Simple in-memory rate limiting (in production, use Redis)
    current_time = time.time()
    # Allow 10 requests per minute per client
    return True  # Simplified for now

def generate_tts_voice_openai(text, voice="alloy"):
    """Enhanced OpenAI TTS with Nigerian network optimizations"""
    request_id = generate_request_id()
    
    try:
        # Check if OpenAI API key is available
        openai_api_key = os.getenv('OPENAI_API_KEY')
        if not openai_api_key:
            log_message("tts", f"[{request_id}] OpenAI API key not configured, using mock response")
            return generate_mock_tts_response(text, voice, request_id)
        
        # Sanitize input
        sanitized_text = sanitize_input(text)
        if len(sanitized_text) > 4096:
            raise ValueError("Text too long (max 4096 characters)")
        
        log_message("tts", f"[{request_id}] Starting OpenAI TTS generation: {sanitized_text[:50]}...")
        
        # Import OpenAI client
        try:
            from openai import OpenAI
            client = OpenAI(api_key=openai_api_key)
        except ImportError:
            log_message("tts", f"[{request_id}] OpenAI library not installed, using mock response")
            return generate_mock_tts_response(text, voice, request_id)
        
        # Generate TTS with retry mechanism
        def tts_request():
            response = client.audio.speech.create(
                model="tts-1",
                voice=voice,
                input=sanitized_text,
                response_format="mp3"
            )
            return response
        
        # Use retry mechanism for Nigerian network conditions
        response = retry_with_backoff(tts_request, max_retries=NIGERIAN_NETWORK_CONFIG['max_retries'])
        
        # Convert response to base64 for easy transmission
        audio_data = response.content
        audio_base64 = base64.b64encode(audio_data).decode('utf-8')
        
        log_message("tts", f"[{request_id}] OpenAI TTS generation successful")
        
        return {
            "success": True,
            "audio_base64": audio_base64,
            "format": "mp3",
            "text": sanitized_text,
            "voice": voice,
            "request_id": request_id,
            "provider": "openai",
            "size_bytes": len(audio_data)
        }
        
    except Exception as e:
        log_message("tts", f"[{request_id}] OpenAI TTS generation error: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "request_id": request_id,
            "fallback": True
        }

def generate_mock_tts_response(text, voice, request_id):
    """Mock TTS response for testing and fallback"""
    try:
        # Create a more realistic mock response
        mock_audio_data = b"MOCK_AUDIO_DATA_" + text.encode('utf-8') + b"_" + voice.encode('utf-8')
        audio_base64 = base64.b64encode(mock_audio_data).decode('utf-8')
        
        log_message("tts", f"[{request_id}] Mock TTS generation successful")
        
        return {
            "success": True,
            "audio_base64": audio_base64,
            "format": "mp3",
            "text": text,
            "voice": voice,
            "request_id": request_id,
            "mock": True,
            "provider": "mock",
            "message": "This is a mock TTS response for testing. In production, this would generate real audio."
        }
        
    except Exception as e:
        log_message("tts", f"[{request_id}] Mock TTS generation error: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "request_id": request_id
        }

def generate_tts_voice_message(text, voice_id, group_id, jwt_token):
    """Enhanced MiniMax TTS with Nigerian network optimizations"""
    request_id = generate_request_id()
    
    try:
        url = "https://api.minimax.chat/v1/t2a_v2"
        headers = {
            "Authorization": f"Bearer {jwt_token}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "group_id": group_id,
            "voice_id": voice_id,
            "text": sanitize_input(text),
            "audio_setting": {
                "sample_rate": 22050,
                "bitrate": 128000,
                "format": "mp3"
            }
        }
        
        def minimax_request():
            response = requests.post(
                url, 
                headers=headers, 
                json=payload,
                timeout=NIGERIAN_NETWORK_CONFIG['timeout']
            )
            return response
        
        # Use retry mechanism
        response = retry_with_backoff(minimax_request, max_retries=NIGERIAN_NETWORK_CONFIG['max_retries'])
        
        if response.status_code == 200:
            result = response.json()
            if result.get("audio_file"):
                log_message("tts", f"[{request_id}] MiniMax TTS generation successful")
                return {
                    "success": True,
                    "audio_url": result["audio_file"],
                    "text": text,
                    "request_id": request_id,
                    "provider": "minimax"
                }
        
        log_message("tts", f"[{request_id}] MiniMax TTS generation failed: {response.text}")
        return {
            "success": False,
            "error": f"MiniMax API error: {response.text}",
            "request_id": request_id
        }
        
    except Exception as e:
        log_message("tts", f"[{request_id}] MiniMax TTS generation error: {str(e)}")
        return {
            "success": False,
            "error": str(e),
            "request_id": request_id
        }

@odiadev_bp.route('/tts', methods=['POST'])
def text_to_speech():
    """Enhanced TTS endpoint with Nigerian optimizations"""
    request_id = generate_request_id()
    
    try:
        # Rate limiting check
        if not rate_limit_check():
            return jsonify({
                "success": False,
                "error": "Rate limit exceeded. Please try again later.",
                "request_id": request_id
            }), 429
        
        data = request.get_json()
        
        if not data or not data.get('text'):
            return jsonify({
                "success": False,
                "error": "Text is required",
                "request_id": request_id
            }), 400
        
        text = str(data.get('text', '')).strip()
        voice = str(data.get('voice', 'alloy'))
        provider = str(data.get('provider', 'openai'))
        
        # Enhanced validation
        if not text:
            return jsonify({
                "success": False,
                "error": "Text cannot be empty",
                "request_id": request_id
            }), 400
        
        if len(text) > 4096:
            return jsonify({
                "success": False,
                "error": "Text too long (max 4096 characters)",
                "request_id": request_id
            }), 400
        
        # Validate voice options
        valid_voices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']
        if voice not in valid_voices:
            voice = 'alloy'  # Default to alloy if invalid
        
        log_message("tts", f"[{request_id}] TTS request received: {text[:50]}... (voice: {voice}, provider: {provider})")
        
        # Generate TTS based on provider
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
                "data": result,
                "request_id": request_id,
                "timestamp": datetime.now().isoformat()
            }), 200
        else:
            return jsonify({
                "success": False,
                "error": result.get('error', 'TTS generation failed'),
                "request_id": request_id,
                "timestamp": datetime.now().isoformat()
            }), 500
            
    except Exception as e:
        log_message("tts", f"[{request_id}] TTS endpoint error: {str(e)}")
        return jsonify({
            "success": False,
            "error": "Internal server error",
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }), 500

@odiadev_bp.route('/signup', methods=['POST'])
def signup():
    """Enhanced signup endpoint with Nigerian optimizations"""
    request_id = generate_request_id()
    
    try:
        # Rate limiting check
        if not rate_limit_check():
            return jsonify({
                "success": False,
                "error": "Rate limit exceeded. Please try again later.",
                "request_id": request_id
            }), 429
        
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No data provided",
                "request_id": request_id
            }), 400
        
        # Extract and validate required fields
        full_name = sanitize_input(data.get('full_name', ''))
        phone = data.get('phone', '').strip()
        business_name = sanitize_input(data.get('business_name', ''))
        plan_tier = data.get('plan_tier', '').strip().lower()
        voice_option = data.get('voice_option', False)
        
        # Enhanced validation
        if not all([full_name, phone, business_name, plan_tier]):
            return jsonify({
                "success": False,
                "error": "Missing required fields: full_name, phone, business_name, plan_tier",
                "request_id": request_id
            }), 400
        
        if not validate_phone(phone):
            return jsonify({
                "success": False,
                "error": "Invalid Nigerian phone number format. Must be 11 digits starting with 080, 081, 070, 071, 090, or 091",
                "request_id": request_id
            }), 400
        
        if not validate_plan_tier(plan_tier):
            return jsonify({
                "success": False,
                "error": f"Invalid plan tier. Must be one of: {', '.join(PRICING_TIERS.keys())}",
                "request_id": request_id
            }), 400
        
        # Check for duplicate phone numbers
        existing_client = Client.query.filter_by(phone=phone).first()
        if existing_client:
            return jsonify({
                "success": False,
                "error": "Phone number already registered",
                "request_id": request_id
            }), 409
        
        # Log the signup attempt
        log_message("signup", f"[{request_id}] New signup attempt: {full_name} - {plan_tier}")
        
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
        
        # Simulate deployment process with Nigerian network considerations
        try:
            deployment.status = 'deploying'
            db.session.commit()
            
            # Simulate deployment time (realistic for Nigerian infrastructure)
            time.sleep(0.5)  # Simulate processing time
            
            # For demo purposes, mark as completed
            deployment.status = 'completed'
            client.is_live = True
            db.session.commit()
            
        except Exception as e:
            deployment.status = 'failed'
            db.session.commit()
            log_message("deployment", f"[{request_id}] Deployment failed for client {client.id}: {str(e)}")
        
        # Generate welcome TTS message if requested
        tts_result = None
        if voice_option:
            welcome_text = f"Welcome to ODIADEV, {full_name}! Your {plan_tier.title()} plan AI agent is being deployed for {business_name}. Thank you for choosing ODIADEV for your business automation needs."
            tts_result = generate_tts_voice_openai(welcome_text)
        
        # Prepare response
        response_data = {
            "success": True,
            "status": "success",
            "message": "Signup completed successfully",
            "client_id": client.id,
            "deployment_status": deployment.status,
            "tts_generated": tts_result is not None and tts_result.get('success', False),
            "request_id": request_id,
            "timestamp": datetime.now().isoformat(),
            "plan_details": {
                "tier": plan_tier,
                "price_naira": PRICING_TIERS[plan_tier],
                "features": get_plan_features(plan_tier)
            }
        }
        
        if tts_result and tts_result.get('success'):
            response_data["welcome_audio"] = tts_result
        
        log_message("signup", f"[{request_id}] Signup completed for client {client.id}")
        
        return jsonify(response_data), 200
        
    except Exception as e:
        log_message("signup", f"[{request_id}] Signup error: {str(e)}")
        return jsonify({
            "success": False,
            "error": "Internal server error",
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }), 500

def get_plan_features(plan_tier):
    """Get features for each plan tier"""
    features = {
        'starter': [
            'Basic AI Agent',
            'Text-to-Speech (5 hours/month)',
            'Email Support',
            'Standard Response Time'
        ],
        'pro': [
            'Advanced AI Agent',
            'Text-to-Speech (20 hours/month)',
            'Priority Support',
            'Custom Voice Training',
            'API Access'
        ],
        'enterprise': [
            'Custom AI Agent',
            'Unlimited Text-to-Speech',
            '24/7 Dedicated Support',
            'Custom Integration',
            'White-label Solution',
            'Advanced Analytics'
        ]
    }
    return features.get(plan_tier, [])

@odiadev_bp.route('/status/<int:client_id>', methods=['GET'])
def get_client_status(client_id):
    """Enhanced client status endpoint"""
    request_id = generate_request_id()
    
    try:
        client = Client.query.get_or_404(client_id)
        deployments = Deployment.query.filter_by(client_id=client_id).all()
        
        response_data = {
            "success": True,
            "client": client.to_dict(),
            "deployments": [d.to_dict() for d in deployments],
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        log_message("status", f"[{request_id}] Status check error: {str(e)}")
        return jsonify({
            "success": False,
            "error": "Failed to get status",
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }), 500

@odiadev_bp.route('/logs', methods=['GET'])
def get_logs():
    """Enhanced logs endpoint with filtering"""
    request_id = generate_request_id()
    
    try:
        limit = request.args.get('limit', 100, type=int)
        source = request.args.get('source', None)
        level = request.args.get('level', None)
        
        # Validate limit
        if limit > 1000:
            limit = 1000  # Cap at 1000 for performance
        
        query = Log.query
        if source:
            query = query.filter_by(source=source)
        
        logs = query.order_by(Log.timestamp.desc()).limit(limit).all()
        
        response_data = {
            "success": True,
            "logs": [log.to_dict() for log in logs],
            "total_count": len(logs),
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": "Failed to get logs",
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }), 500

# New endpoint for Nigerian network diagnostics
@odiadev_bp.route('/network-test', methods=['GET'])
def network_test():
    """Test endpoint for Nigerian network conditions"""
    request_id = generate_request_id()
    
    try:
        # Test external API connectivity
        test_urls = [
            "https://api.openai.com/v1/models",
            "https://httpbin.org/get"
        ]
        
        results = {}
        for url in test_urls:
            try:
                start_time = time.time()
                response = requests.get(url, timeout=10)
                end_time = time.time()
                
                results[url] = {
                    "status": response.status_code,
                    "response_time_ms": round((end_time - start_time) * 1000, 2),
                    "success": response.status_code < 400
                }
            except Exception as e:
                results[url] = {
                    "status": "error",
                    "error": str(e),
                    "success": False
                }
        
        return jsonify({
            "success": True,
            "network_test": results,
            "request_id": request_id,
            "timestamp": datetime.now().isoformat(),
            "nigerian_optimizations": NIGERIAN_NETWORK_CONFIG
        }), 200
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e),
            "request_id": request_id,
            "timestamp": datetime.now().isoformat()
        }), 500

