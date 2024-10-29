#!/bin/bash

# Carica configurazione
source .backup.env

# Configurazione
RESTORE_DIR="/tmp/restore-temp"

# Funzione per log
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Lista backup disponibili
list_remote_backups() {
    log_message "Backup disponibili sul server remoto:"
    
    sshpass -p "${BACKUP_SERVER_PASSWORD}" ssh -p "${BACKUP_SERVER_PORT}" \
        "${BACKUP_SERVER_USER}@${BACKUP_SERVER_HOST}" \
        "ls -l ${BACKUP_SERVER_PATH}/{database,files,configs}"
}

# Scarica backup
download_backup() {
    local type=$1
    local filename=$2
    
    log_message "Download backup $filename..."
    
    mkdir -p "${RESTORE_DIR}"
    
    sshpass -p "${BACKUP_SERVER_PASSWORD}" scp -P "${BACKUP_SERVER_PORT}" \
        "${BACKUP_SERVER_USER}@${BACKUP_SERVER_HOST}:${BACKUP_SERVER_PATH}/${type}/${filename}" \
        "${RESTORE_DIR}/${filename}"
}

# Ripristino
restore_backup() {
    local type=$1
    local filename=$2
    
    case $type in
        "database")
            if [[ "$filename" == *.gz ]]; then
                gunzip -c "${RESTORE_DIR}/${filename}" | \
                    docker-compose exec -T mariadb mysql -u root -p"${DB_ROOT_PASSWORD}"
            else
                cat "${RESTORE_DIR}/${filename}" | \
                    docker-compose exec -T mariadb mysql -u root -p"${DB_ROOT_PASSWORD}"
            fi
            ;;
        "files")
            tar -xzf "${RESTORE_DIR}/${filename}" -C /
            ;;
        "configs")
            tar -xzf "${RESTORE_DIR}/${filename}" -C /
            ;;
        *)
            log_message "Tipo di backup non valido"
            return 1
            ;;
    esac
}

# Main
case $1 in
    "list")
        list_remote_backups
        ;;
    "restore")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Uso: $0 restore <type> <filename>"
            echo "Types: database, files, configs"
            exit 1
        fi
        download_backup "$2" "$3" && restore_backup "$2" "$3"
        rm -rf "${RESTORE_DIR}"
        ;;
    *)
        echo "Uso: $0 {list|restore}"
        echo "Esempio: $0 restore database backup_20240129.sql.gz"
        exit 1
        ;;
esac
