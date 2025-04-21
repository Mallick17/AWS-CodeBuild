#!/bin/bash
echo "Running before_install.sh..."

# Stop old containers
docker-compose -f /home/ec2-user/chat-app/docker-compose.yml down || true

# Remove old images (optional cleanup)
docker system prune -af || true
