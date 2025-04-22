#!/bin/bash
set -e

echo "Running start.sh..."

# Move to app directory
cd /home/ubuntu/chat-app

# Authenticate with ECR (non-interactive)
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 339713104321.dkr.ecr.ap-south-1.amazonaws.com

# Pull the latest image
docker pull 339713104321.dkr.ecr.ap-south-1.amazonaws.com/chat-app:latest

# Shut down any running containers
docker-compose down || true

# Start containers in detached mode
docker-compose up -d
