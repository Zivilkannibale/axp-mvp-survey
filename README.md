# axp-mvp-survey

MVP Shiny survey pipeline with Google Sheets questionnaire definitions, MariaDB persistence, scoring, norms, and export tooling for OSF.

## Quick Start (Local Development)

No external services required for local testing:

```bash
# 1. Clone and enter the repo
git clone <repo-url>
cd axp-mvp-survey

# 2. Restore R dependencies
Rscript -e "renv::restore()"

# 3. Run the app
Rscript -e "shiny::runApp('app')"
```

The app automatically uses `docs/sample_questionnaire.csv` when Google Sheets isn't configured.
Language-specific CSVs are available at `docs/sample_questionnaire_en.csv` and `docs/sample_questionnaire_de.csv`.

**Optional:** Enable dev mode for step jumping:
```r
Sys.setenv(DEV_MODE = "true")
shiny::runApp("app")
```

**Local MariaDB smoke test (Windows + Docker Desktop):**

```powershell
# Ensure R loads app/.Renviron for DB_* settings
$env:R_ENVIRON_USER = "C:\Users\<you>\source\repos\axp-mvp-survey\app\.Renviron"

# Install RMariaDB if needed
R.exe -q -e "renv::install('RMariaDB')"

# Run the app
R.exe -q -e "shiny::runApp('app', port = 3838)"
```

In another shell, verify DB writes:

```powershell
docker exec -e MYSQL_PWD=<app_password> axp-mariadb mariadb -u axp_app -e "SELECT COUNT(*) FROM submission;" axp_mvp
```

Note: On the vServer, the `mysql` CLI may not be installed. Use `docker exec ... mariadb` as shown above to query the DB from the container.

## For New Contributors

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Project architecture overview
- How to add new input types
- Styling guidelines
- Browser compatibility notes

## Development Guide

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for:
- Detailed architecture diagram
- Step-by-step extension patterns
- Troubleshooting tips

## Environment Variables

See `config/.env.example` for the full list. All are optional for local development.

## Safe Server Updates (Do Not Overwrite Secrets)

The server keeps secrets and runtime config **outside git**. These files must never be overwritten:

- `app/.Renviron`
- `ops/mariadb/.env`

**Safe update flow (recommended):**

```bash
cd /srv/shiny-server/axp-mvp-survey
git fetch origin
git checkout feature/mariadb-migration
git pull --ff-only
```

**Optional safety backup before pull:**

```bash
cp app/.Renviron app/.Renviron.bak
cp ops/mariadb/.env ops/mariadb/.env.bak
```

If Google Sheets config stops working after a pull, re-check `app/.Renviron` and confirm:

```
GOOGLE_SHEET_ID=...
GOOGLE_SHEET_SHEETNAME=...
GOOGLE_SHEET_AUTH_JSON=/srv/shiny-server/axp-mvp-survey/secret/your-service-account.json
GOOGLE_SHEET_AUTH_EMAIL=...
GOOGLE_SHEET_USE_OAUTH=false
```

## Questionnaire in Google Sheets

- Option A (no auth): publish your sheet as CSV and set `GOOGLE_SHEET_CSV_URL`.
- Option B (API): set `GOOGLE_SHEET_ID` and `GOOGLE_SHEET_SHEETNAME`, then configure auth via
  `GOOGLE_SHEET_AUTH_JSON` (service account) or `GOOGLE_SHEET_USE_OAUTH=true` for cached OAuth.
- The UI includes a reload button and optional sheet-tab override; page refresh also reloads the questionnaire.
- API loading uses `googlesheets4`.
- If both are set, API loading is attempted first, then CSV, then the local sample.
- For non-interactive runs, set `GARGLE_OAUTH_CACHE` to the folder holding the cached token.
- Required columns are listed in `docs/questionnaire_schema.md`.
- Versioning is tracked via `instrument_id`, `instrument_version`, `language`, and `definition_hash`.
- Optional UI columns include `width`, `placeholder`, `slider_left_label`, `slider_right_label`, and `slider_ticks`.
- The experience tracer uses additional optional columns (see below).
- Recommended workflow:
  - Develop locally with `docs/sample_questionnaire.csv` and run the app to validate changes.
  - Push to the repo and have the server pull the latest code.
  - Upload the CSV to Google Drive, open it as a Google Sheet, and copy its contents into a new tab in the shared survey sheet that the server service account can access.

### Collaborator setup

Pick one of the following:

- Service account (shared key, no prompts):
  - Share the sheet with the service account email.
  - Provide the JSON key file out-of-band (do not commit).
  - Set `GOOGLE_SHEET_AUTH_JSON` and `GOOGLE_SHEET_USE_OAUTH=false`.
