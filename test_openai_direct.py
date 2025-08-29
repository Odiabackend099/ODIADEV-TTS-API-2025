#!/usr/bin/env python3
"""
Direct test of OpenAI TTS functionality
"""

import os
import base64

def test_openai_tts():
    try:
        import openai
        
        print("Testing OpenAI TTS directly...")
        print(f"OpenAI version: {openai.__version__}")
        print(f"API Key: {os.getenv('OPENAI_API_KEY', 'Not set')[:20]}...")
        print(f"API Base: {os.getenv('OPENAI_API_BASE', 'Not set')}")
        
        # Try different initialization methods
        print("\n1. Testing simple initialization...")
        try:
            client = openai.OpenAI()
            print("âœ… Simple initialization successful")
        except Exception as e:
            print(f"âŒ Simple initialization failed: {e}")
            return False
        
        print("\n2. Testing TTS request...")
        try:
            response = client.audio.speech.create(
                model="tts-1",
                voice="alloy",
                input="Hello, this is a test."
            )
            
            # Get audio data
            audio_data = response.content
            audio_base64 = base64.b64encode(audio_data).decode('utf-8')
            
            print(f"âœ… TTS request successful! Audio size: {len(audio_data)} bytes")
            print(f"Base64 length: {len(audio_base64)} characters")
            return True
            
        except Exception as e:
            print(f"âŒ TTS request failed: {e}")
            return False
            
    except Exception as e:
        print(f"âŒ Import or general error: {e}")
        return False

if __name__ == "__main__":
    success = test_openai_tts()
    if success:
        print("\nðŸŽ‰ OpenAI TTS test passed!")
    else:
        print("\nðŸ’¥ OpenAI TTS test failed!")

