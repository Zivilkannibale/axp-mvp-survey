# Pull Request: Migrate to Strato MariaDB for Raw Data Storage

## Summary

This PR implements the migration from PostgreSQL to Strato's managed MariaDB 10.11 for raw survey data storage, while maintaining backward compatibility with existing PostgreSQL deployments.

## Changes

### Database Layer (`R/db.R`, `R/config.R`)
- **New MariaDB connector** using `RMariaDB` package with TLS support
- **Auto-dialect detection**: defaults to MariaDB, falls back to PostgreSQL if legacy `STRATO_PG_*` vars are set
- **TLS configuration**: `DB_TLS=1` enables encryption, `DB_TLS_CA_PATH` for custom CA
- **Parameterized queries**: dialect-aware placeholders (`?` for MariaDB, `$N` for Postgres)
- **Safe error handling**: passwords are redacted from error messages

### Schema (`sql/001_init_mariadb.sql`)
- MariaDB-compatible DDL with UTF8MB4 charset and InnoDB engine
- Tables: `submission`, `response_numeric`, `response_text`, `score`, `aggregate_norms`, `response_tracer`
- Proper indexes on `session_id` and `created_at` columns
- Foreign key constraints with `ON DELETE CASCADE`

### Export Pipeline (`scripts/export_public.R`)
- **Anonymization**: Session IDs are SHA-256 hashed with a configurable salt
- **Data cleaning**: Free-text responses are NEVER exported; timestamps coarsened to dates
- **Wide format output**: One row per session with item/scale columns
- **Codebook generation**: Auto-generated field descriptions

### OSF Upload (`scripts/osf_upload.R`)
- Full OSF API v2 implementation
- Uploads: `axp_public_latest.csv`, `codebook.csv`, `README.md`, `CHANGELOG.md`
- Token-based authentication (never logged)

### Documentation
- **README.md**: Production architecture table, data lifecycle diagram, deployment checklist, secrets management
- **DEVELOPMENT.md**: Updated persistence section with MariaDB details
- **CONTRIBUTING.md**: Updated environment variable table

## Environment Variables

### New (MariaDB - Primary)
```bash
DB_DIALECT=mariadb
DB_HOST=database-5019530911.webspace-host.com
DB_PORT=3306
DB_NAME=dbs15265782
DB_USER=dbu4550099
DB_PASSWORD=<secret>
DB_TLS=1
DB_TLS_VERIFY=1
DB_TLS_CA_PATH=  # optional
```

### Legacy (PostgreSQL - Still Supported)
```bash
STRATO_PG_HOST=...
STRATO_PG_DB=...
# etc.
```

### OSF Export
```bash
OSF_TOKEN=<secret>
OSF_PROJECT_ID=<project>
EXPORT_ANON_SALT=<random string>
```

## Deployment Checklist

After merging, the server operator should:

```bash
# 1. SSH to server
ssh root@85.215.90.33

# 2. Pull changes
cd /srv/shiny-server/axp-mvp-survey
git pull origin main

# 3. Install RMariaDB package
sudo -u shiny R -e "renv::install('RMariaDB')"
sudo -u shiny R -e "renv::snapshot()"  # optional

# 4. Fix renv drift
sudo -u shiny R -e "renv::restore()"
sudo -u shiny R -e "renv::install('systemfonts')"

# 5. Update app/.Renviron with DB_* variables
# (Add DB_PASSWORD securely)

# 6. Initialize database schema
sudo -u shiny R -e "source('scripts/init_db.R')"

# 7. Restart Shiny Server
systemctl restart shiny-server
```

## Testing Notes

- Local testing works without DB (skips writes)
- Set `DEV_MODE=true` for step jumping
- Export scripts require DB connection

## Breaking Changes

- Environment variables changed from `STRATO_PG_*` to `DB_*`
- Legacy vars still work but are deprecated

## Dependencies

- Requires `RMariaDB` package (not yet in lockfile - install on server)
- `uuid` and `digest` packages (already available)
