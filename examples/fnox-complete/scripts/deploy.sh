#!/bin/bash
set -e

# Example deployment script
# This demonstrates how to deploy with fnox-managed secrets

ENVIRONMENT=${1:-staging}

echo "=================================================="
echo "Deploying to: $ENVIRONMENT"
echo "=================================================="

# Verify environment is valid
case $ENVIRONMENT in
    staging|production)
        echo "✓ Valid environment: $ENVIRONMENT"
        ;;
    *)
        echo "Error: Invalid environment '$ENVIRONMENT'"
        echo "Usage: $0 {staging|production}"
        exit 1
        ;;
esac

# Verify required secrets are available
echo ""
echo "Verifying secrets..."
required_secrets=(
    "DATABASE_URL"
    "AWS_S3_BUCKET"
    "JWT_SECRET"
)

for secret in "${required_secrets[@]}"; do
    if [ -z "${!secret}" ]; then
        echo "Error: Required secret '$secret' not found"
        echo "Make sure you're running this via: fnox exec --profile $ENVIRONMENT -- $0"
        exit 1
    fi
    echo "  ✓ $secret is set"
done

echo "✓ All required secrets are available"

# Build application
echo ""
echo "Building application..."
npm run build || {
    echo "Error: Build failed"
    exit 1
}
echo "✓ Build complete"

# Run tests
echo ""
echo "Running tests..."
npm test || {
    echo "Error: Tests failed"
    exit 1
}
echo "✓ Tests passed"

# Deploy based on environment
echo ""
echo "Deploying to $ENVIRONMENT..."

if [ "$ENVIRONMENT" = "staging" ]; then
    # Example: Deploy to staging server
    echo "Deploying to staging server..."

    # Example deployment commands:
    # - rsync dist/ to server
    # - SSH and restart service
    # - Update load balancer

    # rsync -avz --delete dist/ user@staging.example.com:/var/www/app/
    # ssh user@staging.example.com "sudo systemctl restart myapp"

    echo "✓ Deployed to staging: https://staging.example.com"

elif [ "$ENVIRONMENT" = "production" ]; then
    # Production deployment with extra safety checks
    echo "⚠️  PRODUCTION DEPLOYMENT"

    # Require confirmation
    if [ -z "$CI" ]; then
        read -p "Are you sure you want to deploy to PRODUCTION? (type 'yes'): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Deployment cancelled"
            exit 1
        fi
    fi

    # Example deployment to production
    echo "Deploying to production..."

    # Example deployment commands:
    # - Blue-green deployment
    # - Canary release
    # - Rolling update

    # kubectl set image deployment/myapp myapp=myapp:$VERSION
    # kubectl rollout status deployment/myapp

    echo "✓ Deployed to production: https://example.com"
fi

# Post-deployment health check
echo ""
echo "Running health check..."
if [ "$ENVIRONMENT" = "staging" ]; then
    HEALTH_URL="https://staging.example.com/health"
elif [ "$ENVIRONMENT" = "production" ]; then
    HEALTH_URL="https://example.com/health"
fi

# Wait a bit for deployment to settle
sleep 5

# Check health endpoint
# if curl -f -s "$HEALTH_URL" | grep -q "ok"; then
#     echo "✓ Health check passed"
# else
#     echo "⚠️  Health check failed - please investigate"
#     exit 1
# fi

echo ""
echo "=================================================="
echo "Deployment to $ENVIRONMENT complete!"
echo "=================================================="
echo "URL: $HEALTH_URL"
echo "Timestamp: $(date)"
echo "Deployed by: ${USER:-CI}"
echo "=================================================="
