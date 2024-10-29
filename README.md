# DigitalDept WS

<div align="center">

```
╔╦╗┬┌─┐┬┌┬┐┌─┐┬    ╔╦╗┌─┐┌─┐┌┬┐  ╦ ╦╔═╗
 ║║│├─┤│ │ ├─┤│     ║║├┤ ├─┘ │   ║║║╚═╗
═╩╝┴┴ ┴┴ ┴ ┴ ┴┴─┘  ═╩╝└─┘┴   ┴   ╚╩╝╚═╝
```

Stack completo per sviluppo web con Nginx in reverse proxy su Apache, PHP-FPM, MariaDB e Redis

</div>

## 🚀 Caratteristiche

- 🌐 Nginx come reverse proxy
- 🖥️ Apache come web server
- 🐘 PHP 8.3-FPM con estensioni ottimizzate
- 🔒 SSL/TLS automatico con Let's Encrypt
- 💾 MariaDB 10.11 per il database
- ⚡ Redis per caching
- 🔄 Backup automatizzati
- 📊 Monitoraggio integrato

## 📋 Prerequisiti

- Docker 20.10+
- Docker Compose 2.0+
- Git
- Dominio configurato con DNS puntato al server

## ⚡ Quick Start

```bash
# Clona il repository
git clone https://github.com/giodigital/digitaldept-ws.git
cd digitaldept-ws

# Setup ambiente
./scripts/setup-env.sh

# Installa con il tuo dominio
./scripts/install.sh your-domain.com your@email.com

# Monitora lo stato
./scripts/utils/monitor.sh
```

## 🏗️ Struttura

```
digitaldept-ws/
├── docker/
│   ├── nginx/          # Configurazione Nginx e SSL
│   ├── apache/         # Configurazione Apache
│   ├── php/            # PHP-FPM e estensioni
│   ├── mariadb/        # Configurazione DB
│   └── redis/          # Configurazione Redis
├── scripts/
│   ├── install.sh      # Script installazione
│   ├── setup-env.sh    # Setup ambiente
│   └── utils/          # Script utilità
├── src/                # Files applicazione
└── docs/              # Documentazione
```

## 🔧 Configurazione

### Virtual Hosts
Per aggiungere un nuovo dominio:
```bash
./scripts/install.sh nuovo-dominio.com email@dominio.com
```

### SSL/TLS
I certificati vengono gestiti automaticamente tramite Let's Encrypt:
- Generazione automatica durante l'installazione
- Rinnovo automatico via cron
- Backup periodico dei certificati

### Database
MariaDB è configurato con:
- Ottimizzazioni per la produzione
- Backup automatici
- Rotazione log

### Cache
Redis è configurato per:
- Sessioni PHP
- Object caching
- Persistenza dati

## 🛠️ Manutenzione

### Backup
```bash
# Backup manuale completo
./scripts/utils/backup.sh

# Verifica backup
ls -l docker/mariadb/backup/
```

### SSL
```bash
# Rinnovo manuale certificati
./scripts/utils/renew-ssl.sh
```

### Monitoraggio
```bash
# Stato sistema
./scripts/utils/monitor.sh
```

## 🔐 Sicurezza

- HTTPS forzato
- Headers di sicurezza
- Rate limiting
- Protezione DDoS base
- Backup cifrati
- Permessi restrittivi

## 🔍 Troubleshooting

### Log
```bash
# Tutti i log
docker-compose logs

# Log specifici
docker-compose logs nginx
docker-compose logs apache
docker-compose logs php
```

### Problemi comuni

1. **Certificato SSL non generato**
   ```bash
   ./scripts/utils/renew-ssl.sh
   ```

2. **Problemi permessi**
   ```bash
   chmod -R 755 src/
   chown -R www-data:www-data src/
   ```

## 📚 Documentazione estesa

Documentazione dettagliata disponibile in:
- [Setup Guida](docs/setup.md)
- [Configurazione](docs/configuration.md)
- [Sicurezza](docs/security.md)
- [Backup](docs/backup.md)

## 🤝 Contributing

1. Fork il repository
2. Crea un feature branch
3. Commit le modifiche
4. Push al branch
5. Crea una Pull Request

## 📝 License

MIT License - vedi [LICENSE](LICENSE)

## 🔧 Gestione Database

### phpMyAdmin
- Accesso: https://tuo-dominio.com/phpmyadmin/
- Credenziali: configurate nel file .env
- Funzionalità:
  - Gestione database
  - Import/Export dati
  - Gestione utenti
  - Query SQL

### Sicurezza phpMyAdmin
- Accesso protetto da autenticazione
- Connessione SSL/TLS
- Rate limiting configurato
- Accesso limitato alla rete backend

## 📦 Versioni dei componenti

- Nginx: stable-alpine
- Apache: 2.4
- PHP: 8.3-fpm
- MariaDB: 10.11
- Redis: 7-alpine
- phpMyAdmin: latest

## 💾 Backup Remoto

### Configurazione
1. Crea file `.backup.env` con i dettagli del server remoto
2. Configura le credenziali SSH
3. Imposta il percorso di backup remoto

### Backup Automatico
```bash
# Backup manuale
./scripts/backup/backup.sh

# Configurare backup automatico
crontab -e
# Aggiungi: 0 3 * * * cd /path/to/project && ./scripts/backup/backup.sh

