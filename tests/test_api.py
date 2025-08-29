#!/usr/bin/env python3
"""
Test script for ODIADEV API endpoints
"""

import requests
import json
import time
import base64

BASE_URL = "http://localhost:5000"

def test_health_endpoint():
    """Test the health check endpoint"""
    print("Testing health endpoint...")
    
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
        
    except Exception as e:
        print(f"Error testing health: {e}")
        return False

def test_tts_endpoint():
    """Test the TTS endpoint"""
    print("Testing TTS endpoint...")
    
    test_data = {
        "text": "Hello, this is a test of the ODIADEV TTS service. Welcome to our platform!",
        "voice": "alloy",
        "provider": "openai"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/tts", json=test_data)
        print(f"Status Code: {response.status_code}")
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        
        if response.status_code == 200 and result.get('success'):
            # Check if audio data is present
            if result.get('data', {}).get('audio_base64'):
                print("âœ… TTS generation successful - Audio data received")
                return True
            else:
                print("âŒ TTS generation failed - No audio data")
                return False
        else:
            print(f"âŒ TTS generation failed: {result.get('error', 'Unknown error')}")
            return False
        
    except Exception as e:
        print(f"Error testing TTS: {e}")
        return False

def test_signup_endpoint():
    """Test the signup endpoint"""
    print("Testing signup endpoint...")
    
    test_data = {
        "full_name": "Test User",
        "phone": "08123456789",
        "business_name": "Test Business",
        "plan_tier": "starter",
        "voice_option": True
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/signup", json=test_data)
        print(f"Status Code: {response.status_code}")
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        
        if response.status_code == 200:
            return result.get('client_id')
        
    except Exception as e:
        print(f"Error testing signup: {e}")
    
    return None

def test_status_endpoint(client_id):
    """Test the status endpoint"""
    if not client_id:
        print("No client ID to test status endpoint")
        return False
    
    print(f"Testing status endpoint for client {client_id}...")
    
    try:
        response = requests.get(f"{BASE_URL}/api/status/{client_id}")
        print(f"Status Code: {response.status_code}")
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        return response.status_code == 200
        
    except Exception as e:
        print(f"Error testing status: {e}")
        return False

def test_logs_endpoint():
    """Test the logs endpoint"""
    print("Testing logs endpoint...")
    
    try:
        response = requests.get(f"{BASE_URL}/api/logs?limit=10")
        print(f"Status Code: {response.status_code}")
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        return response.status_code == 200
        
    except Exception as e:
        print(f"Error testing logs: {e}")
        return False

def main():
    """Run all tests"""
    print("Starting ODIADEV API tests...")
    print("=" * 50)
    
    # Wait a moment for server to start
    time.sleep(2)
    
    test_results = []
    
    # Test health check
    test_results.append(("Health Check", test_health_endpoint()))
    print("\n" + "=" * 50)
    
    # Test TTS endpoint
    test_results.append(("TTS Generation", test_tts_endpoint()))
    print("\n" + "=" * 50)
    
    # Test signup
    client_id = test_signup_endpoint()
    test_results.append(("Signup", client_id is not None))
    print("\n" + "=" * 50)
    
    # Test status
    test_results.append(("Status Check", test_status_endpoint(client_id)))
    print("\n" + "=" * 50)
    
    # Test logs
    test_results.append(("Logs", test_logs_endpoint()))
    print("\n" + "=" * 50)
    
    # Summary
    print("Test Results Summary:")
    print("=" * 50)
    passed = 0
    for test_name, result in test_results:
        status = "âœ… PASSED" if result else "âŒ FAILED"
        print(f"{test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\nOverall: {passed}/{len(test_results)} tests passed")
    print("Tests completed!")

if __name__ == "__main__":
    main()

