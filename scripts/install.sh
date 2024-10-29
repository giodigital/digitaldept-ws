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

# Crea la configurazione nginx da template
cat > docker/nginx/templates/site.conf.template << 'TEMPLATE'
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Root directory and index files
    root /var/www/html;
    index index.php index.html;

    # phpMyAdmin configuration
    location /phpmyadmin/ {
        proxy_pass http://phpmyadmin:80/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_redirect off;
        proxy_buffering off;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Proxy settings for Apache
    location / {
        proxy_pass http://apache:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
TEMPLATE

# Elabora il template con le variabili
envsubst '$DOMAIN' < docker/nginx/templates/site.conf.template > docker/nginx/conf.d/${DOMAIN}.conf

# Inizializza directory
mkdir -p src
mkdir -p docker/nginx/ssl
mkdir -p docker/mariadb/backup
mkdir -p docker/logs/${DOMAIN}

# Crea file PHP di test
echo "<?php phpinfo(); ?>" > src/index.php

# Imposta permessi
chmod -R 755 src
chown -R www-data:www-data src

echo -e "${GREEN}Avvio container...${NC}"

# Ferma eventuali container in esecuzione
docker-compose down

# Aggiorna il file .env con il dominio corrente
sed -i "s/DOMAIN=.*/DOMAIN=${DOMAIN}/" .env 2>/dev/null || echo "DOMAIN=${DOMAIN}" >> .env

# Avvia i container
docker-compose up -d

# Attendi che i servizi siano pronti
echo -e "${YELLOW}Attendo l'inizializzazione dei servizi...${NC}"
sleep 10

# Verifica che il servizio HTTP sia raggiungibile
if curl -s -o /dev/null -w "%{http_code}" http://${DOMAIN} > /dev/null; then
    echo -e "${GREEN}Servizio HTTP verificato, procedo con SSL${NC}"
    
    # Ottieni certificato SSL
    echo -e "${YELLOW}Ottengo certificato SSL...${NC}"
    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d ${DOMAIN}

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Certificato SSL ottenuto con successo${NC}"
        
        # Riavvia nginx per applicare la configurazione SSL
        docker-compose restart nginx
        
        # Configura il rinnovo automatico
        (crontab -l 2>/dev/null; echo "0 0 * * * cd $(pwd) && docker-compose run --rm certbot renew --quiet && docker-compose kill -s SIGHUP nginx") | crontab -
        
        echo -e "${GREEN}Installazione completata con successo!${NC}"
        echo -e "Sito disponibile su:"
        echo -e "- https://${DOMAIN}"
        echo -e "- https://${DOMAIN}/phpmyadmin/"
    else
        echo -e "${RED}Errore durante l'ottenimento del certificato SSL${NC}"
        exit 1
    fi
else
    echo -e "${RED}Errore: impossibile raggiungere il dominio via HTTP${NC}"
    echo "Verifica:"
    echo "1. La configurazione DNS"
    echo "2. Le regole del firewall (porte 80 e 443)"
    echo "3. La raggiungibilità del server"
    exit 1
fi

# Verifica finale
echo -e "\n${GREEN}Verifica dello stato dei servizi:${NC}"
docker-compose ps

echo -e "\n${GREEN}Installazione completata!${NC}"
echo "Credenziali phpMyAdmin:"
echo "URL: https://${DOMAIN}/phpmyadmin/"
echo "User: root"
echo "Password: vedi file .env (DB_ROOT_PASSWORD)"
