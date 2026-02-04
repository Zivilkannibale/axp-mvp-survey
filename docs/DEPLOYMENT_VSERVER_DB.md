# vServer Database Deployment Guide

This document provides step-by-step instructions for deploying the self-hosted
MariaDB database on the vServer for the AXP MVP Survey application.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           vServer (85.215.90.33)                            │
│                                                                             │
│  ┌─────────────────┐         ┌─────────────────┐                           │
│  │  Shiny Server   │         │  Docker         │                           │
│  │  (systemd)      │         │                 │                           │
│  │                 │         │  ┌───────────┐  │                           │
│  │  app.R ─────────┼────────►│  │ MariaDB   │  │                           │
│  │                 │ 127.0.0.1  │ 10.11     │  │                           │
│  │  Port: 3838     │ :3307   │  │           │  │                           │
│  └─────────────────┘         │  └───────────┘  │                           │
│           │                  │        │        │                           │
│           │                  │  ┌─────▼─────┐  │                           │
│           │                  │  │  Volume   │  │                           │
│           │                  │  │  (data)   │  │                           │
│           │                  │  └───────────┘  │                           │
│           │                  └─────────────────┘                           │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐                                                       │
│  │  Traefik        │ ◄──── HTTPS (443)                                     │
│  │  (reverse proxy)│                                                       │
│  └─────────────────┘                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| MariaDB self-hosted | Strato managed DB resolves to private IP, unreachable from vServer |
| Port 3307 | Avoids conflicts with any existing MySQL/MariaDB installations |
| Bind to 127.0.0.1 | Database is NOT publicly accessible (security) |
| DB_SSL=false | TLS not needed for localhost connections |
| Docker volume | Data persists across container restarts |

---

## Prerequisites

- SSH access to vServer as root
- Docker and docker-compose installed (already present)
- Git repo cloned at `/srv/shiny-server/axp-mvp-survey`
- For local Windows testing: R installed (and `R.exe`/`Rscript.exe` available),
  Docker Desktop running, and `RMariaDB` installed in the project `renv` library.

---

## Step 1: Start the Database

```bash
# Navigate to the ops directory
cd /srv/shiny-server/axp-mvp-survey/ops/mariadb

# Create the .env file with passwords (NEVER commit this)
cp .env.example .env
nano .env

# Set strong passwords:
# MARIADB_PASSWORD=<generate-secure-password>
# MARIADB_ROOT_PASSWORD=<generate-different-secure-password>

# Secure the .env file
chmod 600 .env

# Start the database
docker compose up -d

# Verify it's running
docker ps | grep axp-mariadb

# Check logs
docker logs axp-mariadb
```

### Verify Database Connection

```bash
# Test connection (will prompt for password)
mysql -h 127.0.0.1 -P 3307 -u axp_app -p axp_mvp

# Inside MySQL, verify:
SHOW DATABASES;
SELECT VERSION();
\q
```

---

## Step 2: Configure Shiny Environment

```bash
# Navigate to app directory
cd /srv/shiny-server/axp-mvp-survey/app

# Create .Renviron from example
cp .Renviron.example .Renviron

# Edit with actual values
nano .Renviron
```

**Required settings for database:**

```
DB_DIALECT=mariadb
DB_HOST=127.0.0.1
DB_PORT=3307
DB_NAME=axp_mvp
DB_USER=axp_app
DB_PASSWORD=<same-password-from-docker-env>
DB_SSL=false
```

**Required settings for Google Sheets (production):**

```
GOOGLE_SHEET_ID=...
GOOGLE_SHEET_SHEETNAME=...
GOOGLE_SHEET_AUTH_JSON=/srv/shiny-server/axp-mvp-survey/secret/your-service-account.json
GOOGLE_SHEET_AUTH_EMAIL=...
GOOGLE_SHEET_USE_OAUTH=false
```

**Secure the file:**

```bash
chmod 600 .Renviron
chown shiny:shiny .Renviron
```

---

## Step 3: Initialize Database Schema

```bash
cd /srv/shiny-server/axp-mvp-survey

# Run as shiny user to match runtime permissions
sudo -u shiny Rscript scripts/init_mariadb.R
```

**Expected output:**

```
Loaded environment from app/.Renviron
Connecting to MariaDB...
✅ Connected successfully
Initializing schema from sql/001_init_mariadb.sql...
✅ Schema initialized
Tables in database:
[1] "submission" "response_numeric" "response_text" "score" "aggregate_norms" "response_tracer"
✅ All expected tables present
Done.
```

---

## Step 4: Restart Shiny Server

```bash
systemctl restart shiny-server
systemctl status shiny-server
```

---

## Step 5: Test the Application

1. Open browser: `http://85.215.90.33:3838/axp-mvp-survey/app/`
2. Complete a test survey
3. Verify data was saved:

```bash
mysql -h 127.0.0.1 -P 3307 -u axp_app -p axp_mvp -e "SELECT COUNT(*) FROM submission;"
```

---

## Local Testing (Windows)

If you are running the app locally (not on the vServer), ensure R loads
`app/.Renviron` so the DB settings are available to the app.

```powershell
$env:R_ENVIRON_USER = "C:\\Users\\<you>\\source\\repos\\axp-mvp-survey\\app\\.Renviron"
R.exe -q -e "shiny::runApp('app', port = 3838)"
```

If the app logs: `RMariaDB package is required`, install it in the project:

```powershell
R.exe -q -e "renv::install('RMariaDB')"
```

