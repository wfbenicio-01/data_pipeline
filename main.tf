
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "bucket_name" {
  default = "myproject-dev-lambda-artifacts"
}

resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = var.bucket_name
}

resource "aws_s3_object" "audio_zip" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "audio_processor.zip"
  source = "deploy/audio_processor.zip"
  etag   = filemd5("deploy/audio_processor.zip")
}

resource "aws_s3_object" "video_zip" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "video_processor.zip"
  source = "deploy/video_processor.zip"
  etag   = filemd5("deploy/video_processor.zip")
}

resource "aws_s3_object" "text_zip" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "text_processor.zip"
  source = "deploy/text_processor.zip"
  etag   = filemd5("deploy/text_processor.zip")
}

resource "aws_s3_object" "detect_zip" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "detect_file.zip"
  source = "deploy/detect_file.zip"
  etag   = filemd5("deploy/detect_file.zip")
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "audio_processor" {
  function_name = "audio_processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  s3_bucket     = aws_s3_bucket.lambda_artifacts.bucket
  s3_key        = aws_s3_object.audio_zip.key
  source_code_hash = filebase64sha256("deploy/audio_processor.zip")
}

resource "aws_lambda_function" "video_processor" {
  function_name = "video_processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  s3_bucket     = aws_s3_bucket.lambda_artifacts.bucket
  s3_key        = aws_s3_object.video_zip.key
  source_code_hash = filebase64sha256("deploy/video_processor.zip")
}

resource "aws_lambda_function" "text_processor" {
  function_name = "text_processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  s3_bucket     = aws_s3_bucket.lambda_artifacts.bucket
  s3_key        = aws_s3_object.text_zip.key
  source_code_hash = filebase64sha256("deploy/text_processor.zip")
}

resource "aws_lambda_function" "detect_file" {
  function_name = "detect_file"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  s3_bucket     = aws_s3_bucket.lambda_artifacts.bucket
  s3_key        = aws_s3_object.detect_zip.key
  source_code_hash = filebase64sha256("deploy/detect_file.zip")
}
