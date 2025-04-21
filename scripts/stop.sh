#!/bin/bash
echo "Running stop.sh..."

cd /home/ubuntu/chat-app

# Stop and remove containers
docker-compose down || true