To verify local DB writes without stopping the app, run in a second shell:

```powershell
docker exec -e MYSQL_PWD=<app_password> axp-mariadb mariadb -u axp_app -e "SELECT COUNT(*) FROM submission;" axp_mvp
```

---

## Notes From Deployment (2026-02-03)

- If `mysql` CLI is missing on the vServer, use the MariaDB client inside the container:
  `docker exec -e MYSQL_PWD=<app_password> axp-mariadb mariadb -u axp_app -e "SELECT COUNT(*) FROM submission;" axp_mvp`
- If `renv` attempts to bootstrap inside `app/`, ensure `app/.Rprofile` exists and sets
  `RENV_PROJECT` to the repo root (already included in this branch).
- If `RMariaDB` fails to install, install system dependency:
  `apt install -y libmysqlclient-dev`
- Ensure `shiny` owns the repo `renv/` directory so packages can be installed:
  `chown -R shiny:shiny /srv/shiny-server/axp-mvp-survey/renv`

## Step 6: Configure Automated Backups

### Create Backup Directory

```bash
mkdir -p /srv/axp-db-backups
chmod 700 /srv/axp-db-backups
```

### Make Backup Script Executable

```bash
chmod +x /srv/shiny-server/axp-mvp-survey/ops/mariadb/backup.sh
```

### Test Backup

```bash
/srv/shiny-server/axp-mvp-survey/ops/mariadb/backup.sh
ls -la /srv/axp-db-backups/
```

### Schedule Daily Backups (as root)

```bash
crontab -e
```

Add this line:

```
30 2 * * * /srv/shiny-server/axp-mvp-survey/ops/mariadb/backup.sh >> /var/log/axp_db_backup.log 2>&1
```

This runs backups at 2:30 AM daily, keeping the last 14 backups.

---

## Step 7: Configure Data Export Jobs

### As user shiny:

```bash
sudo -u shiny crontab -e
```

Add these lines:

```
# Export public data daily at 3:00 AM
0 3 * * * cd /srv/shiny-server/axp-mvp-survey && Rscript scripts/export_public.R >> /var/log/axp_export.log 2>&1

# Upload to OSF daily at 3:15 AM
15 3 * * * cd /srv/shiny-server/axp-mvp-survey && Rscript scripts/osf_upload.R >> /var/log/axp_osf.log 2>&1
```

---

## Troubleshooting

### Database Connection Refused

```bash
# Check if container is running
docker ps | grep axp-mariadb

# Check container logs
docker logs axp-mariadb --tail 50

# Restart container
docker compose -f /srv/shiny-server/axp-mvp-survey/ops/mariadb/docker-compose.yml restart
```

### Shiny Can't Connect to DB

```bash
# Test .Renviron is readable by shiny
sudo -u shiny cat /srv/shiny-server/axp-mvp-survey/app/.Renviron | grep DB_

# Test R can connect
sudo -u shiny Rscript -e "
  readRenviron('app/.Renviron')
  source('R/config.R')
  source('R/db.R')
  con <- db_connect()
  print(con)
  DBI::dbDisconnect(con)
"
```

### renv Issues

```bash
cd /srv/shiny-server/axp-mvp-survey

# Check status
sudo -u shiny Rscript -e "renv::status()"

# Restore missing packages
sudo -u shiny Rscript -e "renv::restore()"

# Known issues:
# - systemfonts may require: apt-get install libfontconfig1-dev
# - uuid version mismatch: renv::restore() should fix
```

### Restore from Backup

```bash
# Find latest backup
ls -lt /srv/axp-db-backups/

# Restore (replace filename)
gunzip -c /srv/axp-db-backups/axp_mvp_2026-02-03.sql.gz | \
  docker exec -i axp-mariadb mysql -u root -p axp_mvp
```

---

## Security Checklist

- [ ] `.env` file has chmod 600, not in git
- [ ] `.Renviron` file has chmod 600, owned by shiny
- [ ] Database only bound to 127.0.0.1 (not 0.0.0.0)
- [ ] Strong passwords for MARIADB_PASSWORD and MARIADB_ROOT_PASSWORD
- [ ] Backup directory has chmod 700
- [ ] No secrets committed to git

---

## File Locations Summary

| File | Purpose | Permissions |
|------|---------|-------------|
| `/srv/shiny-server/axp-mvp-survey/ops/mariadb/docker-compose.yml` | DB container definition | 644 |
| `/srv/shiny-server/axp-mvp-survey/ops/mariadb/.env` | DB passwords | 600 |
| `/srv/shiny-server/axp-mvp-survey/app/.Renviron` | App secrets | 600, shiny:shiny |
| `/srv/shiny-server/axp-mvp-survey/secret/*.json` | Google auth | 600, shiny:shiny |
| `/srv/axp-db-backups/` | Database backups | 700 |
| `/var/log/axp_*.log` | Application logs | various |

---

## Quick Reference Commands

```bash
# Start DB
cd /srv/shiny-server/axp-mvp-survey/ops/mariadb && docker compose up -d

# Stop DB
cd /srv/shiny-server/axp-mvp-survey/ops/mariadb && docker compose down

# View DB logs
docker logs axp-mariadb -f

# Restart Shiny
systemctl restart shiny-server

# Check Shiny status
systemctl status shiny-server

# Manual backup
/srv/shiny-server/axp-mvp-survey/ops/mariadb/backup.sh

# Connect to DB
mysql -h 127.0.0.1 -P 3307 -u axp_app -p axp_mvp
```
