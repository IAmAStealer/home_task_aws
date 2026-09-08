import json
import logging
import os
import uuid
import boto3

database = os.getenv('DATABASE', 'UNKNOWN')
logger = logging.getLogger()
logger.setLevel(level=os.getenv('APP_LOG_LEVEL', 'INFO').upper())
dynamodb = boto3.client('dynamodb')

def handler(event, context):
    # print("Lambda function ARN:", context.invoked_function_arn)
    # print("CloudWatch log stream name:", context.log_stream_name)
    # print("CloudWatch log group name:",  context.log_group_name)
    # print("Lambda Request ID:", context.aws_request_id)
    # print("Lambda function memory limits in MB:", context.memory_limit_in_mb)
    # # We have added a 1 second delay so you can see the time remaining in get_remaining_time_in_millis.
    # time.sleep(1)
    # print("Lambda time remaining in MS:", context.get_remaining_time_in_millis())




    if event["requestContext"]["http"]["method"] == "POST":
        if 'payload' not in json.loads(event["body"]):
            logger.warning("Received event: %s", json.dumps(event))
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "status": "Bad request",
                    "message": "Request logged."
                })
            }
    logger.info("Received event: %s", json.dumps(event)) #Log any event regarding security
    #Save in Database only correct event
    dynamodb.put_item(
        TableName=database,
        Item={
            'uuid': {'S': str(uuid.uuid4())},
            'request': {'S': json.dumps(event)}
        }
    )
    return {
        "statusCode": 200,
        "body": json.dumps({
            "status": "healthy",
            "message": "Request processed and saved."
        })
    }
