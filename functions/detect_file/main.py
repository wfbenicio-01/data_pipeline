import os, json, boto3

sfn = boto3.client('stepfunctions')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']
    size = record['s3']['object']['size']
    threshold = int(os.environ.get('SIZE_THRESHOLD', '10485760'))
    if size > threshold:
        sqs.send_message(QueueUrl=os.environ['FALLBACK_QUEUE_URL'],
                         MessageBody=json.dumps({'bucket': bucket, 'key': key}))
    else:
        sfn.start_execution(stateMachineArn=os.environ['STATE_MACHINE_ARN'],
                            input=json.dumps({'bucket': bucket, 'key': key}))
    return {'status': 'accepted'}