- OAuth (per-user login):
  - Share the sheet with each collaborator's Google account.
  - Set `GOOGLE_SHEET_USE_OAUTH=true`.
  - First run will prompt for Google login; token is cached.

## Slider input

The questionnaire supports a custom `sliderInput` type. Required sliders must be touched; the UI sets a `__touched` flag when the slider moves and uses it to enable the Next button on slider pages. If no default value is provided, sliders initialize at the midpoint. The UI generator is vendored in `R/quetzio/` (see `R/quetzio/NOTICE.txt`).

## Experience tracer input

The questionnaire supports a custom `experience_tracer` type (drawn curve over time). It records raw points and a resampled vector on submit.

Optional columns for tracer configuration (all optional):
- `tracer_instruction` (string)
- `tracer_duration_seconds` (number; used to label the x-axis in minutes)
- `tracer_y_min`, `tracer_y_max` (number; default 0..100)
- `tracer_samples` (number; resampled vector length)
- `tracer_height` (number; canvas height in px)
- `tracer_min_points` (number; minimum points for required validation)
- `tracer_top_label` (string; top-right label inside the canvas)
- `tracer_grid_cols`, `tracer_grid_rows` (number; grid resolution)

The local reference row lives in `docs/sample_questionnaire.csv`. You can copy its columns/values into the Google Sheet to update the schema.

## Production architecture (current)

### Infrastructure overview (as of 2026-02-03)

| Component | Technology | Details |
|-----------|------------|--------|
| Frontend | Shiny app | Deployed via Shiny Server on Ubuntu 20.04.6 LTS |
| Raw data storage | MariaDB 10.11 (self-hosted) | Docker container on vServer, localhost only |
| Public data | OSF | Cleaned CSVs uploaded on schedule |
| Questionnaire source | Google Sheets (build-time) | Multi-collaborator editing; CSV fallback |

**Why self-hosted MariaDB?** The Strato managed DB resolves to a private IP (10.x.x.x) and has no IP whitelist feature, making it unreachable from the vServer. Self-hosting ensures reliable connectivity.

### Data lifecycle

```
┌─────────────────┐     ┌────────────────┐     ┌──────────────────┐
│   Shiny UI      │────►│  Validate +    │────►│  MariaDB (raw)   │
│  (participant)  │     │  sanitize      │     │  - submission    │
└─────────────────┘     └────────────────┘     │  - responses     │
                                                │  - scores        │
                                                └────────┬─────────┘
                                                         │ periodic
                                                         ▼ export job
                                                ┌────────────────────┐
                                                │  Clean / redact    │
                                                │  - remove free text│
                                                │  - anon session id │
                                                └────────┬───────────┘
                                                         │
                                                         ▼
                                                ┌────────────────────┐
                                                │  Public CSV        │
                                                │  (exports/)        │
                                                └────────┬───────────┘
                                                         │ osf_upload.R
                                                         ▼
                                                ┌────────────────────┐
                                                │  OSF repository    │
                                                │  (researchers)     │
                                                └────────────────────┘
```

**Important:** Public CSVs must NOT contain raw free text or identifiable metadata. Free-text is stored only in MariaDB for potential manual review and is never exported.

### Database configuration (MariaDB - self-hosted)

The database runs as a Docker container on the vServer, bound to localhost only (not publicly accessible).

Set the following environment variables (in `app/.Renviron` on server):

```bash
DB_DIALECT=mariadb
DB_HOST=127.0.0.1
DB_PORT=3307
DB_NAME=axp_mvp
DB_USER=axp_app
DB_PASSWORD=...        # NEVER commit
DB_SSL=false           # TLS not needed for localhost
DB_USER=axp_app
DB_PASSWORD=...        # NEVER commit
DB_SSL=false           # TLS not needed for localhost
```

**Note:** `DB_SSL=false` is correct for localhost connections. TLS is only needed for remote databases.

For local development without a database, simply omit `DB_*` variables — the app will skip DB writes.

### Full deployment guide

For complete step-by-step instructions including Docker setup, backups, and cron jobs, see:

📄 **[docs/DEPLOYMENT_VSERVER_DB.md](docs/DEPLOYMENT_VSERVER_DB.md)**

### Secrets management

**Principle:** No secrets in git. Ever.

All sensitive values are stored on the server in `app/.Renviron` (or `secret/` directory for JSON keys). This file is:
- **Not tracked** in git (listed in `.gitignore`)
- **Owned by `shiny`** user (or www-data depending on config)
- **Permissions `600`** (read/write owner only)

Required secrets for production:

| Variable | Purpose | Location |
|----------|---------|----------|
| `DB_PASSWORD` | MariaDB password | `app/.Renviron` |
| `OSF_TOKEN` | OSF API token for uploads | `app/.Renviron` |
| `GOOGLE_SHEET_AUTH_JSON` | Path to Google service account JSON | `app/.Renviron` (points to `secret/*.json`) |

