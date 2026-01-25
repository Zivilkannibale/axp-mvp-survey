# axp-mvp-survey

MVP Shiny survey pipeline with Google Sheets questionnaire definitions, PostgreSQL persistence, scoring, norms, and export tooling.

## Quick start

1) Install R and required packages.
2) Copy `config/.env.example` to your environment (do not commit secrets).
3) Run the app:

```r
shiny::runApp("app")
```

The app uses `docs/sample_questionnaire.csv` if `GOOGLE_SHEET_CSV_URL` is not set or fails.

## Environment variables

See `config/.env.example` for required variables. Secrets must be stored in the environment.

## Questionnaire in Google Sheets

- Option A (no auth): publish your sheet as CSV and set `GOOGLE_SHEET_CSV_URL`.
- Option B (API): set `GOOGLE_SHEET_ID` and `GOOGLE_SHEET_SHEETNAME`, then configure auth via
  `GOOGLE_SHEET_AUTH_JSON` (service account) or `GOOGLE_SHEET_USE_OAUTH=true` for cached OAuth.
- The UI includes a reload button and optional sheet-tab override; page refresh also reloads the questionnaire.
- API loading uses `googlesheets4` and is informed by shiny.quetzio (reference only).
- If both are set, API loading is attempted first, then CSV, then the local sample.
- For non-interactive runs, set `GARGLE_OAUTH_CACHE` to the folder holding the cached token.
- Required columns are listed in `docs/questionnaire_schema.md`.
- Versioning is tracked via `instrument_id`, `instrument_version`, `language`, and `definition_hash`.
- Optional UI columns include `width`, `placeholder`, `slider_left_label`, `slider_right_label`, and `slider_ticks`.

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

The questionnaire supports a custom `sliderInput` type. Required sliders must be touched; the UI sets a `__touched` flag when the slider moves. The UI rendering is vendored from shiny.quetzio (see `R/quetzio/NOTICE.txt`).

## Database and STRATO deploy notes

- Configure PostgreSQL credentials in the environment.
- `sql/001_init.sql` creates required tables.
- Deploy behind nginx with Shiny Server or ShinyProxy. Ensure HTTPS and set `APP_BASE_URL`.

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
- vendored shiny.quetzio UI components
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

- Free-text responses are stored only in the raw database and excluded from public exports by default.
- IP addresses are not collected or stored.
- Do not commit `.env` files or tokens.
- `plot_scores_radar()` expects the 11-ASC canonical scale order; if your `scale_id` values differ, pass a named `scale_map` to map them to canonical labels.
