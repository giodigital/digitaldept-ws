#!/bin/bash

# Rinnova certificati
docker-compose run --rm certbot renew --quiet

# Riavvia nginx per applicare i nuovi certificati
docker-compose kill -s SIGHUP nginx

echo "Certificati SSL aggiornati"
