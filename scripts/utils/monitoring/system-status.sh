#!/bin/bash

echo "=== System Status Report ==="
date

echo -e "\n=== Docker Container Status ==="
docker-compose ps

echo -e "\n=== Resource Usage ==="
docker stats --no-stream $(docker-compose ps -q)

echo -e "\n=== Disk Usage ==="
df -h

echo -e "\n=== Memory Usage ==="
free -h

echo -e "\n=== SSL Certificates Status ==="
docker-compose exec nginx openssl x509 -in /etc/letsencrypt/live/*/cert.pem -noout -dates 2>/dev/null

echo -e "\n=== Recent Errors ==="
docker-compose logs --tail=50 | grep -i error
