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

# Aggiorna .env con il dominio
sed -i "s/DOMAIN=.*/DOMAIN=$DOMAIN/" .env

# Crea configurazione nginx
cat > docker/nginx/conf.d/default.conf << NGINX_CONF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root /var/www/html;
    index index.php index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://apache:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /phpmyadmin/ {
        proxy_pass http://phpmyadmin:80/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_redirect off;
        proxy_buffering off;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
NGINX_CONF

# Crea directory necessarie
mkdir -p src
mkdir -p docker/nginx/ssl
mkdir -p docker/mariadb/backup
mkdir -p docker/logs

# File PHP di test
echo "<?php phpinfo(); ?>" > src/index.php
chmod -R 755 src
chown -R www-data:www-data src

echo -e "${GREEN}Avvio container...${NC}"

# Riavvio container
docker-compose down
docker-compose up -d

# Attendi inizializzazione
sleep 10

# Verifica servizio HTTP
if curl -s -o /dev/null -w "%{http_code}" http://localhost > /dev/null; then
    echo -e "${GREEN}Servizio HTTP verificato, procedo con SSL${NC}"
    
    # Ottieni certificato SSL
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
        
        # Aggiorna configurazione nginx per HTTPS
        cat > docker/nginx/conf.d/default.conf << NGINX_SSL_CONF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    root /var/www/html;
    index index.php index.html;

    location / {
        proxy_pass http://apache:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /phpmyadmin/ {
        proxy_pass http://phpmyadmin:80/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_redirect off;
        proxy_buffering off;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
NGINX_SSL_CONF
        
        # Riavvia nginx
        docker-compose restart nginx
        
        # Configura rinnovo automatico
        (crontab -l 2>/dev/null | grep -v "certbot renew") | crontab -
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
    echo -e "${RED}Errore: servizio HTTP non raggiungibile${NC}"
    exit 1
fi

# Verifica finale
echo -e "\n${GREEN}Stato dei servizi:${NC}"
docker-compose ps
