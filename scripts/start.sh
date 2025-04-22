#!/bin/bash
set -e

echo "Running start.sh..."

# Move to app directory
cd /home/ubuntu/chat-app || exit 1

# Full paths to binaries
AWS_CLI="/usr/bin/aws"
DOCKER="/usr/bin/docker"
DOCKER_COMPOSE="/usr/local/bin/docker-compose"

# Authenticate with ECR (non-interactive)
$AWS_CLI ecr get-login-password --region ap-south-1 | $DOCKER login --username AWS --password-stdin 339713104321.dkr.ecr.ap-south-1.amazonaws.com

# Pull the latest image
$DOCKER pull 339713104321.dkr.ecr.ap-south-1.amazonaws.com/chat-app:latest

# Shut down existing containers (if any)
$DOCKER_COMPOSE down || true

echo "Fetching secrets from AWS Secrets Manager..."

# Replace with your actual secret name
SECRET_NAME="chat-app-secrets/env"
REGION="ap-south-1"

# Fetch secrets from Secrets Manager
SECRET_JSON=$($AWS_CLI secretsmanager get-secret-value --secret-id $SECRET_NAME --region $REGION --query SecretString --output text)

# Parse and export each variable (requires jq)
export DB_USER=$(echo $SECRET_JSON | jq -r '.DB_USER')
export DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.DB_PASSWORD')
export DB_HOST=$(echo $SECRET_JSON | jq -r '.DB_HOST')
export DB_PORT=$(echo $SECRET_JSON | jq -r '.DB_PORT')
export DB_NAME=$(echo $SECRET_JSON | jq -r '.DB_NAME')

echo "Secrets loaded and exported."

# Run docker-compose
$DOCKER_COMPOSE -f /home/ubuntu/chat-app/scripts/docker-compose.yml up -d


