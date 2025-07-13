output "bronze_bucket" {
  value = aws_s3_bucket.bronze.bucket
}

output "gold_bucket" {
  value = aws_s3_bucket.gold.bucket
}

output "fallback_queue_url" {
  value = aws_sqs_queue.fallback.id
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.ingest.arn
}
