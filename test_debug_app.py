import requests
import json

def test_debug_app():
    """Test the debug Flask application"""
    base_url = "http://localhost:5001"
    
    print("Testing Debug Flask App...")
    print("=" * 40)
    
    # Test health endpoint
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        print(f"Health Status: {response.status_code}")
        print(f"Health Response: {json.dumps(response.json(), indent=2)}")
    except Exception as e:
        print(f"Health test failed: {e}")
        return False
    
    # Test debug endpoint
    try:
        response = requests.get(f"{base_url}/debug", timeout=5)
        print(f"\nDebug Status: {response.status_code}")
        print(f"Debug Response: {json.dumps(response.json(), indent=2)}")
    except Exception as e:
        print(f"Debug test failed: {e}")
    
    # Test TTS endpoint
    try:
        data = {"text": "Testing ODIADEV TTS system"}
        response = requests.post(f"{base_url}/test-tts", json=data, timeout=5)
        print(f"\nTTS Status: {response.status_code}")
        result = response.json()
        print(f"TTS Success: {result.get('success')}")
        print(f"TTS Message: {result.get('message')}")
        return True
    except Exception as e:
        print(f"TTS test failed: {e}")
        return False

if __name__ == "__main__":
    test_debug_app()