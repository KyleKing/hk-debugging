"""
Complete example of using aioboto3 with AWS SSO credentials

This demonstrates:
1. Using AWS SSO credentials with aioboto3 (no code changes needed!)
2. Proper error handling for expired credentials
3. Multiple AWS service examples (S3, DynamoDB, SQS, SNS)
4. FastAPI integration
5. Health check endpoint showing current identity

Prerequisites:
- AWS SSO configured: aws configure sso --profile my-dev
- Logged in: aws sso login --profile my-dev
- aioboto3 installed: pip install aioboto3
"""

import aioboto3
import asyncio
from botocore.exceptions import ClientError, TokenRetrievalError
from typing import List, Dict, Optional
import os
import sys

# AWS SSO profile (from environment or default)
AWS_PROFILE = os.getenv("AWS_PROFILE", "my-dev")


# =============================================================================
# Error Handling Utilities
# =============================================================================

class AWSCredentialError(Exception):
    """Raised when AWS credentials are invalid or expired"""
    pass


async def handle_aws_errors(func):
    """Decorator to handle common AWS authentication errors"""
    async def wrapper(*args, **kwargs):
        try:
            return await func(*args, **kwargs)
        except TokenRetrievalError:
            error_msg = (
                "❌ AWS SSO session expired!\n"
                f"Please run: aws sso login --profile {AWS_PROFILE}"
            )
            print(error_msg, file=sys.stderr)
            raise AWSCredentialError(error_msg)
        except ClientError as e:
            if e.response['Error']['Code'] == 'ExpiredToken':
                error_msg = (
                    "❌ Temporary credentials expired!\n"
                    f"Please run: aws sso login --profile {AWS_PROFILE}"
                )
                print(error_msg, file=sys.stderr)
                raise AWSCredentialError(error_msg)
            else:
                # Re-raise other client errors
                raise
    return wrapper


# =============================================================================
# AWS Identity Information
# =============================================================================

@handle_aws_errors
async def get_caller_identity() -> Dict:
    """
    Get current AWS identity (account, user, role)
    Useful for debugging and health checks
    """
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('sts') as sts:
        identity = await sts.get_caller_identity()
        return {
            "account_id": identity['Account'],
            "user_arn": identity['Arn'],
            "user_id": identity['UserId'],
            "profile": AWS_PROFILE
        }


# =============================================================================
# S3 Operations
# =============================================================================

@handle_aws_errors
async def list_s3_buckets() -> List[str]:
    """List all S3 buckets accessible with current credentials"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('s3') as s3:
        response = await s3.list_buckets()
        return [bucket['Name'] for bucket in response['Buckets']]


@handle_aws_errors
async def list_s3_objects(bucket_name: str, prefix: str = "", max_keys: int = 100) -> List[Dict]:
    """List objects in an S3 bucket"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('s3') as s3:
        response = await s3.list_objects_v2(
            Bucket=bucket_name,
            Prefix=prefix,
            MaxKeys=max_keys
        )

        return [
            {
                "key": obj['Key'],
                "size": obj['Size'],
                "last_modified": obj['LastModified'].isoformat(),
                "storage_class": obj.get('StorageClass', 'STANDARD')
            }
            for obj in response.get('Contents', [])
        ]


@handle_aws_errors
async def upload_to_s3(bucket_name: str, key: str, content: bytes, content_type: str = "application/octet-stream") -> Dict:
    """Upload content to S3"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('s3') as s3:
        await s3.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=content,
            ContentType=content_type
        )

        return {
            "bucket": bucket_name,
            "key": key,
            "size": len(content),
            "content_type": content_type
        }


@handle_aws_errors
async def download_from_s3(bucket_name: str, key: str) -> bytes:
    """Download content from S3"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('s3') as s3:
        response = await s3.get_object(Bucket=bucket_name, Key=key)
        async with response['Body'] as stream:
            content = await stream.read()
            return content


# =============================================================================
# DynamoDB Operations
# =============================================================================

@handle_aws_errors
async def list_dynamodb_tables() -> List[str]:
    """List all DynamoDB tables"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('dynamodb') as dynamodb:
        response = await dynamodb.list_tables()
        return response.get('TableNames', [])


@handle_aws_errors
async def put_dynamodb_item(table_name: str, item: Dict) -> None:
    """Put an item into DynamoDB table"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.resource('dynamodb') as dynamodb:
        table = await dynamodb.Table(table_name)
        await table.put_item(Item=item)


@handle_aws_errors
async def get_dynamodb_item(table_name: str, key: Dict) -> Optional[Dict]:
    """Get an item from DynamoDB table"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.resource('dynamodb') as dynamodb:
        table = await dynamodb.Table(table_name)
        response = await table.get_item(Key=key)
        return response.get('Item')


@handle_aws_errors
async def query_dynamodb(table_name: str, key_condition: str, expression_values: Dict) -> List[Dict]:
    """Query DynamoDB table"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.resource('dynamodb') as dynamodb:
        table = await dynamodb.Table(table_name)
        response = await table.query(
            KeyConditionExpression=key_condition,
            ExpressionAttributeValues=expression_values
        )
        return response.get('Items', [])


# =============================================================================
# SQS Operations
# =============================================================================

