#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Funzione per logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Verifica parametri
if [ -z "$1" ]; then
    error "Usage: $0 domain.com [email]"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"webmaster@$DOMAIN"}

# Aggiorna .env con il dominio
sed -i "s/DOMAIN=.*/DOMAIN=$DOMAIN/" .env

# Ricarica le variabili d'ambiente
source .env

log "DigitalDept WS - Installation"
log "=============================="

# Verifica prerequisiti
command -v docker >/dev/null 2>&1 || { 
    warning "Docker non trovato. Installazione..."
    curl -fsSL https://get.docker.com | sh
}
command -v docker-compose >/dev/null 2>&1 || {
    warning "Docker Compose non trovato. Installazione..."
    apt install -y docker-compose
}

# Crea la struttura delle directory
log "Creazione struttura directory..."
mkdir -p src
mkdir -p docker/nginx/{conf.d,ssl}
mkdir -p docker/mariadb/backup
mkdir -p docker/logs/${DOMAIN}

# Configurazione iniziale nginx (solo HTTP)
log "Configurazione nginx iniziale..."
cat > docker/nginx/conf.d/${DOMAIN}.conf << NGINX_CONF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root /var/www/html;
    index index.php index.html;

    # Certbot challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files \$uri =404;
    }

    # Proxy settings for Apache
    location / {
        proxy_pass http://apache:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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

# Crea file PHP di test
log "Creazione file di test..."
echo "<?php phpinfo(); ?>" > src/index.php

# Imposta permessi
log "Configurazione permessi..."
chmod -R 755 src
chown -R www-data:www-data src

# Avvio container
log "Avvio container..."
docker-compose down
docker-compose up -d

# Attesa per inizializzazione
warning "Attendo l'inizializzazione dei servizi..."
sleep 10

# Test connettività HTTP
log "Verifica connettività HTTP..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost > /dev/null; then
    log "Servizio HTTP verificato, procedo con SSL"
    
    # Configurazione SSL
    warning "Ottengo certificato SSL..."
    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d ${DOMAIN}

    if [ $? -eq 0 ]; then
        log "Certificato SSL ottenuto con successo"
        
        # Aggiorna configurazione nginx per HTTPS
        log "Configurazione HTTPS..."
        cat > docker/nginx/conf.d/${DOMAIN}.conf << NGINX_SSL_CONF
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

    root /var/www/html;
    index index.php index.html;

    # phpMyAdmin configuration
    location /phpmyadmin/ {
        proxy_pass http://phpmyadmin:80/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_redirect off;
        proxy_buffering off;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Proxy settings for Apache
    location / {
        proxy_pass http://apache:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # PHP handling
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param PHP_VALUE "upload_max_filesize = 64M \n post_max_size = 64M";
    }

    # Cache static files
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
NGINX_SSL_CONF
        
        # Riavvia nginx
        log "Riavvio nginx con la nuova configurazione..."
        docker-compose restart nginx
        
        # Configura rinnovo automatico certificati
        log "Configurazione rinnovo automatico certificati..."
        (crontab -l 2>/dev/null | grep -v "certbot renew") | crontab -
        (crontab -l 2>/dev/null; echo "0 0 * * * cd $(pwd) && docker-compose run --rm certbot renew --quiet && docker-compose kill -s SIGHUP nginx") | crontab -

        log "Installazione completata con successo!"
        log "Sito disponibile su:"
        log "- https://${DOMAIN}"
        log "- https://${DOMAIN}/phpmyadmin/"
    else
        error "Errore durante l'ottenimento del certificato SSL"
        exit 1
    fi
else
    error "Errore: servizio HTTP non raggiungibile"
    error "Verifica:"
    error "1. La configurazione DNS"
    error "2. Le regole del firewall (porte 80 e 443)"
    error "3. La raggiungibilità del server"
    docker-compose logs nginx
    exit 1
fi

# Verifica finale dei servizi
warning "Controllo stato servizi:"
for service in nginx apache php mariadb redis phpmyadmin; do
    if docker-compose ps $service | grep -q "Up"; then
        log "$service: OK"
    else
        error "$service: KO"
    fi
done

# Informazioni finali
log "Informazioni utili:"
log "1. I log sono disponibili in docker/logs/${DOMAIN}/"
log "2. I backup del database sono in docker/mariadb/backup/"
log "3. Per monitorare i log: docker-compose logs -f"
log "4. Per riavviare un servizio: docker-compose restart [servizio]"
log "5. Accesso phpMyAdmin: https://${DOMAIN}/phpmyadmin/"

# Test finale HTTPS
if curl -sk -o /dev/null -w "%{http_code}" "https://${DOMAIN}" | grep -q "200"; then
    log "Test HTTPS completato con successo"
else
    warning "HTTPS potrebbe richiedere qualche minuto per essere completamente attivo"
fi

log "Setup completato con successo!"

