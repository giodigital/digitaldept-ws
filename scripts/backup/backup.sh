#!/bin/bash

# Carica configurazione
source .backup.env

# Configurazione
BACKUP_DIR="/tmp/backup-temp"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Funzione per log
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a backup.log
}

# Crea directory temporanea
setup_temp_dir() {
    log_message "Preparazione directory temporanea..."
    rm -rf "${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}/{database,files,configs}"
}

# Backup Database
backup_database() {
    log_message "Backup database..."
    
    docker-compose exec -T mariadb mysqldump -u root \
        -p"${DB_ROOT_PASSWORD}" --all-databases --events \
        --routines --triggers --single-transaction --quick \
        > "${BACKUP_DIR}/database/all_databases_${TIMESTAMP}.sql"
    
    gzip "${BACKUP_DIR}/database/all_databases_${TIMESTAMP}.sql"
    
    log_message "Backup database completato"
}

# Backup Files
backup_files() {
    log_message "Backup files..."
    
    # Backup src directory
    tar -czf "${BACKUP_DIR}/files/src_${TIMESTAMP}.tar.gz" src/
    
    # Backup configurations
    tar -czf "${BACKUP_DIR}/configs/configs_${TIMESTAMP}.tar.gz" \
        docker/nginx/conf.d/ \
        docker/apache/conf.d/ \
        docker/php/ \
        docker/mariadb/conf.d/ \
        .env
        
    # Backup SSL certificates
    docker-compose exec -T nginx tar -czf - /etc/letsencrypt \
        > "${BACKUP_DIR}/configs/ssl_${TIMESTAMP}.tar.gz"
    
    log_message "Backup files completato"
}

# Trasferimento tramite sshpass
transfer_backups() {
    log_message "Trasferimento backup al server remoto..."
    
    # Installa sshpass se non presente
    if ! command -v sshpass &> /dev/null; then
        apt-get update && apt-get install -y sshpass
    fi
    
    # Crea directory remota
    sshpass -p "${BACKUP_SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        -p "${BACKUP_SERVER_PORT}" \
        "${BACKUP_SERVER_USER}@${BACKUP_SERVER_HOST}" \
        "mkdir -p ${BACKUP_SERVER_PATH}/{database,files,configs}"
    
    # Trasferisci i file
    for type in database files configs; do
        sshpass -p "${BACKUP_SERVER_PASSWORD}" scp -P "${BACKUP_SERVER_PORT}" \
            -r "${BACKUP_DIR}/${type}/"* \
            "${BACKUP_SERVER_USER}@${BACKUP_SERVER_HOST}:${BACKUP_SERVER_PATH}/${type}/"
    done
    
    log_message "Trasferimento completato"
}

# Pulizia backup remoti
cleanup_remote_backups() {
    log_message "Pulizia backup remoti..."
    
    sshpass -p "${BACKUP_SERVER_PASSWORD}" ssh -p "${BACKUP_SERVER_PORT}" \
        "${BACKUP_SERVER_USER}@${BACKUP_SERVER_HOST}" \
        "find ${BACKUP_SERVER_PATH} -type f -mtime +${BACKUP_RETENTION_DAYS} -delete"
    
    log_message "Pulizia completata"
}

# Pulizia locale
cleanup_local() {
    log_message "Pulizia directory temporanea..."
    rm -rf "${BACKUP_DIR}"
    log_message "Pulizia completata"
}

# Verifica spazio disponibile
check_disk_space() {
    local min_space=5  # GB
    local available=$(df -BG "${BACKUP_DIR}" | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if [ "$available" -lt "$min_space" ]; then
        log_message "ERRORE: Spazio insufficiente (${available}GB). Necessari ${min_space}GB"
        return 1
    fi
    return 0
}

# Verifica connessione SSH
check_ssh_connection() {
    log_message "Verifica connessione SSH..."
    
    if sshpass -p "${BACKUP_SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        -p "${BACKUP_SERVER_PORT}" \
        "${BACKUP_SERVER_USER}@${BACKUP_SERVER_HOST}" "echo 'Connection test'" &> /dev/null; then
        log_message "Connessione SSH OK"
        return 0
    else
        log_message "ERRORE: Connessione SSH fallita"
        return 1
    fi
}

# Notifica via email (se configurata)
send_notification() {
    local status=$1
    local message=$2
    
    if [ ! -z "${NOTIFICATION_EMAIL}" ]; then
        echo "${message}" | mail -s "Backup ${status} - $(date +%Y-%m-%d)" "${NOTIFICATION_EMAIL}"
    fi
}

# Main backup procedure
main() {
    log_message "Inizio procedura di backup"
    
    # Verifiche preliminari
    check_disk_space || exit 1
    check_ssh_connection || exit 1
    
    # Setup
    setup_temp_dir
    
    # Esegui backup
    backup_database
    backup_files
    
    # Trasferisci
    if transfer_backups; then
        cleanup_remote_backups
        send_notification "SUCCESS" "Backup completato e trasferito con successo"
    else
        send_notification "ERROR" "Errore durante il trasferimento del backup"
        exit 1
    fi
    
    # Pulizia
    cleanup_local
    
    log_message "Backup completato con successo"
}

# Esegui backup
main
