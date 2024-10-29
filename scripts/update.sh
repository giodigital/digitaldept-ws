#!/bin/bash

echo "Aggiornamento DigitalDept WS"
echo "=========================="

# Pull delle nuove immagini
echo "Downloading nuove versioni..."
docker-compose pull

# Backup del database
echo "Backup database..."
./scripts/utils/backup.sh

# Riavvio con nuove versioni
echo "Riavvio servizi..."
docker-compose down
docker-compose up -d

echo "Aggiornamento completato!"
echo "Verifica lo stato con: docker-compose ps"
