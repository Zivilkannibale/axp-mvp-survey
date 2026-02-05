# Contributing to AXP MVP Survey

This guide helps new developers get up to speed quickly.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd axp-mvp-survey

# 2. Open in RStudio or VS Code with R extension

# 3. Restore dependencies (from repo root)
Rscript -e "renv::restore()"

# 4. Run the app locally
Rscript -e "shiny::runApp('app')"
```

The app will use `docs/sample_questionnaire.csv` by default — no Google Sheets or database config needed for local development.

## Project Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        Browser (Shiny)                         │
└─────────────────────────────┬──────────────────────────────────┘
                              │
┌─────────────────────────────▼──────────────────────────────────┐
│                      app/app.R                                  │
│  • UI definition (fluidPage)                                   │
│  • Server logic (step navigation, validation)                  │
│  • CSS (inline <style> block)                                  │
│  • JS (inline <script> for boot, scroll, transitions)          │
└───────┬───────────┬───────────┬───────────┬───────────┬────────┘
        │           │           │           │           │
    ┌───▼───┐   ┌───▼───┐   ┌───▼───┐   ┌───▼───┐   ┌───▼───┐
    │config │   │loader │   │vendor │   │scoring│   │ plots │
    │  .R   │   │  .R   │   │ ui.R  │   │  .R   │   │  .R   │
    └───────┘   └───────┘   └───────┘   └───────┘   └───────┘
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
    Env vars    Google      Dynamic     Scale      Radar
    & secrets   Sheets/     inputs      compute    chart
                CSV
```

## Key Files to Know

| File | Purpose |
|------|---------|
| `app/app.R` | Main Shiny app — UI, server, CSS, JS all in one file |
| `R/config.R` | Environment variable loading |
| `R/questionnaire_loader.R` | Load/validate questionnaire from CSV or Google Sheets |
| `R/quetzio/vendor_ui.R` | Dynamic UI generator for questionnaire items |
| `R/scoring.R` | Score computation from numeric responses |
| `R/plots.R` | Radar chart for feedback page |
| `R/db.R` | MariaDB persistence |
| `docs/sample_questionnaire.csv` | Local questionnaire for development |
| `docs/scales.csv` | Scale definitions for scoring |

## Development Workflow

### 1. Local Development (no external services)

Set `DEV_MODE=true` in your environment to enable step jumping via progress bar clicks:

```r
# In R console before running:
Sys.setenv(DEV_MODE = "true")
shiny::runApp("app")
```

### 2. Adding a New Input Type

1. Add UI generation in `R/quetzio/vendor_ui.R` → `quetzio_generate_ui()` switch
2. Add validation logic in `app/app.R` → `observeEvent(input$next_step)`
3. Add data extraction in submission handler if needed
4. Update `docs/questionnaire_schema.md` with new columns

### 3. Modifying Styles

All CSS lives in the inline `tags$style(HTML(...))` block in `app/app.R` (around lines 100–800). Keep styles centralized here rather than scattering across files.

### 4. Testing Questionnaire Changes

1. Edit `docs/sample_questionnaire.csv`
2. Restart the Shiny app (or click "Reload" in the intro panel)
3. Walk through the survey to verify

## UI/UX Principles

### Slider Initialization
Sliders use a **readiness gate** to prevent layout shifts:
- Handle is hidden until `ionRangeSlider` initializes
- `is-ready` class reveals the slider after position is calculated
- `is-untouched` / `is-touched` classes track user interaction

### Transitions
- Step changes trigger `is-transitioning` class on `.app-shell`
- A brief busy overlay appears during server round-trips
- Scroll-to-top fires after each step change

### Mobile / Touch
- Touch targets are 44px+ for accessibility
- Sliders work via touch events (ionRangeSlider handles this)
- Experience tracer uses `touch-action: none` for drawing

## Browser Compatibility

Tested on:
- Chrome 90+ (Windows, macOS, Android)
- Firefox 88+
- Safari 14+ (macOS, iOS)
- Edge 90+

Key compatibility notes:
- CSS `:has()` selector used — works in all modern browsers
- `requestAnimationFrame` used for animations — universal support
- `MutationObserver` for DOM watching — universal support
- Touch events for experience tracer — works on all mobile browsers

## Environment Variables

See `config/.env.example` for the full list. For local dev, only optional vars:

| Variable | Purpose | Required? |
|----------|---------|-----------|
| `DEV_MODE` | Enable step jumping | No (default: false) |
| `P6M_ENABLED` | Animated tiling background | No (default: false) |
| `GOOGLE_SHEET_*` | Google Sheets integration | No (uses local CSV) |
| `DB_*` | MariaDB persistence (primary) | No (skips DB writes) |
| `OSF_TOKEN`, `OSF_PROJECT_ID` | OSF export uploads | No (manual upload) |

## Common Issues

### Sliders not validating
- Check that `__touched` flag is being set
- Verify slider IDs match between questionnaire and validation logic

### Questionnaire not loading
- Check env vars and sheet permissions
- Look at R console for error messages
- Verify CSV column names match schema

### Boot overlay stuck
- Check browser console for JS errors
- Verify Shiny websocket connected
- Check for CORS issues if running behind proxy

## Code Style

- R: Follow tidyverse style guide
- JS: Vanilla JS, no build step, ES5-compatible patterns
- CSS: CSS custom properties for theming, BEM-ish class naming

## Questions?

Check `docs/DEVELOPMENT.md` for more architecture details, or open an issue.
