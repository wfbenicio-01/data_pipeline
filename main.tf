terraform {
  required_version = ">= 1.2"
  required_providers {
    aws      = { source = "hashicorp/aws", version = "~> 4.0" }
    template = { source = "hashicorp/template", version = "~> 2.2" }
  }
}

provider "aws" {
  region = var.region
}

# S3 Buckets
resource "aws_s3_bucket" "bronze" {
  bucket = "${var.name_prefix}-bronze"
  acl    = "private"
}

resource "aws_s3_bucket" "gold" {
  bucket = "${var.name_prefix}-gold"
  acl    = "private"
}

# SQS for fallback processing
resource "aws_sqs_queue" "fallback_dlq" {
  name = "${var.name_prefix}-fallback-dlq"
}

resource "aws_sqs_queue" "fallback" {
  name            = "${var.name_prefix}-fallback-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.fallback_dlq.arn
    maxReceiveCount     = 5
  })
}

# IAM for Lambdas
resource "aws_iam_role" "lambda_exec" {
  name = "${var.name_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject","s3:PutObject"]
        Resource = ["${aws_s3_bucket.bronze.arn}/*","${aws_s3_bucket.gold.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.fallback.arn
      },
      {
        Effect = "Allow"
        Action = ["states:StartExecution"]
        Resource = "*"
      }
    ]
  })
}

# IAM for Step Functions
resource "aws_iam_role" "sfn_role" {
  name = "${var.name_prefix}-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "${var.name_prefix}-sfn-policy"
  role = aws_iam_role.sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = [
        aws_lambda_function.detect.arn,
        aws_lambda_function.text_processor.arn,
        aws_lambda_function.audio_processor.arn,
        aws_lambda_function.video_processor.arn
      ]
    }]
  })
}

# Archive Lambdas
data "archive_file" "detect_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/detect_file"
  output_path = "${path.module}/deploy/detect_file.zip"
}
data "archive_file" "text_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/text_processor"
  output_path = "${path.module}/deploy/text_processor.zip"
}
data "archive_file" "audio_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/audio_processor"
  output_path = "${path.module}/deploy/audio_processor.zip"
}
data "archive_file" "video_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/video_processor"
  output_path = "${path.module}/deploy/video_processor.zip"
}

# Lambdas
resource "aws_lambda_function" "detect" {
  filename      = data.archive_file.detect_zip.output_path
  function_name = "${var.name_prefix}-detect"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 512
  timeout       = 30
  environment {
    variables = {
      SIZE_THRESHOLD     = var.size_threshold
      FALLBACK_QUEUE_URL= aws_sqs_queue.fallback.id
      STATE_MACHINE_ARN = aws_sfn_state_machine.ingest.arn
    }
  }
}

resource "aws_lambda_function" "text_processor" {
  filename      = data.archive_file.text_zip.output_path
  function_name = "${var.name_prefix}-text-processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 1024
  timeout       = 300
  environment {
    variables = {
      GOLD_BUCKET         = aws_s3_bucket.gold.id
      OPENSEARCH_HOST     = var.opensearch_host
      OPENSEARCH_INDEX    = var.opensearch_index
      OPENSEARCH_USER     = var.opensearch_user
      OPENSEARCH_PASS     = var.opensearch_pass
    }
  }
}

resource "aws_lambda_function" "audio_processor" {
  filename      = data.archive_file.audio_zip.output_path
  function_name = "${var.name_prefix}-audio-processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 1024
  timeout       = 900
  environment {
    variables = {
      GOLD_BUCKET         = aws_s3_bucket.gold.id
      OPENSEARCH_HOST     = var.opensearch_host
      OPENSEARCH_INDEX    = var.opensearch_index
      OPENSEARCH_USER     = var.opensearch_user
      OPENSEARCH_PASS     = var.opensearch_pass
    }
  }
}

resource "aws_lambda_function" "video_processor" {
  filename      = data.archive_file.video_zip.output_path
  function_name = "${var.name_prefix}-video-processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 2048
  timeout       = 900
  environment {
    variables = {
      GOLD_BUCKET         = aws_s3_bucket.gold.id
      OPENSEARCH_HOST     = var.opensearch_host
      OPENSEARCH_INDEX    = var.opensearch_index
      OPENSEARCH_USER     = var.opensearch_user
      OPENSEARCH_PASS     = var.opensearch_pass
    }
  }
}

