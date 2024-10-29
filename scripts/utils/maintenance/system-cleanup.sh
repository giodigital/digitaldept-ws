#!/bin/bash

echo "=== System Cleanup ==="
date

echo -e "\n=== Cleaning Docker System ==="
docker system prune -f

echo -e "\n=== Rotating Logs ==="
find docker/logs -name "*.log" -size +100M -exec rm {} \;

echo -e "\n=== Cleaning Old Backups ==="
find docker/mariadb/backup -name "*.sql.gz" -mtime +30 -delete

echo -e "\n=== Cleaning Temporary Files ==="
find /tmp -type f -atime +7 -delete

echo "Cleanup completed"
