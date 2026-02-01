# Development Guide

This document is a practical reference for extending the AXP MVP survey. It focuses on where to make changes, how data moves through the app, and common extension points.

## Project layout

```
app/                 Shiny UI + server (single-file app.R)
app/www/             Static assets (images, JS background, vendor scripts)
R/                   R modules (config, questionnaire loader, scoring, plots)
docs/                Questionnaire schema + sample CSV + scale definitions
scripts/             Batch scripts for norms/export
sql/                 Database schema
config/.env.example  Env var template
```

## High-level flow

1) `app/app.R` loads config and source files from `R/`.
2) Questionnaire is loaded from Google Sheets or CSV.
3) UI is rendered step-by-step (`current_step` in server).
4) Answers are stored in memory and validated on submission.
5) If DB configured, responses + scores are persisted.
6) Feedback page renders a radar chart using computed scores.

## Architecture diagram (text-based)

```
Browser (Shiny client)
  └─ app/app.R (UI + server)
      ├─ R/config.R  (env config)
      ├─ R/questionnaire_loader.R (CSV/Sheets)
      ├─ R/quetzio/vendor_ui.R (dynamic UI)
      ├─ R/scoring.R (score computation)
      ├─ R/plots.R (radar plot)
      ├─ R/db.R (persistence)
      └─ sql/001_init.sql (schema)
```

## Key runtime state

- `current_step()` controls which page is visible.
- `questionnaire_df()` holds the loaded questionnaire data.
- `question_type_map` tracks item_id -> input type.
- `selected_drug`, `selected_dose` keep context for header text.
- `latest_scores()` stores the most recent computed scores.

## UI structure (app/app.R)

- `ui` is a `fluidPage` with a top shell and dynamic `uiOutput("page_ui")`.
- The progress indicator is rendered by `output$progress_steps`.
- Each step is a block in `output$page_ui`.
- `output$page_scroll_js` injects a small script that scrolls to top after step changes.

### Step numbering (current)

1. Intro
2. Consent
3. Visualize experience
4. Questionnaire page 1 (q0)
5. Questionnaire page 2 (q1)
6. Context page
7. Transition card
8. Slider group 1
9. Slider group 2
10. Slider group 3
11. Slider group 4
12. Free-text page
13. Experience tracer
14. Reward (final reveal)
15. Results/feedback

## Questionnaire schema and rendering

The app builds UI from `docs/sample_questionnaire.csv` or Google Sheets.

- Schema: `docs/questionnaire_schema.md`
- Renderer: `R/quetzio/vendor_ui.R`

If you add a new input type, you must update **both**:
1) `R/quetzio/vendor_ui.R` (add UI generation logic)
2) Validation / submission handling in `app/app.R`

### Required answers

The server validates required items on submit:
- `sliderInput` uses a `__touched` flag.
- `experience_tracer` requires a minimum point count.
- All other required fields must be non-empty.

## Adding or changing steps

1) Update `output$page_ui` with a new step block.
2) Update the `observeEvent(input$next_step)` logic to advance.
3) Update `progress_end_step` if the progress bar range changes.
4) Update the feedback step if needed (step 15 currently).

### Reward progress indicator

- The final progress step renders as a flipbook sprite indicator.
- Sprite sheet: `app/www/circleshepherd4.png` (11x11 grid).
- The animation runs via a small JS loop in `app/app.R` that advances a frame index at 60 fps and updates `--frame-x` / `--frame-y`.
- Active/complete state tints the sprite purple and adds a center dot.

## Scroll-to-top behavior

To ensure the new step starts at the top:
- The app injects `output$page_scroll_js` after `page_ui`.
- The script calls `window.__axpScrollTop()` multiple times after render.
- `window.__axpScrollTop` is defined in the head script and uses:
  - Anchor jump
  - `window.scrollTo(0, 0)`
  - document `scrollTop` resets

If scroll fails in a specific browser, confirm the actual scroll container is the document root (not a nested container).

## Dev mode

Enable dev mode to jump between steps:
- Env var: `DEV_MODE=true`
- The progress steps become clickable buttons.
- No validation is required between steps in dev mode.

The badge appears in the top-right to confirm dev mode is active.

## Config and env vars

See `config/.env.example` and `R/config.R`.

Common ones:
- `GOOGLE_SHEET_CSV_URL`
- `GOOGLE_SHEET_ID`
- `GOOGLE_SHEET_SHEETNAME`
- `GOOGLE_SHEET_AUTH_JSON`
- `GOOGLE_SHEET_USE_OAUTH`
- `STRATO_PG_*` (DB)
- `P6M_ENABLED`, `P6M_ANIMATED`
- `DEV_MODE`

## Data persistence

DB logic is in:
- `R/db.R`
- `sql/001_init.sql`

Tables:
- `submissions`
- `responses_numeric`
- `responses_text`
- `scores`

## Scoring and feedback

Scoring:
- `R/scoring.R` computes per-scale scores from numeric items.
- `docs/scales.csv` defines scale mapping.

Feedback UI:
- `output$radar_plot` (plot in `R/plots.R`)

If you change scale ids or add scales:
1) Update `docs/scales.csv`.
2) Adjust scoring map if needed.
3) Update plot expectations (labels/ordering).

## Assets and styling

Static assets:
- `app/www/` (images, `p6m-bg.js`, vendor scripts)

Main styles live in `app/app.R` in the `tags$style` block.

Keep UI changes centralized:
- Prefer updating styles in the inline CSS block.
- Avoid sprinkling style tags in multiple files.

## Common extension patterns

### Add a new questionnaire page
1) Add new rows to the questionnaire CSV / sheet.
2) Add a new step block in `output$page_ui`.
3) If it’s a new input type, update the vendor UI generator.

### Add a new derived score
1) Update `docs/scales.csv`.
2) Update `R/scoring.R` if the scoring logic changes.
3) Update the feedback plot as needed.

### Add a new export field
1) Update `scripts/export_public.R`.
2) Adjust schema changes if required.

## Troubleshooting

- If the boot overlay never clears: verify websocket connectivity and check console errors.
- If questionnaire fails to load: confirm env vars, access permissions, and CSV tab name.
- If sliders appear but don’t validate: confirm `__touched` logic in `R/quetzio/vendor_ui.R`.

## Feature checklist (template)

Use this when adding new functionality:

- [ ] Update questionnaire schema/CSV if needed.
- [ ] Add/adjust UI in `app/app.R`.
- [ ] Update server logic (validation, state, persistence).
- [ ] Update scoring or plots if the feature affects outputs.
- [ ] Update docs: `README.md` and/or `docs/DEVELOPMENT.md`.
- [ ] Test: step navigation, required fields, DB write (if enabled).

## Developer FAQ

**Q: How do I skip steps during dev?**  
Enable `DEV_MODE=true` and click the progress steps.

**Q: Why do required sliders sometimes fail validation?**  
Sliders set a `__touched` flag on change. If a slider is required and never moved, validation fails even if a default value is visible.

**Q: Where is the questionnaire defined?**  
`docs/sample_questionnaire.csv` (local) or Google Sheets when configured.

**Q: How do I add a new input type?**  
Add UI generation in `R/quetzio/vendor_ui.R` and update validation/submission logic in `app/app.R`.

**Q: What controls the progress bar?**  
`progress_start_step`, `progress_end_step`, and `current_step()` in `app/app.R`.

**Q: Why doesn’t the boot screen disappear?**  
The boot overlay clears on `shiny:connected`. Check websocket connection and console errors.