# S3 trigger
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.detect.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bronze.arn
}

resource "aws_s3_bucket_notification" "bronze_notify" {
  bucket = aws_s3_bucket.bronze.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.detect.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# State Machine
data "template_file" "state_machine" {
  template = file("${path.module}/state_machine.asl.json.tpl")
  vars = {
    text_arn  = aws_lambda_function.text_processor.arn
    audio_arn = aws_lambda_function.audio_processor.arn
    video_arn = aws_lambda_function.video_processor.arn
  }
}

resource "aws_sfn_state_machine" "ingest" {
  name       = "${var.name_prefix}-ingest-sm"
  role_arn   = aws_iam_role.sfn_role.arn
  definition = data.template_file.state_machine.rendered
}

# EC2 fallback
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.name_prefix}-ec2-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sqs:ReceiveMessage","sqs:DeleteMessage"], Resource = aws_sqs_queue.fallback.arn },
      { Effect = "Allow", Action = ["s3:GetObject","s3:PutObject"], Resource = ["${aws_s3_bucket.bronze.arn}/*","${aws_s3_bucket.gold.arn}/*"] },
      { Effect = "Allow", Action = ["es:ESHttpPost","es:ESHttpPut","es:ESHttpGet"], Resource = "*" }
    ]
  })
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
resource "aws_instance" "fallback_processor" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.large"
  subnet_id                   = var.fallback_subnet_id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install epel -y
    yum install python3 git -y
    pip3 install boto3 whisper sentence-transformers opensearch-py moviepy
    cat > /home/ec2-user/fallback_processor.py << 'EOPY'
    import os, time, json, boto3, whisper
    from sentence_transformers import SentenceTransformer
    from opensearchpy import OpenSearch, RequestsHttpConnection

    sqs = boto3.client('sqs')
    s3  = boto3.client('s3')
    model_whisper = whisper.load_model("base")
    model_embed   = SentenceTransformer('all-MiniLM-L6-v2')
    host = os.environ['OPENSEARCH_HOST']
    auth = (os.environ['OPENSEARCH_USER'], os.environ['OPENSEARCH_PASS'])
    client = OpenSearch(hosts=[{'host': host, 'port':443}], http_auth=auth,
                        use_ssl=True, verify_certs=True, connection_class=RequestsHttpConnection)

    queue_url = os.environ['FALLBACK_QUEUE_URL']
    gold = os.environ['GOLD_BUCKET']

    while True:
        res = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1, WaitTimeSeconds=20)
        msgs = res.get('Messages', [])
        if not msgs:
            time.sleep(5)
            continue
        for msg in msgs:
            body = json.loads(msg['Body'])
            bucket = body['bucket']; key = body['key']
            local = f"/tmp/{os.path.basename(key)}"
            s3.download_file(bucket, key, local)
            ext = key.rsplit('.',1)[-1].lower()
            text = ""
            if ext in ['txt']:
                text = open(local).read()
            elif ext in ['mp3','wav']:
                text = model_whisper.transcribe(local)['text']
            elif ext in ['mp4','mov']:
                from moviepy.editor import VideoFileClip
                clip=VideoFileClip(local); audio=local.rsplit('.',1)[0]+'.wav'; clip.audio.write_audiofile(audio,fps=16000)
                text = model_whisper.transcribe(audio)['text']
            emb = model_embed.encode([text])[0].tolist()
            # upload transcript
            tkey = key.replace('bronze/','gold/').rsplit('.',1)[0]+'.txt'
            s3.put_object(Bucket=gold, Key=tkey, Body=text)
            # index
            client.index(index=os.environ['OPENSEARCH_INDEX'], body={'key':tkey,'vector':emb})
            sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg['ReceiptHandle'])
    EOPY
    chmod +x /home/ec2-user/fallback_processor.py
    su ec2-user -c "nohup python3 /home/ec2-user/fallback_processor.py &"
  EOF
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