@handle_aws_errors
async def send_sqs_message(queue_url: str, message_body: str, message_attributes: Optional[Dict] = None) -> str:
    """Send a message to SQS queue"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('sqs') as sqs:
        params = {
            'QueueUrl': queue_url,
            'MessageBody': message_body
        }
        if message_attributes:
            params['MessageAttributes'] = message_attributes

        response = await sqs.send_message(**params)
        return response['MessageId']


@handle_aws_errors
async def receive_sqs_messages(queue_url: str, max_messages: int = 10, wait_time: int = 20) -> List[Dict]:
    """Receive messages from SQS queue (long polling)"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('sqs') as sqs:
        response = await sqs.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=max_messages,
            WaitTimeSeconds=wait_time,
            MessageAttributeNames=['All']
        )
        return response.get('Messages', [])


@handle_aws_errors
async def delete_sqs_message(queue_url: str, receipt_handle: str) -> None:
    """Delete a message from SQS queue"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('sqs') as sqs:
        await sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle
        )


# =============================================================================
# SNS Operations
# =============================================================================

@handle_aws_errors
async def publish_to_sns(topic_arn: str, message: str, subject: Optional[str] = None) -> str:
    """Publish a message to SNS topic"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('sns') as sns:
        params = {
            'TopicArn': topic_arn,
            'Message': message
        }
        if subject:
            params['Subject'] = subject

        response = await sns.publish(**params)
        return response['MessageId']


# =============================================================================
# CloudWatch Logs Operations
# =============================================================================

@handle_aws_errors
async def put_cloudwatch_log_event(log_group: str, log_stream: str, message: str) -> None:
    """Put a log event to CloudWatch Logs"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)

    async with session.client('logs') as logs:
        # Ensure log group exists
        try:
            await logs.create_log_group(logGroupName=log_group)
        except ClientError as e:
            if e.response['Error']['Code'] != 'ResourceAlreadyExistsException':
                raise

        # Ensure log stream exists
        try:
            await logs.create_log_stream(
                logGroupName=log_group,
                logStreamName=log_stream
            )
        except ClientError as e:
            if e.response['Error']['Code'] != 'ResourceAlreadyExistsException':
                raise

        # Put log event
        import time
        timestamp = int(time.time() * 1000)

        await logs.put_log_events(
            logGroupName=log_group,
            logStreamName=log_stream,
            logEvents=[
                {
                    'timestamp': timestamp,
                    'message': message
                }
            ]
        )


# =============================================================================
# Example Usage and Tests
# =============================================================================

async def main():
    """Example usage of all functions"""
    print("=" * 80)
    print("AWS SSO + aioboto3 Example")
    print("=" * 80)

    # Get current identity
    print("\n1. Checking AWS identity...")
    try:
        identity = await get_caller_identity()
        print(f"   ✅ Logged in as: {identity['user_arn']}")
        print(f"   Account ID: {identity['account_id']}")
        print(f"   Profile: {identity['profile']}")
    except AWSCredentialError as e:
        print(f"   ❌ Authentication failed: {e}")
        return

    # List S3 buckets
    print("\n2. Listing S3 buckets...")
    try:
        buckets = await list_s3_buckets()
        print(f"   ✅ Found {len(buckets)} buckets:")
        for bucket in buckets[:5]:  # Show first 5
            print(f"      • {bucket}")
        if len(buckets) > 5:
            print(f"      ... and {len(buckets) - 5} more")
    except Exception as e:
        print(f"   ❌ Error: {e}")

    # List DynamoDB tables
    print("\n3. Listing DynamoDB tables...")
    try:
        tables = await list_dynamodb_tables()
        print(f"   ✅ Found {len(tables)} tables:")
        for table in tables[:5]:
            print(f"      • {table}")
        if len(tables) > 5:
            print(f"      ... and {len(tables) - 5} more")
    except Exception as e:
        print(f"   ❌ Error: {e}")

    # Example: Upload to S3 (if you have a test bucket)
    # bucket_name = "my-test-bucket"
    # print(f"\n4. Uploading test file to S3 bucket: {bucket_name}...")
    # try:
    #     result = await upload_to_s3(
    #         bucket_name=bucket_name,
    #         key="test/example.txt",
    #         content=b"Hello from aioboto3 with AWS SSO!",
    #         content_type="text/plain"
    #     )
    #     print(f"   ✅ Uploaded: {result['key']} ({result['size']} bytes)")
    # except Exception as e:
    #     print(f"   ❌ Error: {e}")

    print("\n" + "=" * 80)
    print("✅ All tests completed!")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(main())


# =============================================================================
# FastAPI Integration Example
# =============================================================================

"""
Example FastAPI integration:

from fastapi import FastAPI, HTTPException
from typing import List
import os

app = FastAPI(title="AWS SSO Example API")

# Use environment variable or default
AWS_PROFILE = os.getenv("AWS_PROFILE", "my-dev")


@app.get("/health")
async def health_check():
    try:
        identity = await get_caller_identity()
        return {
            "status": "healthy",
            "aws_account": identity['account_id'],
            "user": identity['user_arn']
        }
    except AWSCredentialError as e:
        raise HTTPException(status_code=503, detail=str(e))


@app.get("/buckets", response_model=List[str])
async def get_buckets():
    try:
        return await list_s3_buckets()
    except AWSCredentialError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/buckets/{bucket_name}/objects")
async def get_bucket_objects(bucket_name: str, prefix: str = ""):
    try:
        objects = await list_s3_objects(bucket_name, prefix)
        return {"bucket": bucket_name, "objects": objects}
    except AWSCredentialError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/tables", response_model=List[str])
async def get_tables():
    try:
        return await list_dynamodb_tables()
    except AWSCredentialError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Run with:
# aws sso login --profile my-dev
# export AWS_PROFILE=my-dev
# uvicorn aws_sso_example:app --reload
"""
