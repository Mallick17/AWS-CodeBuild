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

# Start containers in detached mode
$DOCKER_COMPOSE -f /home/ubuntu/chat-app/scripts/docker-compose.yml up -d

