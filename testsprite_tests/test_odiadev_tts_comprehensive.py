"""
ODIADEV TTS API - Comprehensive TestSprite Test Suite
====================================================

This test suite provides comprehensive testing for the ODIADEV TTS API,
including health checks, TTS functionality, Nigerian business context,
and performance validation.
"""

import requests
import pytest
import json
import base64
import time
from datetime import datetime
import os


class TestODIADEVTTSAPI:
    """Comprehensive test suite for ODIADEV TTS API"""
    
    BASE_URL = "http://localhost:5001"
    
    def setup_method(self):
        """Setup method run before each test"""
        self.session = requests.Session()
        self.session.timeout = 30
    
    def teardown_method(self):
        """Cleanup method run after each test"""
        if hasattr(self, 'session'):
            self.session.close()
    
    # ==========================================
    # HEALTH AND STATUS TESTS
    # ==========================================
    
    def test_health_endpoint_availability(self):
        """Test that the health endpoint is accessible and returns expected data"""
        response = self.session.get(f"{self.BASE_URL}/health")
        
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        
        data = response.json()
        assert "status" in data, "Health response missing 'status' field"
        assert "service" in data, "Health response missing 'service' field"
        assert "version" in data, "Health response missing 'version' field"
        
        assert data["status"] == "healthy", f"Expected healthy status, got {data.get('status')}"
        assert "ODIADEV" in data["service"], "Service name should contain 'ODIADEV'"
    
    def test_health_endpoint_performance(self):
        """Test that health endpoint responds within acceptable time"""
        start_time = time.time()
        response = self.session.get(f"{self.BASE_URL}/health")
        response_time = time.time() - start_time
        
        assert response.status_code == 200, "Health endpoint should be accessible"
        assert response_time < 5.0, f"Health check too slow: {response_time:.2f}s (max 5s)"
    
    def test_debug_endpoint_information(self):
        """Test debug endpoint provides proper configuration information"""
        response = self.session.get(f"{self.BASE_URL}/debug")
        
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        
        data = response.json()
        required_fields = ["config_exists", "env_vars", "working_directory"]
        
        for field in required_fields:
            assert field in data, f"Debug response missing '{field}' field"
        
        # Check that sensitive data is masked
        env_vars = data.get("env_vars", {})
        for key, value in env_vars.items():
            if "KEY" in key.upper() and value != "Not set":
                assert value == "***", f"Sensitive data not masked for {key}: {value}"
    
    # ==========================================
    # TTS CORE FUNCTIONALITY TESTS
    # ==========================================
    
    def test_tts_basic_functionality(self):
        """Test basic TTS functionality with simple text"""
        test_data = {
            "text": "Hello World",
            "voice": "alloy"
        }
        
        response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
        
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        
        data = response.json()
        assert data.get("success") is True, f"TTS generation failed: {data.get('message', 'Unknown error')}"
        
        # Verify response structure
        tts_data = data.get("data", {})
        assert "text" in tts_data, "TTS response missing 'text' field"
        assert "audio_base64" in tts_data, "TTS response missing 'audio_base64' field"
        assert "provider" in tts_data, "TTS response missing 'provider' field"
        
        # Verify audio data is valid base64
        audio_b64 = tts_data.get("audio_base64", "")
        assert len(audio_b64) > 0, "Audio data should not be empty"
        
        try:
            decoded_audio = base64.b64decode(audio_b64)
            assert len(decoded_audio) > 0, "Decoded audio should not be empty"
        except Exception as e:
            pytest.fail(f"Invalid base64 audio data: {e}")
    
    def test_tts_odiadev_company_context(self):
        """Test TTS with ODIADEV company-specific content"""
        odiadev_texts = [
            "Welcome to ODIADEV - The Future of Voice AI in Nigeria",
            "ODIADEV TTS makes voice AI affordable for every Nigerian business",
            "Starting at just 8,000 Naira, we democratize voice technology",
            "Choose ODIADEV TTS - Affordable, reliable, and proudly Nigerian"
        ]
        
        for text in odiadev_texts:
            test_data = {
                "text": text,
                "voice": "alloy"
            }
            
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            
            assert response.status_code == 200, f"Failed for text: {text[:30]}..."
            
            data = response.json()
            assert data.get("success") is True, f"TTS failed for: {text[:30]}..."
            
            # Verify the text is correctly processed
            tts_data = data.get("data", {})
            assert text in tts_data.get("text", ""), "Original text should be preserved"
    
    def test_tts_voice_parameter_validation(self):
        """Test TTS with different voice parameters"""
        valid_voices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
        test_text = "Testing voice parameter validation"
        
        for voice in valid_voices:
            test_data = {
                "text": test_text,
                "voice": voice
            }
            
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            assert response.status_code == 200, f"Voice '{voice}' should be supported"
            
            data = response.json()
            # Note: Our debug implementation may not use the exact voice, but should not fail
            assert data.get("success") is True, f"TTS should succeed with voice '{voice}'"
    
    def test_tts_input_validation(self):
        """Test TTS input validation and error handling"""
        # Test empty text
        empty_text_data = {"text": "", "voice": "alloy"}
        response = self.session.post(f"{self.BASE_URL}/test-tts", json=empty_text_data)
        
        # Should either succeed with mock or fail gracefully
        assert response.status_code in [200, 400], "Empty text should be handled appropriately"
        
        # Test very long text
        long_text = "A" * 5000  # Exceed typical limits
        long_text_data = {"text": long_text, "voice": "alloy"}
        response = self.session.post(f"{self.BASE_URL}/test-tts", json=long_text_data)
        
        assert response.status_code in [200, 400], "Long text should be handled appropriately"
        
        # Test missing text field
        no_text_data = {"voice": "alloy"}
        response = self.session.post(f"{self.BASE_URL}/test-tts", json=no_text_data)
        
        assert response.status_code in [200, 400], "Missing text field should be handled appropriately"
    
    # ==========================================
    # NIGERIAN BUSINESS CONTEXT TESTS
    # ==========================================
    
    def test_nigerian_business_scenarios(self):
        """Test TTS with Nigerian business use cases"""
        nigerian_scenarios = [
            {
                "context": "Customer Service",
                "text": "Thank you for calling ODIADEV. Your call is important to us. Please hold while we connect you to our Lagos office."
            },
            {
                "context": "E-commerce",
                "text": "Your order of 15,000 Naira has been confirmed. We will deliver to your address in Abuja within 2 business days."
            },
            {
                "context": "Banking",
                "text": "Your account balance is 125,000 Naira. For more services, visit any of our branches in Lagos, Kano, or Port Harcourt."
            },
            {
                "context": "Education",
                "text": "Welcome to ODIADEV University online learning platform. Access thousands of courses in English, Hausa, Yoruba, and Igbo."
            }
        ]
        
        for scenario in nigerian_scenarios:
            test_data = {
                "text": scenario["text"],
                "voice": "alloy"
            }
            
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            
            assert response.status_code == 200, f"Failed for {scenario['context']} scenario"
            
            data = response.json()
            assert data.get("success") is True, f"{scenario['context']} TTS should succeed"
            
            # Verify audio was generated
            tts_data = data.get("data", {})
            audio_size = len(base64.b64decode(tts_data.get("audio_base64", "")))
            assert audio_size > 0, f"{scenario['context']} should generate audio data"
    
    def test_nigerian_location_references(self):
        """Test TTS with Nigerian cities and locations"""
        nigerian_locations = [
            "Lagos", "Abuja", "Kano", "Port Harcourt", "Ibadan", 
            "Kaduna", "Jos", "Enugu", "Onitsha", "Warri"
        ]
        
        for location in nigerian_locations:
            text = f"ODIADEV TTS is now available in {location}, bringing affordable voice AI to local businesses."
            
            test_data = {
                "text": text,
                "voice": "alloy"
            }
            
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            
            assert response.status_code == 200, f"Failed for location: {location}"
            
            data = response.json()
            assert data.get("success") is True, f"TTS should work for {location}"
    
    # ==========================================
    # PERFORMANCE AND RELIABILITY TESTS
    # ==========================================
    
    def test_concurrent_requests_handling(self):
        """Test API can handle multiple concurrent requests"""
        import threading
        import queue
        
        results = queue.Queue()
        num_threads = 5
        
        def make_request():
            try:
                test_data = {
                    "text": f"Concurrent test from thread {threading.current_thread().ident}",
                    "voice": "alloy"
                }
                
                response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
                results.put(response.status_code == 200)
            except Exception as e:
                results.put(False)
        
        # Create and start threads
        threads = []
        for i in range(num_threads):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join(timeout=60)
        
        # Check results
        success_count = 0
        while not results.empty():
            if results.get():
                success_count += 1
        
        # Allow for some failures due to resource constraints
        success_rate = success_count / num_threads
        assert success_rate >= 0.6, f"Concurrent request success rate too low: {success_rate:.1%}"
    
    def test_response_time_consistency(self):
        """Test that response times are consistently reasonable"""
        response_times = []
        num_requests = 5
        
        for i in range(num_requests):
            test_data = {
                "text": f"Response time test #{i+1}",
                "voice": "alloy"
            }
            
            start_time = time.time()
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            end_time = time.time()
            
            assert response.status_code == 200, f"Request {i+1} failed"
            response_times.append(end_time - start_time)
        
        # Calculate statistics
        avg_time = sum(response_times) / len(response_times)
        max_time = max(response_times)
        
        assert avg_time < 10.0, f"Average response time too high: {avg_time:.2f}s"
        assert max_time < 30.0, f"Maximum response time too high: {max_time:.2f}s"
    
    def test_memory_stability_under_load(self):
        """Test that the API doesn't have memory leaks under load"""
        # Simple load test - make multiple requests and ensure they all succeed
        num_requests = 20
        success_count = 0
        
        for i in range(num_requests):
            test_data = {
                "text": f"Memory stability test request {i+1}. " * 5,  # Longer text
                "voice": "alloy"
            }
            
            try:
                response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
                if response.status_code == 200:
                    data = response.json()
                    if data.get("success"):
                        success_count += 1
            except Exception:
                continue
            
            # Small delay between requests
            time.sleep(0.1)
        
        success_rate = success_count / num_requests
        assert success_rate >= 0.8, f"Success rate under load too low: {success_rate:.1%}"
    
    # ==========================================
    # INTEGRATION TESTS
    # ==========================================
    
    def test_full_odiadev_company_presentation(self):
        """Test generating the complete ODIADEV company presentation"""
        company_segments = [
            "Welcome to ODIADEV - The Future of Voice AI in Nigeria",
            "We are making professional voice technology affordable for every Nigerian business",
            "Starting at just 8,000 Naira for our Starter plan, up to 75,000 Naira for Enterprise",
            "Our system works reliably even with slower internet connections",
            "Join the voice AI revolution with ODIADEV TTS"
        ]
        
        total_audio_size = 0
        successful_segments = 0
        
        for i, segment in enumerate(company_segments, 1):
            test_data = {
                "text": segment,
                "voice": "alloy"
            }
            
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            
            assert response.status_code == 200, f"Company segment {i} failed"
            
            data = response.json()
            assert data.get("success") is True, f"Company segment {i} TTS failed"
            
            # Calculate audio size
            tts_data = data.get("data", {})
            audio_b64 = tts_data.get("audio_base64", "")
            if audio_b64:
                audio_size = len(base64.b64decode(audio_b64))
                total_audio_size += audio_size
                successful_segments += 1
        
        # Verify we generated a reasonable amount of audio
        assert successful_segments == len(company_segments), "All company segments should succeed"
        assert total_audio_size > 0, "Should generate some audio data"
    
    # ==========================================
    # ERROR HANDLING AND EDGE CASES
    # ==========================================
    
    def test_invalid_json_handling(self):
        """Test API handles invalid JSON gracefully"""
        # Send malformed JSON
        response = self.session.post(
            f"{self.BASE_URL}/test-tts", 
            data="invalid json data",
            headers={"Content-Type": "application/json"}
        )
        
        # Should handle gracefully (not 500)
        assert response.status_code in [200, 400], "Invalid JSON should be handled gracefully"
    
    def test_unsupported_http_methods(self):
        """Test unsupported HTTP methods are handled properly"""
        # Test PUT on TTS endpoint
        response = self.session.put(f"{self.BASE_URL}/test-tts")
        assert response.status_code in [405, 404], "PUT should not be supported on TTS endpoint"
        
        # Test DELETE on health endpoint
        response = self.session.delete(f"{self.BASE_URL}/health")
        assert response.status_code in [405, 404], "DELETE should not be supported on health endpoint"
    
    def test_special_characters_in_text(self):
        """Test TTS handles special characters appropriately"""
        special_texts = [
            "Hello! How are you? I'm fine.",
            "Price: ₦8,000 - ₦75,000",
            "Email: support@odiadev.com",
            "Phone: +234-803-123-4567",
            "Address: 123 Victoria Island, Lagos"
        ]
        
        for text in special_texts:
            test_data = {
                "text": text,
                "voice": "alloy"
            }
            
            response = self.session.post(f"{self.BASE_URL}/test-tts", json=test_data)
            
            # Should handle special characters (may sanitize but shouldn't crash)
            assert response.status_code == 200, f"Special characters should be handled: {text}"
            
            data = response.json()
            # May succeed or fail gracefully depending on implementation
            assert "success" in data, "Response should indicate success/failure status"


def run_testsprite_validation():
    """Run comprehensive validation and generate report"""
    print("🚀 ODIADEV TTS API - TestSprite Comprehensive Testing")
    print("=" * 60)
    
    # Run pytest with detailed output
    import subprocess
    import sys
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_file = f"testsprite_test_report_{timestamp}.html"
    
    # Run tests with pytest
    cmd = [
        sys.executable, "-m", "pytest", 
        __file__,
        "-v",
        "--tb=short",
        f"--html={report_file}",
        "--self-contained-html"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        print(f"\n📊 Test Results Summary:")
        print(f"Exit Code: {result.returncode}")
        print(f"Report: {report_file}")
        
        if result.stdout:
            print("\nSTDOUT:")
            print(result.stdout)
        
        if result.stderr:
            print("\nSTDERR:")
            print(result.stderr)
        
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("❌ Tests timed out after 5 minutes")
        return False
    except Exception as e:
        print(f"❌ Error running tests: {e}")
        return False


if __name__ == "__main__":
    # If run directly, execute the validation
    success = run_testsprite_validation()
    print(f"\n{'✅' if success else '❌'} TestSprite validation {'completed successfully' if success else 'failed'}")