import os
import json
import time
import logging
import uuid
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '10'))

sqs_client = boto3.client('sqs', region_name=AWS_REGION)
s3_client = boto3.client('s3', region_name=AWS_REGION)


def poll_sqs():
    try:
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20,
            MessageAttributeNames=['All']
        )
        
        messages = response.get('Messages', [])
        logger.info(f"Received {len(messages)} messages from SQS")
        return messages
        
    except ClientError as e:
        logger.error(f"Failed to poll SQS: {e}")
        return []


def upload_to_s3(message_body, message_id):
    try:
        data = json.loads(message_body)
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H')
        file_name = f"{message_id}_{uuid.uuid4().hex[:8]}.json"
        s3_key = f"messages/{timestamp}/{file_name}"
        content = {
            'data': data,
            'metadata': {
                'message_id': message_id,
                'processed_at': datetime.utcnow().isoformat(),
                'source': 'microservice2'
            }
        }
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=json.dumps(content, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Uploaded message to S3: s3://{S3_BUCKET_NAME}/{s3_key}")
        return s3_key
        
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse message body as JSON: {e}")
        raise
    except ClientError as e:
        logger.error(f"Failed to upload to S3: {e}")
        raise


def delete_message(receipt_handle):
    try:
        sqs_client.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=receipt_handle
        )
        logger.info("Message deleted from SQS")
    except ClientError as e:
        logger.error(f"Failed to delete message from SQS: {e}")
        raise


def process_message(message):
    message_id = message['MessageId']
    receipt_handle = message['ReceiptHandle']
    body = message['Body']
    
    logger.info(f"Processing message: {message_id}")
    
    try:
        # Upload to S3
        s3_key = upload_to_s3(body, message_id)
        
        # Delete from SQS
        delete_message(receipt_handle)
        
        logger.info(f"Successfully processed message {message_id}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to process message {message_id}: {e}")
        return False


def run_worker():
    logger.info("Starting SQS Worker")
    logger.info(f"SQS Queue: {SQS_QUEUE_URL}")
    logger.info(f"S3 Bucket: {S3_BUCKET_NAME}")
    logger.info(f"Poll Interval: {POLL_INTERVAL}s")
    
    processed_count = 0
    error_count = 0
    
    while True:
        try:
            messages = poll_sqs()
            for message in messages:
                if process_message(message):
                    processed_count += 1
                else:
                    error_count += 1
            
            if processed_count > 0 or error_count > 0:
                logger.info(f"Stats - Processed: {processed_count}, Errors: {error_count}")
            
            if not messages:
                time.sleep(POLL_INTERVAL)
                
        except KeyboardInterrupt:
            logger.info("Shutting down worker...")
            break
        except Exception as e:
            logger.error(f"Unexpected error in worker loop: {e}")
            time.sleep(POLL_INTERVAL)


if __name__ == '__main__':
    if not SQS_QUEUE_URL:
        raise ValueError("SQS_QUEUE_URL environment variable is required")
    if not S3_BUCKET_NAME:
        raise ValueError("S3_BUCKET_NAME environment variable is required")
    
    run_worker()
