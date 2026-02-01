# SQS Queue for message passing between microservices

resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-queue-${var.environment}"
  delay_seconds              = 0
  max_message_size           = 262144  # 256 KB
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = 10      # Long polling
  visibility_timeout_seconds = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-queue-${var.environment}"
    }
  )
}

# Dead letter queue for failed messages
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq-${var.environment}"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-dlq-${var.environment}"
    }
  )
}

# Redrive policy to send failed messages to DLQ
resource "aws_sqs_queue_redrive_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# Allow redrive from main queue to DLQ
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}
