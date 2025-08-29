import os
import json
from TTS.api import TTS

def initialize_tts_models():
    """Initialize and cache TTS models for Nigerian voices"""
    print("Initializing Nigerian TTS models...")
    
    # Load voice configuration
    with open('/app/voices/voice_config.json', 'r') as f:
        config = json.load(f)
    
    for voice_name, voice_config in config['voices'].items():
        try:
            print(f"Loading model for {voice_name}...")
            tts = TTS(model_name=voice_config['model'])
            print(f"Voice {voice_name} model loaded successfully")
        except Exception as e:
            print(f"Failed to load {voice_name}: {e}")
    
    print("TTS model initialization complete")

if __name__ == "__main__":
    initialize_tts_models()