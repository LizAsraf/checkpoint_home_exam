"""
Unit tests for Microservice 2 - SQS Worker
"""

import json
import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Mock environment variables before importing app
os.environ['SQS_QUEUE_URL'] = 'https://sqs.us-east-1.amazonaws.com/123456789/test-queue'
os.environ['S3_BUCKET_NAME'] = 'test-bucket'
os.environ['AWS_REGION'] = 'us-east-1'
os.environ['POLL_INTERVAL'] = '1'

from app import upload_to_s3, process_message, poll_sqs, delete_message


class TestPollSQS:
    """Tests for SQS polling function."""
    
    @patch('app.sqs_client')
    def test_poll_returns_messages(self, mock_sqs):
        """Should return messages from SQS."""
        mock_sqs.receive_message.return_value = {
            'Messages': [
                {'MessageId': '123', 'Body': '{}', 'ReceiptHandle': 'abc'}
            ]
        }
        
        messages = poll_sqs()
        assert len(messages) == 1
        assert messages[0]['MessageId'] == '123'
    
    @patch('app.sqs_client')
    def test_poll_returns_empty_when_no_messages(self, mock_sqs):
        """Should return empty list when no messages."""
        mock_sqs.receive_message.return_value = {}
        
        messages = poll_sqs()
        assert messages == []
    
    @patch('app.sqs_client')
    def test_poll_handles_client_error(self, mock_sqs):
        """Should return empty list on client error."""
        from botocore.exceptions import ClientError
        mock_sqs.receive_message.side_effect = ClientError(
            {'Error': {'Code': '500', 'Message': 'Error'}},
            'ReceiveMessage'
        )
        
        messages = poll_sqs()
        assert messages == []


class TestUploadToS3:
    """Tests for S3 upload function."""
    
    @patch('app.s3_client')
    def test_upload_success(self, mock_s3):
        """Should upload message to S3 successfully."""
        message_body = json.dumps({
            'email_subject': 'Test',
            'email_sender': 'John',
            'email_timestream': '123',
            'email_content': 'Content'
        })
        
        s3_key = upload_to_s3(message_body, 'test-message-id')
        
        assert s3_key.startswith('messages/')
        assert 'test-message-id' in s3_key
        assert s3_key.endswith('.json')
        mock_s3.put_object.assert_called_once()
    
    @patch('app.s3_client')
    def test_upload_includes_metadata(self, mock_s3):
        """Upload should include metadata."""
        message_body = json.dumps({'test': 'data'})
        
        upload_to_s3(message_body, 'msg-123')
        
        call_args = mock_s3.put_object.call_args
        body = json.loads(call_args.kwargs['Body'])
        
        assert 'data' in body
        assert 'metadata' in body
        assert body['metadata']['message_id'] == 'msg-123'
        assert body['metadata']['source'] == 'microservice2'
    
    def test_upload_invalid_json(self):
        """Should raise error for invalid JSON."""
        with pytest.raises(json.JSONDecodeError):
            upload_to_s3('not valid json', 'msg-123')
    
    @patch('app.s3_client')
    def test_upload_s3_error(self, mock_s3):
        """Should raise error on S3 failure."""
        from botocore.exceptions import ClientError
        mock_s3.put_object.side_effect = ClientError(
            {'Error': {'Code': '500', 'Message': 'Error'}},
            'PutObject'
        )
        
        with pytest.raises(ClientError):
            upload_to_s3('{"test": "data"}', 'msg-123')


class TestDeleteMessage:
    """Tests for SQS message deletion."""
    
    @patch('app.sqs_client')
    def test_delete_success(self, mock_sqs):
        """Should delete message from SQS."""
        delete_message('receipt-handle-123')
        
        mock_sqs.delete_message.assert_called_once()
        call_args = mock_sqs.delete_message.call_args
        assert call_args.kwargs['ReceiptHandle'] == 'receipt-handle-123'
    
    @patch('app.sqs_client')
    def test_delete_error(self, mock_sqs):
        """Should raise error on delete failure."""
        from botocore.exceptions import ClientError
        mock_sqs.delete_message.side_effect = ClientError(
            {'Error': {'Code': '500', 'Message': 'Error'}},
            'DeleteMessage'
        )
        
        with pytest.raises(ClientError):
            delete_message('receipt-handle-123')


class TestProcessMessage:
    """Tests for message processing function."""
    
    @patch('app.delete_message')
    @patch('app.upload_to_s3')
    def test_process_success(self, mock_upload, mock_delete):
        """Should process message successfully."""
        mock_upload.return_value = 'messages/2025/01/01/file.json'
        
        message = {
            'MessageId': 'msg-123',
            'Body': json.dumps({'test': 'data'}),
            'ReceiptHandle': 'receipt-123'
        }
        
        result = process_message(message)
        
        assert result is True
        mock_upload.assert_called_once()
        mock_delete.assert_called_once_with('receipt-123')
    
    @patch('app.delete_message')
    @patch('app.upload_to_s3')
    def test_process_upload_failure(self, mock_upload, mock_delete):
        """Should return False on upload failure."""
        mock_upload.side_effect = Exception('Upload failed')
        
        message = {
            'MessageId': 'msg-123',
            'Body': json.dumps({'test': 'data'}),
            'ReceiptHandle': 'receipt-123'
        }
        
        result = process_message(message)
        
        assert result is False
        mock_delete.assert_not_called()
    
    @patch('app.delete_message')
    @patch('app.upload_to_s3')
    def test_process_delete_failure(self, mock_upload, mock_delete):
        """Should return False on delete failure."""
        mock_upload.return_value = 'messages/file.json'
        mock_delete.side_effect = Exception('Delete failed')
        
        message = {
            'MessageId': 'msg-123',
            'Body': json.dumps({'test': 'data'}),
            'ReceiptHandle': 'receipt-123'
        }
        
        result = process_message(message)
        
        assert result is False


class TestS3KeyFormat:
    """Tests for S3 key format."""
    
    @patch('app.s3_client')
    def test_s3_key_has_correct_structure(self, mock_s3):
        """S3 key should follow messages/YYYY/MM/DD/HH/filename.json format."""
        message_body = json.dumps({'test': 'data'})
        
        s3_key = upload_to_s3(message_body, 'msg-123')
        
        parts = s3_key.split('/')
        assert parts[0] == 'messages'
        assert len(parts) == 6  # messages/YYYY/MM/DD/HH/filename
        assert parts[-1].endswith('.json')


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
