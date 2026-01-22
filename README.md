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

- Publish your sheet as CSV and set `GOOGLE_SHEET_CSV_URL`.
- Required columns are listed in `docs/questionnaire_schema.md`.
- Versioning is tracked via `instrument_id`, `instrument_version`, `language`, and `definition_hash`.

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
- fmsb

## Notes

- Free-text responses are stored only in the raw database and excluded from public exports by default.
- IP addresses are not collected or stored.
- Do not commit `.env` files or tokens.
