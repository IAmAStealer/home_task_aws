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
    logger.info("Received event: %s", json.dumps(event))
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
