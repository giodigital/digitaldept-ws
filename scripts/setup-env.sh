#!/bin/bash

# Funzione per generare password sicure
generate_password() {
    openssl rand -base64 32 | tr -d '/+=' | cut -c1-24
}

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}DigitalDept WS - Setup Environment${NC}"
echo "==============================="

# Genera password
DB_ROOT_PASSWORD=$(generate_password)
DB_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)

# Crea .env
cat > .env << EOL
# Environment
COMPOSE_PROJECT_NAME=digitaldept
APP_ENV=production

# Database
MYSQL_DATABASE=digitaldept
DB_USER=digitaldeptuser
DB_PASSWORD=$DB_PASSWORD
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD

# Redis
REDIS_PASSWORD=$REDIS_PASSWORD

# Backup
BACKUP_RETENTION_DAYS=7

# PHP
PHP_MEMORY_LIMIT=256M
PHP_MAX_EXECUTION_TIME=60
PHP_UPLOAD_MAX_FILESIZE=50M
PHP_POST_MAX_SIZE=50M
EOL

# Salva credenziali in modo sicuro
mkdir -p ~/.digitaldept-ws
cat > ~/.digitaldept-ws/credentials.txt << EOL
DigitalDept WS Credentials
================================
Generated on: $(date)

Database Root Password: $DB_ROOT_PASSWORD
Database User: digitaldeptuser
Database Password: $DB_PASSWORD
Redis Password: $REDIS_PASSWORD
EOL

chmod 600 ~/.digitaldept-ws/credentials.txt
chmod 600 .env

echo -e "${GREEN}Setup completato!${NC}"
echo "Credenziali salvate in ~/.digitaldept-ws/credentials.txt"
echo "File .env creato con successo"
