#!/usr/bin/env python3
"""
ODIADEV TTS API Test Suite
Tests for FastAPI-based TTS service with Supabase integration
"""

import requests
import json
import time
import os
import sys
from typing import Optional

# Test configuration
BASE_URL = "http://localhost:8080"  # Docker compose exposes on 8080
ADMIN_TOKEN_FILE = "secrets/ADMIN_TOKEN.txt"

class TTSAPITester:
    def __init__(self, base_url: str = BASE_URL):
        self.base_url = base_url
        self.admin_token = self._load_admin_token()
        self.test_api_key: Optional[str] = None
        
    def _load_admin_token(self) -> Optional[str]:
        """Load admin token from secrets file"""
        try:
            if os.path.exists(ADMIN_TOKEN_FILE):
                with open(ADMIN_TOKEN_FILE, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            print(f"Warning: Could not load admin token: {e}")
        return None
    
    def test_health_endpoint(self) -> bool:
        """Test the /health endpoint"""
        print("ðŸ” Testing /health endpoint...")
        
        try:
            response = requests.get(f"{self.base_url}/health", timeout=10)
            print(f"   Status Code: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"   Response: {json.dumps(data, indent=2)}")
                
                # Validate expected fields
                if "status" in data and "engine" in data:
                    print("   âœ… Health check passed")
                    return True
                else:
                    print("   âŒ Health check response missing required fields")
                    return False
            else:
                print(f"   âŒ Health check failed with status {response.status_code}")
                return False
                
        except Exception as e:
            print(f"   âŒ Error testing health endpoint: {e}")
            return False
    
    def test_voices_endpoint(self) -> bool:
        """Test the /v1/voices endpoint"""
        print("ðŸ” Testing /v1/voices endpoint...")
        
        try:
            response = requests.get(f"{self.base_url}/v1/voices", timeout=10)
            print(f"   Status Code: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"   Response: {json.dumps(data, indent=2)}")
                
                if "voices" in data and isinstance(data["voices"], list):
                    print("   âœ… Voices endpoint passed")
                    return True
                else:
                    print("   âŒ Voices endpoint response invalid")
                    return False
            else:
                print(f"   âŒ Voices endpoint failed with status {response.status_code}")
                return False
                
        except Exception as e:
            print(f"   âŒ Error testing voices endpoint: {e}")
            return False
    
    def test_admin_key_issue(self) -> bool:
        """Test admin key issuance endpoint"""
        print("ðŸ” Testing /admin/keys/issue endpoint...")
        
        if not self.admin_token:
            print("   âš ï¸  No admin token available - skipping admin tests")
            return False
        
        try:
            headers = {
                "x-admin-token": self.admin_token,
                "Content-Type": "application/json"
            }
            
            payload = {
                "label": "test-key",
                "rate_limit_per_min": 10
            }
            
            response = requests.post(
                f"{self.base_url}/admin/keys/issue",
                headers=headers,
                json=payload,
                timeout=10
            )
            
            print(f"   Status Code: {response.status_code}")
            
            if response.status_code in [200, 201]:
                data = response.json()
                print(f"   Response: {json.dumps({k: v for k, v in data.items() if k != 'plaintext_key'}, indent=2)}")
                
                if "plaintext_key" in data:
                    self.test_api_key = data["plaintext_key"]
                    print("   âœ… Admin key issuance passed")
                    return True
                else:
                    print("   âŒ Admin key issuance response missing plaintext_key")
                    return False
            else:
                print(f"   âŒ Admin key issuance failed with status {response.status_code}")
                try:
                    print(f"   Error: {response.json()}")
                except:
                    print(f"   Error: {response.text}")
                return False
                
        except Exception as e:
            print(f"   âŒ Error testing admin key issuance: {e}")
            return False
    
    def test_tts_endpoint(self) -> bool:
        """Test the /v1/tts endpoint"""
        print("ðŸ” Testing /v1/tts endpoint...")
        
        if not self.test_api_key:
            print("   âš ï¸  No API key available - skipping TTS test")
            return False
        
        try:
            headers = {
                "x-api-key": self.test_api_key,
                "Content-Type": "application/json"
            }
            
            payload = {
                "text": "Hello from ODIADEV TTS API test!",
                "voice": "naija_female",
                "format": "mp3",
                "speed": 1.0
            }
            
            response = requests.post(
                f"{self.base_url}/v1/tts",
                headers=headers,
                json=payload,
                timeout=30  # TTS can take longer
            )
            
            print(f"   Status Code: {response.status_code}")
            
            if response.status_code == 200:
                content_type = response.headers.get("content-type", "")
                
                if "application/json" in content_type:
                    # JSON response with S3 URL
                    data = response.json()
                    print(f"   Response: {json.dumps(data, indent=2)}")
                    
                    if "url" in data or "format" in data:
                        print("   âœ… TTS generation passed (JSON response)")
                        return True
                    else:
                        print("   âŒ TTS JSON response missing expected fields")
                        return False
                        
                elif "audio" in content_type:
                    # Binary audio response
                    audio_size = len(response.content)
                    print(f"   Audio size: {audio_size} bytes")
                    
                    if audio_size > 0:
                        # Save test audio file
                        with open("test_output.mp3", "wb") as f:
                            f.write(response.content)
                        print("   âœ… TTS generation passed (audio response)")
                        return True
                    else:
                        print("   âŒ TTS audio response is empty")
                        return False
                else:
                    print(f"   âŒ Unexpected content type: {content_type}")
                    return False
            else:
                print(f"   âŒ TTS endpoint failed with status {response.status_code}")
                try:
                    print(f"   Error: {response.json()}")
                except:
                    print(f"   Error: {response.text}")
                return False
                
        except Exception as e:
            print(f"   âŒ Error testing TTS endpoint: {e}")
            return False
    
    def run_all_tests(self) -> dict:
        """Run all tests and return results"""
        print("ðŸš€ ODIADEV TTS API Test Suite")
        print("=" * 50)
        
        # Wait for service to be ready
        print("â³ Waiting for service to be ready...")
        time.sleep(3)
        
        test_results = {}
        
        # Test health endpoint
        test_results["health"] = self.test_health_endpoint()
        print()
        
        # Test voices endpoint
        test_results["voices"] = self.test_voices_endpoint()
        print()
        
        # Test admin key issuance
        test_results["admin_key"] = self.test_admin_key_issue()
        print()
        
        # Test TTS endpoint
        test_results["tts"] = self.test_tts_endpoint()
        print()
        
        # Summary
        print("=" * 50)
        print("ðŸ“Š Test Results Summary:")
        print("=" * 50)
        
        passed = 0
        total = len(test_results)
        
        for test_name, result in test_results.items():
            status = "âœ… PASSED" if result else "âŒ FAILED"
            print(f"   {test_name.title()}: {status}")
            if result:
                passed += 1
        
        print(f"\nðŸŽ¯ Overall: {passed}/{total} tests passed")
        
        if passed == total:
            print("ðŸŽ‰ All tests passed! API is working correctly.")
        else:
            print("âš ï¸  Some tests failed. Check the output above for details.")
        
        return test_results

def main():
    """Main test runner"""
    tester = TTSAPITester()
    results = tester.run_all_tests()
    
    # Exit with appropriate code
    all_passed = all(results.values())
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()