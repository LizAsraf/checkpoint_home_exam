"""
Unit tests for Microservice 1 - REST API
"""

import json
import pytest
from unittest.mock import patch, MagicMock
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Mock environment variables before importing app
os.environ['SQS_QUEUE_URL'] = 'https://sqs.us-east-1.amazonaws.com/123456789/test-queue'
os.environ['SSM_PARAMETER_NAME'] = '/test/api-token'
os.environ['AWS_REGION'] = 'us-east-1'

from app import app, validate_payload, REQUIRED_FIELDS


@pytest.fixture
def client():
    """Create test client."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


class TestHealthEndpoint:
    """Tests for /health endpoint."""
    
    def test_health_check_returns_200(self, client):
        """Health check should return 200 OK."""
        response = client.get('/health')
        assert response.status_code == 200
        
    def test_health_check_returns_healthy_status(self, client):
        """Health check should return healthy status."""
        response = client.get('/health')
        data = json.loads(response.data)
        assert data['status'] == 'healthy'


class TestRootEndpoint:
    """Tests for / endpoint."""
    
    def test_root_returns_200(self, client):
        """Root endpoint should return 200 OK."""
        response = client.get('/')
        assert response.status_code == 200
        
    def test_root_returns_service_info(self, client):
        """Root endpoint should return service info."""
        response = client.get('/')
        data = json.loads(response.data)
        assert 'service' in data
        assert 'endpoints' in data


class TestValidatePayload:
    """Tests for payload validation function."""
    
    def test_valid_payload(self):
        """Valid payload should pass validation."""
        valid_data = {
            'email_subject': 'Test Subject',
            'email_sender': 'John Doe',
            'email_timestream': '1693561101',
            'email_content': 'Test content'
        }
        is_valid, error = validate_payload(valid_data)
        assert is_valid is True
        assert error is None
    
    def test_missing_email_subject(self):
        """Missing email_subject should fail validation."""
        data = {
            'email_sender': 'John Doe',
            'email_timestream': '1693561101',
            'email_content': 'Test content'
        }
        is_valid, error = validate_payload(data)
        assert is_valid is False
        assert 'email_subject' in error
    
    def test_missing_email_sender(self):
        """Missing email_sender should fail validation."""
        data = {
            'email_subject': 'Test Subject',
            'email_timestream': '1693561101',
            'email_content': 'Test content'
        }
        is_valid, error = validate_payload(data)
        assert is_valid is False
        assert 'email_sender' in error
    
    def test_missing_email_timestream(self):
        """Missing email_timestream should fail validation."""
        data = {
            'email_subject': 'Test Subject',
            'email_sender': 'John Doe',
            'email_content': 'Test content'
        }
        is_valid, error = validate_payload(data)
        assert is_valid is False
        assert 'email_timestream' in error
    
    def test_missing_email_content(self):
        """Missing email_content should fail validation."""
        data = {
            'email_subject': 'Test Subject',
            'email_sender': 'John Doe',
            'email_timestream': '1693561101'
        }
        is_valid, error = validate_payload(data)
        assert is_valid is False
        assert 'email_content' in error
    
    def test_empty_field(self):
        """Empty field should fail validation."""
        data = {
            'email_subject': '',
            'email_sender': 'John Doe',
            'email_timestream': '1693561101',
            'email_content': 'Test content'
        }
        is_valid, error = validate_payload(data)
        assert is_valid is False
        assert 'non-empty' in error
    
    def test_none_data(self):
        """None data should fail validation."""
        is_valid, error = validate_payload(None)
        assert is_valid is False
        assert 'Missing' in error
    
    def test_empty_data(self):
        """Empty data should fail validation."""
        is_valid, error = validate_payload({})
        assert is_valid is False


class TestMessageEndpoint:
    """Tests for /api/message endpoint."""
    
    def test_missing_json_body(self, client):
        """Request without JSON body should return 400."""
        response = client.post('/api/message', content_type='application/json')
        assert response.status_code == 400
    
    def test_missing_token(self, client):
        """Request without token should return 401."""
        payload = {
            'data': {
                'email_subject': 'Test',
                'email_sender': 'John',
                'email_timestream': '123',
                'email_content': 'Content'
            }
        }
        response = client.post(
            '/api/message',
            data=json.dumps(payload),
            content_type='application/json'
        )
        assert response.status_code == 401
        data = json.loads(response.data)
        assert 'token' in data['error'].lower()
    
    @patch('app.validate_token')
    def test_invalid_token(self, mock_validate_token, client):
        """Request with invalid token should return 401."""
        mock_validate_token.return_value = False
        
        payload = {
            'data': {
                'email_subject': 'Test',
                'email_sender': 'John',
                'email_timestream': '123',
                'email_content': 'Content'
            },
            'token': 'invalid-token'
        }
        response = client.post(
            '/api/message',
            data=json.dumps(payload),
            content_type='application/json'
        )
        assert response.status_code == 401
    
    @patch('app.validate_token')
    def test_invalid_payload(self, mock_validate_token, client):
        """Request with invalid payload should return 400."""
        mock_validate_token.return_value = True
        
        payload = {
            'data': {
                'email_subject': 'Test'
                # Missing other required fields
            },
            'token': 'valid-token'
        }
        response = client.post(
            '/api/message',
            data=json.dumps(payload),
            content_type='application/json'
        )
        assert response.status_code == 400
    
    @patch('app.validate_token')
    @patch('app.send_to_sqs')
    def test_valid_request(self, mock_send_sqs, mock_validate_token, client):
        """Valid request should return 200 and send to SQS."""
        mock_validate_token.return_value = True
        mock_send_sqs.return_value = 'test-message-id'
        
        payload = {
            'data': {
                'email_subject': 'Test Subject',
                'email_sender': 'John Doe',
                'email_timestream': '1693561101',
                'email_content': 'Test content'
            },
            'token': 'valid-token'
        }
        response = client.post(
            '/api/message',
            data=json.dumps(payload),
            content_type='application/json'
        )
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert data['message_id'] == 'test-message-id'
        mock_send_sqs.assert_called_once()


class TestRequiredFields:
    """Tests for required fields constant."""
    
    def test_all_required_fields_present(self):
        """All 4 required fields should be defined."""
        assert len(REQUIRED_FIELDS) == 4
        assert 'email_subject' in REQUIRED_FIELDS
        assert 'email_sender' in REQUIRED_FIELDS
        assert 'email_timestream' in REQUIRED_FIELDS
        assert 'email_content' in REQUIRED_FIELDS


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
