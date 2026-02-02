# axp-mvp-survey

MVP Shiny survey pipeline with Google Sheets questionnaire definitions, PostgreSQL persistence, scoring, norms, and export tooling.

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

**Optional:** Enable dev mode for step jumping:
```r
Sys.setenv(DEV_MODE = "true")
shiny::runApp("app")
```

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

## Database and STRATO deploy notes

- Configure PostgreSQL credentials in the environment.
- `sql/001_init.sql` creates required tables.
- Deploy behind nginx with Shiny Server or ShinyProxy. Ensure HTTPS and set `APP_BASE_URL`.

### Current server deployment (STRATO)

- App path: `/srv/shiny-server/axp-mvp-survey/app`
- Service account JSON: `/srv/shiny-server/axp-mvp-survey/secret/axp-mvp-3ec693c04c81.json`
- App env: `/srv/shiny-server/axp-mvp-survey/app/.Renviron` (contains Google Sheets config)
- Shiny Server listens on `http://85.215.90.33:3838/axp-mvp-survey/app/`
- HTTPS is expected to be added via Traefik + DNS (e.g., `axp.circe-science.de`)

### Server sync (non-destructive)

Use the following command block to sync the STRATO server with `origin/main` without clobbering local modifications. It backs up server-only files, attempts a fast-forward pull (no merge), restores secrets/configs, fixes ownership/permissions, and restarts Shiny Server. The backup/restore steps ensure `.Renviron`, `.Rprofile`, and the service account JSON survive even if tracked files change. The `--ff-only` pull protects against accidental merges when the server has local commits.

```bash
cd /srv/shiny-server/axp-mvp-survey

# backup server-only files
backup_dir="/tmp/axp-server-only-$(date +%Y%m%d%H%M%S)"
mkdir -p "$backup_dir"
cp -a app/.Rprofile app/.Renviron secret/axp-mvp-3ec693c04c81.json "$backup_dir"/ 2>/dev/null || true

# sync without clobbering local changes
git fetch origin
git status --short
git pull --ff-only origin main

# restore server-only files (in case tracked files overwrote them)
cp -a "$backup_dir"/.Rprofile app/.Rprofile 2>/dev/null || true
cp -a "$backup_dir"/.Renviron app/.Renviron 2>/dev/null || true
mkdir -p secret
cp -a "$backup_dir"/axp-mvp-3ec693c04c81.json secret/axp-mvp-3ec693c04c81.json 2>/dev/null || true

# fix ownership/permissions
chown shiny:shiny app/.Rprofile app/.Renviron secret/axp-mvp-3ec693c04c81.json 2>/dev/null || true
chmod 644 app/.Rprofile 2>/dev/null || true
chmod 600 app/.Renviron secret/axp-mvp-3ec693c04c81.json 2>/dev/null || true

systemctl restart shiny-server
```

## Scoring and norms

- Define scales in `docs/scales.csv`.
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
- RPostgres
- digest
- readr
- dplyr
- tidyr
- ggplot2
- googlesheets4 (optional, for API-based questionnaire loading)

## Notes

- The progress-step "reward" indicator uses a flipbook sprite sheet (`app/www/circleshepherd4.png`) to animate through an 11x11 grid; the frame index advances in JS at a fixed FPS, with the active state tinted purple and a center dot.
- The radar plot will fall back to mock data if computed scores do not map to all 11 canonical scale labels. This is intentional for now while the full scale mapping is incomplete.
- Slider inputs use a readiness gate to avoid initial layout shifts; the UI keeps handles hidden until ionRangeSlider is fully initialized.
- Free-text responses are stored only in the raw database and excluded from public exports by default.
- IP addresses are not collected or stored.
- Do not commit `.env` files or tokens.
- `plot_scores_radar()` expects the 11-ASC canonical scale order; if your `scale_id` values differ, pass a named `scale_map` to map them to canonical labels.
- Background p6m tiling logic is adapted from https://github.com/taru-u/taru-u.github.io (apps/symmetry).
- The animated background lives in `app/www/p6m-bg.js` and supports a UI toggle ("Animated p6m waves").
- You can disable the background entirely or the animation via env vars: `P6M_ENABLED=false` and/or `P6M_ANIMATED=false`.
