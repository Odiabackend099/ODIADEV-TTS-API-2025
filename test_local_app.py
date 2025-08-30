import requests
import json
import time

def test_health_endpoint():
    """Test the health endpoint"""
    try:
        response = requests.get("http://localhost:5000/health", timeout=10)
        print(f"Health Check Status: {response.status_code}")
        print(f"Health Check Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_tts_endpoint():
    """Test the TTS endpoint with a simple text"""
    try:
        data = {
            "text": "Hello, this is a test of the ODIADEV TTS system.",
            "voice": "alloy"
        }
        
        response = requests.post(
            "http://localhost:5000/api/tts", 
            json=data,
            timeout=30
        )
        
        print(f"TTS Status: {response.status_code}")
        result = response.json()
        print(f"TTS Success: {result.get('success')}")
        
        if result.get('success'):
            print(f"TTS Provider: {result.get('data', {}).get('provider', 'unknown')}")
            print(f"TTS Mock: {result.get('data', {}).get('mock', False)}")
        else:
            print(f"TTS Error: {result.get('error')}")
            
        return response.status_code == 200 and result.get('success')
        
    except Exception as e:
        print(f"TTS test failed: {e}")
        return False

def main():
    print("Testing ODIADEV TTS API locally...")
    print("=" * 50)
    
    # Wait a moment for the server to be ready
    print("Waiting for server to be ready...")
    time.sleep(3)
    
    # Test health endpoint
    print("\n1. Testing Health Endpoint...")
    health_ok = test_health_endpoint()
    
    # Test TTS endpoint
    print("\n2. Testing TTS Endpoint...")
    tts_ok = test_tts_endpoint()
    
    print("\n" + "=" * 50)
    print("Test Results:")
    print(f"Health Check: {'✓ PASS' if health_ok else '✗ FAIL'}")
    print(f"TTS Test: {'✓ PASS' if tts_ok else '✗ FAIL'}")
    
    if health_ok and tts_ok:
        print("\n🎉 All tests passed! Your TTS API is working correctly.")
    else:
        print("\n⚠️ Some tests failed. Check the server logs for details.")

if __name__ == "__main__":
    main()