**Never log secrets.** The codebase explicitly avoids printing `DB_PASSWORD` or `OSF_TOKEN` values.

### Server facts (verified 2026-02-02 Europe/Berlin)

| Property | Value |
|----------|-------|
| OS | Ubuntu 20.04.6 LTS (OpenVZ virtualization) |
| Shiny Server | active (systemd); listens on port 3838 |
| Config | `/etc/shiny-server/shiny-server.conf` -> `site_dir /srv/shiny-server`, `run_as shiny` |
| Repo path | `/srv/shiny-server/axp-mvp-survey` |
| R version | 4.5.2 |
| renv | 1.1.6 |
| Reverse proxy | Traefik (Docker) on ports 80/443/8080 |

### Current server deployment (STRATO)

- App path: `/srv/shiny-server/axp-mvp-survey/app`
- Service account JSON: `/srv/shiny-server/axp-mvp-survey/secret/axp-mvp-3ec693c04c81.json`
- App env: `/srv/shiny-server/axp-mvp-survey/app/.Renviron` (contains Google Sheets config)
- Shiny Server listens on `http://85.215.90.33:3838/axp-mvp-survey/`
- HTTPS is expected to be added via Traefik + DNS (e.g., `axp.circe-science.de`)

### Server sync (non-destructive)

Use the following command block to sync the STRATO server with the deploy branch without clobbering local modifications. It backs up server-only files, attempts a fast-forward pull (no merge), restores secrets/configs, fixes ownership/permissions, and restarts Shiny Server. The backup/restore steps ensure `.Renviron`, `.Rprofile`, the service account JSON, and Shiny Server config survive even if tracked files change. The `--ff-only` pull protects against accidental merges when the server has local commits.

```bash
cd /srv/shiny-server/axp-mvp-survey

# backup server-only files
backup_dir="/tmp/axp-server-only-$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"
cp -a app/.Rprofile app/.Renviron secret/axp-mvp-3ec693c04c81.json "$backup_dir"/ 2>/dev/null || true
sudo cp -a /etc/shiny-server/shiny-server.conf "$backup_dir"/shiny-server.conf 2>/dev/null || true

# sync without clobbering local changes
git fetch origin
git status --short
DEPLOY_BRANCH="feature/mariadb-migration"
git pull --ff-only origin "$DEPLOY_BRANCH"

# restore server-only files (in case tracked files overwrote them)
cp -a "$backup_dir"/.Rprofile app/.Rprofile 2>/dev/null || true
cp -a "$backup_dir"/.Renviron app/.Renviron 2>/dev/null || true
mkdir -p secret
cp -a "$backup_dir"/axp-mvp-3ec693c04c81.json secret/axp-mvp-3ec693c04c81.json 2>/dev/null || true
sudo cp -a "$backup_dir"/shiny-server.conf /etc/shiny-server/shiny-server.conf 2>/dev/null || true

# fix ownership/permissions
chown shiny:shiny app/.Rprofile app/.Renviron secret/axp-mvp-3ec693c04c81.json 2>/dev/null || true
chmod 644 app/.Rprofile 2>/dev/null || true
chmod 600 app/.Renviron secret/axp-mvp-3ec693c04c81.json 2>/dev/null || true

systemctl restart shiny-server
```

### Shiny Server routing (important)

The app is served at `/axp-mvp-survey/` (not `/axp-mvp-survey/app/`). SockJS must be reachable at:

- `/axp-mvp-survey/__sockjs__/info`

Shiny Server config should include:

```
location /axp-mvp-survey {
  app_dir /srv/shiny-server/axp-mvp-survey/app;
  log_dir /var/log/shiny-server;
}
```

The current config template lives at `ops/shiny-server/shiny-server.conf.template`.

If the app disconnects immediately, verify the websocket endpoint above returns JSON and that `app/app.R` sets `shiny.baseurl` to `/axp-mvp-survey/`.

If the app exits during initialization with `Operation not allowed without an active reactive context`, make sure the translation helper uses `shiny::isolate(selected_language())` (see `app/app.R`).

### Server troubleshooting checklist

- Confirm the app URL: `http://85.215.90.33:3838/axp-mvp-survey/` (not `/app/`).
- Confirm SockJS: `curl -i http://127.0.0.1:3838/axp-mvp-survey/__sockjs__/info` returns JSON.
- Check app log: `LOG=$(ls -t /var/log/shiny-server/app-shiny-*.log | head -1); sudo tail -n 200 "$LOG"`.
- If you see `Operation not allowed without an active reactive context`, patch `t()` to use `shiny::isolate(selected_language())`.
- If the browser shows “application unexpectedly exited”, inspect the app log and the Shiny Server log (`/var/log/shiny-server.log`).

