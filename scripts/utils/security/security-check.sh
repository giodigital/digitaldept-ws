#!/bin/bash

echo "=== Security Audit ==="
date

echo -e "\n=== File Permissions ==="
find src/ -type f -not -path "*/\.*" -exec ls -l {} \;

echo -e "\n=== Open Ports ==="
netstat -tulpn | grep LISTEN

echo -e "\n=== Docker Security ==="
docker info --format '{{.SecurityOptions}}'

echo -e "\n=== SSL Configuration ==="
docker-compose exec nginx nginx -T | grep ssl

echo -e "\n=== Failed Login Attempts ==="
docker-compose logs nginx | grep "denied" | tail -n 10
