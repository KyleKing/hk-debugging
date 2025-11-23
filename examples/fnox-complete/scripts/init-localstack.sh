#!/bin/bash
set -e

echo "=================================================="
echo "Initializing LocalStack with secrets and services"
echo "=================================================="

# LocalStack endpoint
ENDPOINT="http://localhost:4566"
REGION="us-east-1"

# Wait for LocalStack to be fully ready
echo "Waiting for LocalStack to be ready..."
until curl -s "$ENDPOINT/_localstack/health" | grep -q '"secretsmanager": "available"'; do
    echo "  Waiting for Secrets Manager..."
    sleep 2
done
echo "✓ LocalStack is ready!"

# Configure AWS CLI for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# =============================================================================
# Create Secrets in Secrets Manager
# =============================================================================

echo ""
echo "Creating secrets in AWS Secrets Manager..."

# Application secrets
aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/database-url \
    --description "Local PostgreSQL connection string" \
    --secret-string "postgresql://postgres:postgres@postgres:5432/dev" \
    2>/dev/null || echo "  Secret myapp/local/database-url already exists"

aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/jwt-secret \
    --description "JWT signing secret for local development" \
    --secret-string "local-jwt-secret-$(openssl rand -hex 16)" \
    2>/dev/null || echo "  Secret myapp/local/jwt-secret already exists"

aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/session-secret \
    --description "Session signing secret for local development" \
    --secret-string "local-session-secret-$(openssl rand -hex 16)" \
    2>/dev/null || echo "  Secret myapp/local/session-secret already exists"

# AWS service configurations
aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/s3-bucket-name \
    --description "Local S3 bucket name" \
    --secret-string "local-dev-bucket" \
    2>/dev/null || echo "  Secret myapp/local/s3-bucket-name already exists"

# External API keys (test/development keys)
aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/stripe-key \
    --description "Stripe test secret key" \
    --secret-string "sk_test_local_$(openssl rand -hex 12)" \
    2>/dev/null || echo "  Secret myapp/local/stripe-key already exists"

aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/sendgrid-key \
    --description "SendGrid test API key (use MailHog instead)" \
    --secret-string "SG.local_test_key" \
    2>/dev/null || echo "  Secret myapp/local/sendgrid-key already exists"

echo "✓ Secrets created successfully!"

# =============================================================================
# Create S3 Buckets
# =============================================================================

echo ""
echo "Creating S3 buckets..."

aws --endpoint-url=$ENDPOINT s3 mb s3://local-dev-bucket 2>/dev/null || echo "  Bucket local-dev-bucket already exists"
aws --endpoint-url=$ENDPOINT s3 mb s3://local-uploads 2>/dev/null || echo "  Bucket local-uploads already exists"
aws --endpoint-url=$ENDPOINT s3 mb s3://local-static-assets 2>/dev/null || echo "  Bucket local-static-assets already exists"

# Configure CORS for S3 buckets
cat > /tmp/cors-config.json <<EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws --endpoint-url=$ENDPOINT s3api put-bucket-cors \
    --bucket local-dev-bucket \
    --cors-configuration file:///tmp/cors-config.json 2>/dev/null || true

echo "✓ S3 buckets created and configured!"

# =============================================================================
# Create KMS Keys
# =============================================================================

echo ""
echo "Creating KMS keys..."

KMS_KEY_ID=$(aws --endpoint-url=$ENDPOINT kms create-key \
    --description "LocalStack development encryption key" \
    --query 'KeyMetadata.KeyId' \
    --output text 2>/dev/null || echo "")

if [ -n "$KMS_KEY_ID" ]; then
    aws --endpoint-url=$ENDPOINT kms create-alias \
        --alias-name alias/local-dev-key \
        --target-key-id "$KMS_KEY_ID" 2>/dev/null || true
    echo "✓ KMS key created: $KMS_KEY_ID"
else
    echo "  KMS key already exists or creation skipped"
fi

# =============================================================================
# Create DynamoDB Tables (optional)
# =============================================================================

echo ""
echo "Creating DynamoDB tables..."

aws --endpoint-url=$ENDPOINT dynamodb create-table \
    --table-name local-sessions \
    --attribute-definitions \
        AttributeName=sessionId,AttributeType=S \
    --key-schema \
        AttributeName=sessionId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "  Table local-sessions already exists"

aws --endpoint-url=$ENDPOINT dynamodb create-table \
    --table-name local-users \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=email,AttributeType=S \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
    --global-secondary-indexes \
        "IndexName=EmailIndex,KeySchema=[{AttributeName=email,KeyType=HASH}],Projection={ProjectionType=ALL},ProvisionedThroughput={ReadCapacityUnits=5,WriteCapacityUnits=5}" \
    --billing-mode PAY_PER_REQUEST \
    2>/dev/null || echo "  Table local-users already exists"

echo "✓ DynamoDB tables created!"

# =============================================================================
# Create SQS Queues (optional)
# =============================================================================

echo ""
echo "Creating SQS queues..."

aws --endpoint-url=$ENDPOINT sqs create-queue \
    --queue-name local-email-queue \
    2>/dev/null || echo "  Queue local-email-queue already exists"

aws --endpoint-url=$ENDPOINT sqs create-queue \
    --queue-name local-job-queue \
    2>/dev/null || echo "  Queue local-job-queue already exists"

echo "✓ SQS queues created!"

# =============================================================================
# Create SNS Topics (optional)
# =============================================================================

echo ""
echo "Creating SNS topics..."

aws --endpoint-url=$ENDPOINT sns create-topic \
    --name local-notifications \
    2>/dev/null || echo "  Topic local-notifications already exists"

echo "✓ SNS topics created!"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=================================================="
echo "LocalStack initialization complete!"
echo "=================================================="
echo ""
echo "Available services:"
echo "  • Secrets Manager: http://localhost:4566"
echo "  • S3: http://localhost:4566"
echo "  • KMS: http://localhost:4566"
echo "  • DynamoDB: http://localhost:4566"
echo "  • SQS: http://localhost:4566"
echo "  • SNS: http://localhost:4566"
echo ""
echo "View LocalStack dashboard: https://app.localstack.cloud"
echo ""
echo "Verify secrets with:"
echo "  aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets"
echo ""
echo "Verify S3 buckets with:"
echo "  aws --endpoint-url=http://localhost:4566 s3 ls"
echo ""
