#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verifica parametri
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 domain.com [email]${NC}"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"webmaster@$DOMAIN"}

echo -e "${GREEN}DigitalDept WS - Installation${NC}"
echo "=============================="

# Verifica prerequisiti
command -v docker >/dev/null 2>&1 || { 
    echo -e "${YELLOW}Docker non trovato. Installazione...${NC}"
    curl -fsSL https://get.docker.com | sh
}
command -v docker-compose >/dev/null 2>&1 || {
    echo -e "${YELLOW}Docker Compose non trovato. Installazione...${NC}"
    apt install -y docker-compose
}

# Crea configurazione Nginx
envsubst '${DOMAIN}' < docker/nginx/templates/vhost.conf.template > docker/nginx/conf.d/${DOMAIN}.conf

# Inizializza directory
mkdir -p src
mkdir -p docker/nginx/ssl
mkdir -p docker/mariadb/backup
mkdir -p docker/logs/${DOMAIN}

# Crea file PHP di test
cat > src/index.php << 'EOL'
<?php
phpinfo();
EOL

# Imposta permessi
chmod -R 755 src
chown -R www-data:www-data src

echo -e "${GREEN}Avvio container...${NC}"
docker-compose up -d nginx

# Ottieni certificato SSL iniziale (staging)
echo -e "${YELLOW}Ottengo certificato SSL di test...${NC}"
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --staging \
    -d $DOMAIN -d www.$DOMAIN

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Test SSL riuscito. Ottengo certificato reale...${NC}"
    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d $DOMAIN -d www.$DOMAIN
        
    # Riavvia nginx per applicare il certificato
    docker-compose restart nginx
else
    echo -e "${RED}Errore durante il test SSL. Verifica DNS e riprova.${NC}"
    exit 1
fi

# Configura rinnovo automatico
(crontab -l 2>/dev/null; echo "0 0 * * * cd $(pwd) && docker-compose run --rm certbot renew --quiet && docker-compose kill -s SIGHUP nginx") | crontab -

echo -e "${GREEN}Installazione completata!${NC}"
echo -e "Verifica che il sito sia raggiungibile su: https://${DOMAIN}"
echo ""
echo "Comandi utili:"
echo "docker-compose ps    - Stato dei container"
echo "docker-compose logs  - Log dei servizi"
