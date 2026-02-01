"""
Microservice 1 - REST API
- Receives requests from ALB
- Validates token against SSM Parameter Store
- Validates payload has required fields
- Sends valid messages to SQS
"""

import os
import json
import logging
import boto3
from flask import Flask, request, jsonify
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
SSM_PARAMETER_NAME = os.environ.get('SSM_PARAMETER_NAME')

# Required fields in the payload
REQUIRED_FIELDS = ['email_subject', 'email_sender', 'email_timestream', 'email_content']

# AWS clients
ssm_client = boto3.client('ssm', region_name=AWS_REGION)
sqs_client = boto3.client('sqs', region_name=AWS_REGION)

# Cache for token (refreshed periodically)
_cached_token = None


def get_token_from_ssm():
    """Retrieve the API token from SSM Parameter Store."""
    global _cached_token
    
    if _cached_token:
        return _cached_token
    
    try:
        response = ssm_client.get_parameter(
            Name=SSM_PARAMETER_NAME,
            WithDecryption=True
        )
        _cached_token = response['Parameter']['Value']
        logger.info(f"Successfully retrieved token from SSM: {SSM_PARAMETER_NAME}")
        return _cached_token
    except ClientError as e:
        logger.error(f"Failed to get token from SSM: {e}")
        raise


def validate_token(provided_token):
    """Validate the provided token against the stored token."""
    stored_token = get_token_from_ssm()
    return provided_token == stored_token


def validate_payload(data):
    """Validate that the payload contains all required fields."""
    if not data:
        return False, "Missing 'data' field in payload"
    
    missing_fields = [field for field in REQUIRED_FIELDS if field not in data]
    
    if missing_fields:
        return False, f"Missing required fields: {', '.join(missing_fields)}"
    
    # Check that all fields are non-empty strings
    for field in REQUIRED_FIELDS:
        if not isinstance(data[field], str) or not data[field].strip():
            return False, f"Field '{field}' must be a non-empty string"
    
    return True, None


def send_to_sqs(data):
    """Send the validated data to SQS."""
    try:
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(data),
            MessageAttributes={
                'Source': {
                    'StringValue': 'microservice1',
                    'DataType': 'String'
                }
            }
        )
        logger.info(f"Message sent to SQS. MessageId: {response['MessageId']}")
        return response['MessageId']
    except ClientError as e:
        logger.error(f"Failed to send message to SQS: {e}")
        raise


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for ALB."""
    return jsonify({'status': 'healthy'}), 200


@app.route('/api/message', methods=['POST'])
def process_message():
    """
    Process incoming message.
    
    Expected payload:
    {
        "data": {
            "email_subject": "...",
            "email_sender": "...",
            "email_timestream": "...",
            "email_content": "..."
        },
        "token": "..."
    }
    """
    try:
        # Parse JSON payload
        payload = request.get_json()
        
        if not payload:
            return jsonify({
                'error': 'Invalid JSON payload'
            }), 400
        
        # Extract token and data
        token = payload.get('token')
        data = payload.get('data')
        
        # Validate token is provided
        if not token:
            return jsonify({
                'error': 'Missing token in payload'
            }), 401
        
        # Validate token against SSM
        if not validate_token(token):
            logger.warning("Invalid token provided")
            return jsonify({
                'error': 'Invalid token'
            }), 401
        
        # Validate payload structure
        is_valid, error_message = validate_payload(data)
        if not is_valid:
            return jsonify({
                'error': error_message
            }), 400
        
        # Send to SQS
        message_id = send_to_sqs(data)
        
        return jsonify({
            'status': 'success',
            'message': 'Message sent to queue',
            'message_id': message_id
        }), 200
        
    except ClientError as e:
        logger.error(f"AWS error: {e}")
        return jsonify({
            'error': 'Internal server error'
        }), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({
            'error': 'Internal server error'
        }), 500


@app.route('/', methods=['GET'])
def root():
    """Root endpoint."""
    return jsonify({
        'service': 'Microservice 1 - REST API',
        'endpoints': {
            '/health': 'Health check',
            '/api/message': 'POST - Send message to queue'
        }
    }), 200


if __name__ == '__main__':
    # Validate required environment variables
    if not SQS_QUEUE_URL:
        raise ValueError("SQS_QUEUE_URL environment variable is required")
    if not SSM_PARAMETER_NAME:
        raise ValueError("SSM_PARAMETER_NAME environment variable is required")
    
    logger.info(f"Starting Microservice 1")
    logger.info(f"SQS Queue: {SQS_QUEUE_URL}")
    logger.info(f"SSM Parameter: {SSM_PARAMETER_NAME}")
    
    app.run(host='0.0.0.0', port=8080)