## Deploy steps (operator checklist)

For the **full deployment guide** including database setup, backups, and cron jobs, see:
**[docs/DEPLOYMENT_VSERVER_DB.md](docs/DEPLOYMENT_VSERVER_DB.md)**

### Quick deployment (code updates only)

When deploying code updates to the vServer (database already running):

```bash
# 1. SSH into the server
ssh root@85.215.90.33

# 2. Pull latest code
cd /srv/shiny-server/axp-mvp-survey
git fetch origin
git pull --ff-only origin main

# 3. Restore R dependencies (fix renv drift)
sudo -u shiny Rscript -e "renv::restore()"

# 4. If systemfonts or uuid missing/outdated:
sudo -u shiny Rscript -e "renv::install('systemfonts')"
sudo -u shiny Rscript -e "renv::install('uuid')"

# 5. Restart Shiny Server
systemctl restart shiny-server

# 6. Verify
systemctl status shiny-server
curl -s http://localhost:3838/axp-mvp-survey/app/ | head -20
```

### Initial database setup (one-time)

```bash
# 1. Start MariaDB container
cd /srv/shiny-server/axp-mvp-survey/ops/mariadb
cp .env.example .env
nano .env  # Set MARIADB_PASSWORD and MARIADB_ROOT_PASSWORD
chmod 600 .env
docker compose up -d

# 2. Configure Shiny environment
cd /srv/shiny-server/axp-mvp-survey/app
cp .Renviron.example .Renviron
nano .Renviron  # Set DB_PASSWORD (same as MARIADB_PASSWORD)
chmod 600 .Renviron
chown shiny:shiny .Renviron

# 3. Initialize database schema
cd /srv/shiny-server/axp-mvp-survey
sudo -u shiny Rscript scripts/init_mariadb.R

# 4. Restart Shiny Server
systemctl restart shiny-server
```

### renv drift (known issues on server)

As of 2026-02-02, the server has:
- **Missing:** `systemfonts`
- **Out-of-sync:** `uuid` (lockfile vs library)

Resolution:
```r
# In R console (as shiny user):
renv::restore()
renv::install("systemfonts")
# If you want to update lockfile to match current library:
# renv::snapshot()  # Only if intentional
```

## Scoring and norms

- Define scales in `docs/scales.csv` (currently mapped to all 11D-ASC items).
- Recompute norms with:

```r
source("scripts/recompute_norms.R")
```

## Public export and OSF

- Export de-identified bundles with:

```r
source("scripts/export_public.R")
```

- `scripts/osf_upload.R` is a placeholder and uses `OSF_TOKEN` when configured.
- Exports exclude free-text by default and coarsen timestamps to dates.

## renv

Initialize renv from the repo root:

```r
renv::init()
```

Dependencies used:
- shiny
- vendored UI components in `R/quetzio/`
- httr
- jsonlite
- DBI
- RMariaDB (primary database driver)
- RPostgres (legacy, optional)
- uuid (for session ID generation)
- digest (for anonymization hashes)
- readr
- dplyr
- tidyr
- ggplot2
- googlesheets4 (optional, for API-based questionnaire loading)

### Adding RMariaDB to renv

If RMariaDB is not yet in the lockfile:

```r
# Install the package
renv::install("RMariaDB")

# Update lockfile
renv::snapshot()
```

## Notes

- The progress-step "reward" indicator uses a flipbook sprite sheet (`app/www/circleshepherd4.png`) to animate through an 11x11 grid; the frame index advances in JS at a fixed FPS, with the active state tinted purple and a center dot.
- The radar plot will fall back to mock data if computed scores do not map to all 11 canonical scale labels. This is intentional for now while the full scale mapping is incomplete.
- The feedback page now explicitly states whether the radar plot uses real submitted scores or mock data (e.g., dev mode).
- Slider inputs use a readiness gate to avoid initial layout shifts; the UI keeps handles hidden until ionRangeSlider is fully initialized.
- Free-text responses are stored only in the raw database and excluded from public exports by default.
- IP addresses are not collected or stored.
- Do not commit `.env` files or tokens.
- `plot_scores_radar()` expects the 11-ASC canonical scale order; if your `scale_id` values differ, pass a named `scale_map` to map them to canonical labels.
- Background p6m tiling logic is adapted from https://github.com/taru-u/taru-u.github.io (apps/symmetry).
- The animated background lives in `app/www/p6m-bg.js` and supports a UI toggle ("Animated p6m waves").
- You can disable the background entirely or the animation via env vars: `P6M_ENABLED=false` and/or `P6M_ANIMATED=false`.
