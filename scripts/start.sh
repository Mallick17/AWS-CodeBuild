#!/bin/bash
set -euo pipefail

echo "🚀 Running start.sh..."

APP_DIR="/home/ubuntu/chat-app"
COMPOSE_FILE="$APP_DIR/scripts/docker-compose.yml"
ECR_IMAGE="339713104321.dkr.ecr.ap-south-1.amazonaws.com/chat-app:latest"
SECRET_ARN="arn:aws:secretsmanager:ap-south-1:339713104321:secret:chat-app-secrets-rXZYzv"
REGION="ap-south-1"

# Binary paths
AWS_CLI="/usr/bin/aws"
DOCKER="/usr/bin/docker"
DOCKER_COMPOSE="/usr/local/bin/docker-compose"

# Ensure required tools exist
for cmd in $AWS_CLI $DOCKER $DOCKER_COMPOSE jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' not found. Exiting."
    exit 1
  fi
done

# Navigate to app directory
cd "$APP_DIR" || { echo "❌ Directory $APP_DIR not found"; exit 1; }

# Authenticate Docker to ECR
echo "🔐 Logging in to Amazon ECR..."
$AWS_CLI ecr get-login-password --region "$REGION" | $DOCKER login --username AWS --password-stdin "$ECR_IMAGE" || {
  echo "❌ ECR login failed"; exit 1;
}

# Pull the latest image
echo "📦 Pulling latest image from ECR..."
$DOCKER pull "$ECR_IMAGE"

# Shut down existing containers (non-fatal)
echo "🛑 Stopping existing containers (if any)..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" down || true

# Fetch secrets from Secrets Manager
echo "🔐 Fetching secrets from AWS Secrets Manager..."
SECRET_JSON=$($AWS_CLI secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$REGION" \
  --query SecretString \
  --output text)

# Export environment variables
export DB_USER=$(echo "$SECRET_JSON" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.DB_PASSWORD')
export DB_HOST=$(echo "$SECRET_JSON" | jq -r '.DB_HOST')
export DB_PORT=$(echo "$SECRET_JSON" | jq -r '.DB_PORT')
export DB_NAME=$(echo "$SECRET_JSON" | jq -r '.DB_NAME')

echo "✅ Secrets loaded."

# Start containers
echo "🚀 Starting containers using Docker Compose..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d || {
  echo "❌ Failed to start containers"; exit 1;
}

echo "✅ Deployment completed successfully."
