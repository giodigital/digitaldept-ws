#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="docker/mariadb/backup"

# Backup Database
echo "Backup database..."
docker-compose exec -T mariadb mysqldump -u root -p"${DB_ROOT_PASSWORD}" --all-databases > "${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql"
gzip "${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql"

# Backup Certificati SSL
echo "Backup certificati SSL..."
tar -czf "${BACKUP_DIR}/ssl_backup_${TIMESTAMP}.tar.gz" docker/nginx/ssl/

# Cleanup vecchi backup
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${BACKUP_RETENTION_DAYS:-7} -delete
find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS:-7} -delete

echo "Backup completato"
