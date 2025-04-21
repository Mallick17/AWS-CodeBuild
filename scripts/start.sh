#!/bin/bash
echo "Running start.sh..."

cd /home/ubuntu/chat-app

# Pull the latest image from ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.ap-south-1.amazonaws.com
docker pull <your-aws-account-id>.dkr.ecr.ap-south-1.amazonaws.com/chat-app:latest

# Start the app with docker-compose
docker-compose up -d
