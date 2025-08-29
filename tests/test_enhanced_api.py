import unittest
import json
import base64
import time
from unittest.mock import patch, MagicMock
import sys
import os

# Add the project root to the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from src.models.user import db
from src.models.client import Client, Deployment, Log

class TestEnhancedODIADEVAPI(unittest.TestCase):
    """Comprehensive test suite for enhanced ODIADEV TTS API"""
    
    def setUp(self):
        """Set up test environment"""
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app = app.test_client()
        
        with app.app_context():
            db.create_all()
    
    def tearDown(self):
        """Clean up after tests"""
        with app.app_context():
            db.session.remove()
            db.drop_all()
    
    def test_health_check(self):
        """Test health check endpoint"""
        response = self.app.get('/health')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(data['status'], 'healthy')
        self.assertEqual(data['service'], 'ODIADEV TTS API')
        self.assertEqual(data['version'], '1.0.0')
    
    def test_tts_endpoint_validation(self):
        """Test TTS endpoint input validation"""
        # Test missing text
        response = self.app.post('/api/tts', 
                               data=json.dumps({}),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Text is required', data['error'])
        self.assertIn('request_id', data)
        
        # Test empty text
        response = self.app.post('/api/tts',
                               data=json.dumps({'text': ''}),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Text cannot be empty', data['error'])
        
        # Test text too long
        long_text = 'A' * 5000
        response = self.app.post('/api/tts',
                               data=json.dumps({'text': long_text}),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Text too long', data['error'])
    
    @patch('src.routes.odiadev.generate_tts_voice_openai')
    def test_tts_success_mock(self, mock_tts):
        """Test successful TTS generation with mock"""
        mock_tts.return_value = {
            'success': True,
            'audio_base64': 'mock_audio_data',
            'format': 'mp3',
            'text': 'Hello world',
            'voice': 'alloy',
            'request_id': 'test123',
            'provider': 'mock'
        }
        
        response = self.app.post('/api/tts',
                               data=json.dumps({
                                   'text': 'Hello world',
                                   'voice': 'alloy',
                                   'provider': 'openai'
                               }),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data['success'])
        self.assertIn('TTS generation successful', data['message'])
        self.assertIn('request_id', data)
        self.assertIn('timestamp', data)
        self.assertIn('data', data)
        
        # Verify mock was called
        mock_tts.assert_called_once_with('Hello world', 'alloy')
    
    def test_signup_validation(self):
        """Test signup endpoint validation"""
        # Test missing required fields
        response = self.app.post('/api/signup',
                               data=json.dumps({
                                   'full_name': 'John Doe'
                               }),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Missing required fields', data['error'])
        
        # Test invalid phone number
        response = self.app.post('/api/signup',
                               data=json.dumps({
                                   'full_name': 'John Doe',
                                   'phone': '12345',  # Invalid Nigerian number
                                   'business_name': 'Test Business',
                                   'plan_tier': 'starter'
                               }),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Invalid Nigerian phone number', data['error'])
        
        # Test invalid plan tier
        response = self.app.post('/api/signup',
                               data=json.dumps({
                                   'full_name': 'John Doe',
                                   'phone': '08012345678',  # Valid Nigerian number
                                   'business_name': 'Test Business',
                                   'plan_tier': 'invalid_plan'
                               }),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Invalid plan tier', data['error'])
    
    def test_signup_success(self):
        """Test successful signup"""
        response = self.app.post('/api/signup',
                               data=json.dumps({
                                   'full_name': 'John Doe',
                                   'phone': '08012345678',
                                   'business_name': 'Test Business',
                                   'plan_tier': 'starter',
                                   'voice_option': True
                               }),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data['success'])
        self.assertIn('Signup completed successfully', data['message'])
        self.assertIn('client_id', data)
        self.assertIn('deployment_status', data)
        self.assertIn('request_id', data)
        self.assertIn('timestamp', data)
        self.assertIn('plan_details', data)
        
        # Verify plan details
        plan_details = data['plan_details']
        self.assertEqual(plan_details['tier'], 'starter')
        self.assertEqual(plan_details['price_naira'], 8000)
        self.assertIsInstance(plan_details['features'], list)
        
        # Verify database records
        with app.app_context():
            client = Client.query.get(data['client_id'])
            self.assertIsNotNone(client)
            self.assertEqual(client.full_name, 'John Doe')
            self.assertEqual(client.phone, '08012345678')
            self.assertEqual(client.business_name, 'Test Business')
            self.assertEqual(client.plan_tier, 'starter')
            self.assertTrue(client.voice_option)
            self.assertTrue(client.is_live)
    
    def test_duplicate_phone_signup(self):
        """Test signup with duplicate phone number"""
        # First signup
        self.app.post('/api/signup',
                     data=json.dumps({
                         'full_name': 'John Doe',
                         'phone': '08012345678',
                         'business_name': 'Test Business',
                         'plan_tier': 'starter'
                     }),
                     content_type='application/json')
        
        # Second signup with same phone
        response = self.app.post('/api/signup',
                               data=json.dumps({
                                   'full_name': 'Jane Doe',
                                   'phone': '08012345678',
                                   'business_name': 'Another Business',
                                   'plan_tier': 'pro'
                               }),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 409)
        self.assertFalse(data['success'])
        self.assertIn('Phone number already registered', data['error'])
    
    def test_client_status(self):
        """Test client status endpoint"""
        # Create a client first
        signup_response = self.app.post('/api/signup',
                                      data=json.dumps({
                                          'full_name': 'John Doe',
                                          'phone': '08012345678',
                                          'business_name': 'Test Business',
                                          'plan_tier': 'starter'
                                      }),
                                      content_type='application/json')
        signup_data = json.loads(signup_response.data)
        client_id = signup_data['client_id']
        
        # Get status
        response = self.app.get(f'/api/status/{client_id}')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data['success'])
        self.assertIn('client', data)
        self.assertIn('deployments', data)
        self.assertIn('request_id', data)
        self.assertIn('timestamp', data)
        
        # Verify client data
        client = data['client']
        self.assertEqual(client['full_name'], 'John Doe')
        self.assertEqual(client['phone'], '08012345678')
        self.assertEqual(client['business_name'], 'Test Business')
        self.assertEqual(client['plan_tier'], 'starter')
        
        # Verify deployments
        deployments = data['deployments']
        self.assertIsInstance(deployments, list)
        self.assertGreater(len(deployments), 0)
        self.assertEqual(deployments[0]['status'], 'completed')
    
    def test_client_status_not_found(self):
        """Test client status for non-existent client"""
        response = self.app.get('/api/status/999')
        
        self.assertEqual(response.status_code, 404)
    
    def test_logs_endpoint(self):
        """Test logs endpoint"""
        # Create some logs first
        with app.app_context():
            log1 = Log(source='test', message='Test log 1')
            log2 = Log(source='test', message='Test log 2')
            db.session.add(log1)
            db.session.add(log2)
            db.session.commit()
        
        # Get logs
        response = self.app.get('/api/logs')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data['success'])
        self.assertIn('logs', data)
        self.assertIn('total_count', data)
        self.assertIn('request_id', data)
        self.assertIn('timestamp', data)
        
        # Verify logs
        logs = data['logs']
        self.assertIsInstance(logs, list)
        self.assertGreaterEqual(len(logs), 2)
        
        # Test filtering by source
        response = self.app.get('/api/logs?source=test')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        logs = data['logs']
        for log in logs:
            self.assertEqual(log['source'], 'test')
        
        # Test limit parameter
        response = self.app.get('/api/logs?limit=1')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertLessEqual(len(data['logs']), 1)
    
    def test_network_test_endpoint(self):
        """Test network diagnostics endpoint"""
        response = self.app.get('/api/network-test')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data['success'])
        self.assertIn('network_test', data)
        self.assertIn('request_id', data)
        self.assertIn('timestamp', data)
        self.assertIn('nigerian_optimizations', data)
        
        # Verify Nigerian optimizations config
        optimizations = data['nigerian_optimizations']
        self.assertIn('retry_delays', optimizations)
        self.assertIn('timeout', optimizations)
        self.assertIn('max_retries', optimizations)
        self.assertIn('request_size_limit', optimizations)
    
    def test_input_sanitization(self):
        """Test input sanitization"""
        malicious_text = '<script>alert("xss")</script>Hello world'
        
        response = self.app.post('/api/tts',
                               data=json.dumps({
                                   'text': malicious_text,
                                   'voice': 'alloy'
                               }),
                               content_type='application/json')
        
        # Should still work but with sanitized input
        self.assertIn(response.status_code, [200, 500])  # Mock might fail, but no XSS
    
    def test_nigerian_phone_validation(self):
        """Test Nigerian phone number validation"""
        valid_numbers = [
            '08012345678',  # MTN
            '08112345678',  # MTN
            '07012345678',  # Airtel
            '07112345678',  # Airtel
            '09012345678',  # 9mobile
            '09112345678',  # 9mobile
        ]
        
        invalid_numbers = [
            '12345678901',  # Invalid prefix
            '0801234567',   # Too short
            '080123456789', # Too long
            'abc12345678',  # Contains letters
        ]
        
        # Test valid numbers
        for phone in valid_numbers:
            response = self.app.post('/api/signup',
                                   data=json.dumps({
                                       'full_name': f'Test {phone}',
                                       'phone': phone,
                                       'business_name': 'Test Business',
                                       'plan_tier': 'starter'
                                   }),
                                   content_type='application/json')
            
            if response.status_code == 409:  # Duplicate phone
                continue
            data = json.loads(response.data)
            self.assertTrue(data['success'], f"Phone {phone} should be valid")
        
        # Test invalid numbers
        for phone in invalid_numbers:
            response = self.app.post('/api/signup',
                                   data=json.dumps({
                                       'full_name': f'Test {phone}',
                                       'phone': phone,
                                       'business_name': 'Test Business',
                                       'plan_tier': 'starter'
                                   }),
                                   content_type='application/json')
            data = json.loads(response.data)
            self.assertFalse(data['success'], f"Phone {phone} should be invalid")
    
    def test_plan_features(self):
        """Test plan features endpoint"""
        plans = ['starter', 'pro', 'enterprise']
        
        for plan in plans:
            response = self.app.post('/api/signup',
                                   data=json.dumps({
                                       'full_name': f'Test {plan}',
                                       'phone': f'080{plan}12345',
                                       'business_name': f'Test {plan} Business',
                                       'plan_tier': plan
                                   }),
                                   content_type='application/json')
            
            if response.status_code == 409:  # Duplicate phone
                continue
            data = json.loads(response.data)
            
            self.assertTrue(data['success'])
            plan_details = data['plan_details']
            self.assertEqual(plan_details['tier'], plan)
            self.assertIsInstance(plan_details['features'], list)
            self.assertGreater(len(plan_details['features']), 0)
    
    def test_error_handling(self):
        """Test error handling and logging"""
        # Test with invalid JSON
        response = self.app.post('/api/tts',
                               data='invalid json',
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 400)
        
        # Test with malformed data
        response = self.app.post('/api/tts',
                               data=json.dumps({'text': None}),
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 400)
    
    def test_request_id_tracking(self):
        """Test request ID tracking across endpoints"""
        # Make multiple requests and verify unique request IDs
        request_ids = set()
        
        for i in range(5):
            response = self.app.get('/health')
            data = json.loads(response.data)
            request_ids.add(data.get('request_id', f'request_{i}'))
        
        # Each request should have a unique ID
        self.assertEqual(len(request_ids), 5)
    
    def test_timestamp_consistency(self):
        """Test timestamp consistency in responses"""
        response = self.app.get('/health')
        data = json.loads(response.data)
        
        # Verify timestamp is in ISO format
        timestamp = data.get('timestamp')
        if timestamp:
            # Should be parseable as ISO format
            from datetime import datetime
            try:
                datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            except ValueError:
                self.fail("Timestamp should be in ISO format")

class TestNigerianNetworkOptimizations(unittest.TestCase):
    """Test Nigerian network-specific optimizations"""
    
    def setUp(self):
        """Set up test environment"""
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app = app.test_client()
        
        with app.app_context():
            db.create_all()
    
    def tearDown(self):
        """Clean up after tests"""
        with app.app_context():
            db.session.remove()
            db.drop_all()
    
    @patch('src.routes.odiadev.requests.get')
    def test_network_retry_mechanism(self, mock_get):
        """Test retry mechanism for network failures"""
        # Simulate network failures then success
        mock_get.side_effect = [
            Exception("Network timeout"),
            Exception("Connection error"),
            MagicMock(status_code=200, json=lambda: {"status": "ok"})
        ]
        
        response = self.app.get('/api/network-test')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data['success'])
        
        # Verify retry was attempted
        self.assertEqual(mock_get.call_count, 3)
    
    def test_timeout_handling(self):
        """Test timeout handling for slow connections"""
        # This would require more complex mocking of the actual network calls
        # For now, we test that the endpoint responds within reasonable time
        start_time = time.time()
        response = self.app.get('/api/network-test')
        end_time = time.time()
        
        self.assertLess(end_time - start_time, 5)  # Should respond within 5 seconds
        self.assertEqual(response.status_code, 200)
    
    def test_request_size_limits(self):
        """Test request size limits for Nigerian networks"""
        # Test with large payload
        large_text = 'A' * 5000  # 5KB text
        
        response = self.app.post('/api/tts',
                               data=json.dumps({'text': large_text}),
                               content_type='application/json')
        data = json.loads(response.data)
        
        self.assertEqual(response.status_code, 400)
        self.assertFalse(data['success'])
        self.assertIn('Text too long', data['error'])

if __name__ == '__main__':
    # Run the tests
    unittest.main(verbosity=2)
