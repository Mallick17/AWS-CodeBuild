#!/bin/bash
echo "Running after_install.sh..."

# Change ownership (optional, if files are owned by root)
chown -R ubuntu:ubuntu /home/ec2-user/chat-app
