resolve_root_dir <- function() {
  wd <- getwd()
  if (basename(wd) == "app") {
    normalizePath(file.path(wd, ".."))
  } else {
    wd
  }
}

root_dir <- resolve_root_dir()

source(file.path(root_dir, "R/config.R"))
source(file.path(root_dir, "R/questionnaire_loader.R"))
source(file.path(root_dir, "R/db.R"))
source(file.path(root_dir, "R/scoring.R"))
source(file.path(root_dir, "R/plots.R"))
source(file.path(root_dir, "R/experience_tracer.R"))
source(file.path(root_dir, "R/quetzio/vendor_ui.R"))

suppressPackageStartupMessages({
  library(shiny)
})

options(shiny.useragg = TRUE)

if (requireNamespace("systemfonts", quietly = TRUE)) {
  try({
    nunito_variable <- file.path(root_dir, "app", "www", "fonts", "Nunito-VariableFont_wght.ttf")
    press_start <- file.path(root_dir, "app", "www", "fonts", "PressStart2P-Regular.ttf")
    if (file.exists(nunito_variable)) {
      systemfonts::register_font("Nunito", regular = nunito_variable, bold = nunito_variable)
    }
    if (file.exists(press_start)) {
      systemfonts::register_font("Press Start 2P", regular = press_start)
    }
  }, silent = TRUE)
}

load_questionnaire <- function(sheet_name_override = NULL) {
  cfg <- get_config(required = FALSE)
  df <- NULL
  sheet_name <- cfg$GOOGLE_SHEET_SHEETNAME
  if (!is.null(sheet_name_override) && sheet_name_override != "") {
    sheet_name <- sheet_name_override
  }
  if (cfg$GOOGLE_SHEET_ID != "" && sheet_name != "") {
    df <- try(load_questionnaire_from_gsheet(cfg$GOOGLE_SHEET_ID, sheet_name, cfg), silent = TRUE)
    if (inherits(df, "try-error")) {
      message("Google Sheets API load failed; falling back to CSV/local sample.")
      df <- NULL
    }
  }

  if (cfg$GOOGLE_SHEET_CSV_URL != "") {
    df <- try(load_questionnaire_from_sheet(cfg$GOOGLE_SHEET_CSV_URL), silent = TRUE)
    if (inherits(df, "try-error")) {
      message("Google Sheets CSV load failed; falling back to local sample.")
      df <- NULL
    }
  }

  if (is.null(df)) {
    df <- load_questionnaire_from_csv(file.path(root_dir, "docs/sample_questionnaire.csv"))
  }

  df
}

env_flag <- function(value, default = TRUE) {
  if (is.null(value) || value == "") return(default)
  tolower(value) %in% c("1", "true", "yes", "y", "on")
}

cfg_ui <- get_config(required = FALSE)
P6M_ENABLED <- env_flag(cfg_ui$P6M_ENABLED, FALSE)
P6M_ANIMATED_DEFAULT <- env_flag(cfg_ui$P6M_ANIMATED, FALSE)
DEV_MODE <- env_flag(cfg_ui$DEV_MODE, FALSE)

ui <- fluidPage(
  tags$head(
    tags$link(rel = "preload", href = "fonts/PressStart2P-Regular.ttf", as = "font", type = "font/ttf"),
    tags$link(rel = "preload", href = "fonts/Nunito-VariableFont_wght.ttf", as = "font", type = "font/ttf"),
    tags$link(rel = "preload", href = "circe-logo.png", as = "image"),
    if (!P6M_ENABLED) tags$link(rel = "preload", href = "circe-bg.png", as = "image"),
    if (P6M_ENABLED) tags$link(rel = "preload", href = "p6m-bg.js", as = "script"),
    if (P6M_ENABLED) tags$script(src = "p6m-bg.js", defer = "defer"),
    tags$script(src = "signature_pad.js", defer = "defer"),
    tags$script(src = "experience_tracer.js", defer = "defer"),
    tags$script(HTML("
      $(function(){
        function ensureDrugPlaceholder(){
          var $el = $('#q0');
          if (!$el.length) return;
          var $wrap = $el.closest('.select-placeholder-wrap');
          if (!$wrap.length) {
            $el.wrap('<div class=\"select-placeholder-wrap\"></div>');
            $wrap = $el.closest('.select-placeholder-wrap');
            var placeholder = $el.find('option[value=\"\"]').first().text();
            $wrap.append('<span class=\"select-placeholder-text\"></span>');
            $wrap.find('.select-placeholder-text').text(placeholder || 'Please choose a drug to continue');
          }
          if (!$el.val()) {
            $el.addClass('is-placeholder');
            $wrap.removeClass('has-value');
          } else {
            $el.removeClass('is-placeholder');
            $wrap.addClass('has-value');
          }
        }
        $(document).on('change', '#q0', ensureDrugPlaceholder);
        setTimeout(ensureDrugPlaceholder, 0);
      });
    ")),
    tags$script(HTML("
      Shiny.addCustomMessageHandler('clearRadioSelection', function(message){
        if (!message || !message.id) return;
        var $inputs = $('input[name=\"' + message.id + '\"]');
        if (!$inputs.length) return;
        $inputs.prop('checked', false);
        Shiny.setInputValue(message.id, '', {priority: 'event'});
      });
    ")),
    tags$style(HTML("
      @font-face {
        font-family: 'Press Start 2P';
        font-style: normal;
        font-weight: 400;
        font-display: block;
        src: url('fonts/PressStart2P-Regular.ttf') format('truetype');
      }
      @font-face {
        font-family: 'Nunito';
        font-style: normal;
        font-weight: 200 1000;
        font-display: swap;
        src: url('fonts/Nunito-VariableFont_wght.ttf') format('truetype');
      }
      :root {
        --accent: #6b3df0;
        --accent-soft: #f0ecff;
        --text: #262632;
        --muted: #7b7f8c;
        --border: #e6e7eb;
        --bg: #f9f9fb;
        --card: #ffffff;
        --radius: 20px;
        --font-body: 'Nunito', 'Segoe UI', sans-serif;
        --font-head: 'Nunito', 'Segoe UI', sans-serif;
        --slider-accent: #6b3df0;
        --slider-track: #e6e3f4;
      }
      body {
        background-color: var(--bg);
        color: var(--text);
        font-family: var(--font-body);
      }
      h1, h2, h3 { font-family: var(--font-head); letter-spacing: -0.01em; }
      #p6m-layer { position: fixed; inset: 0; z-index: 0; pointer-events: none; }
      #p6m-layer canvas { width: 100%; height: 100%; display: block; }
      .app-shell { position: relative; z-index: 1; max-width: 720px; margin: 0 auto; padding: 28px 20px 48px; background: transparent; }
      .app-shell .irs,
      .app-shell .slider-labels,
      .app-shell #radar_plot,
      .app-shell .app-card,
      .app-shell .nav-actions {
        transition: opacity 450ms ease;
      }
      .app-shell.is-booting .irs,
      .app-shell.is-booting .slider-labels,
      .app-shell.is-booting #radar_plot,
      .app-shell.is-booting .app-card,
      .app-shell.is-booting .nav-actions {
        opacity: 0;
      }
      .app-shell.is-transitioning .irs,
      .app-shell.is-transitioning .slider-labels,
      .app-shell.is-transitioning #radar_plot,
      .app-shell.is-transitioning .app-card,
      .app-shell.is-transitioning .nav-actions {
        opacity: 0;
      }
      .app-logo { display: block; width: 120px; height: auto; margin: 0 0 12px; }
      .app-eyebrow { text-transform: uppercase; font-size: 16px; letter-spacing: 0.18em; color: #000000; font-weight: 700; margin: -4px 0 6px; }
      .app-title { font-size: 28px; margin: 8px 0 12px; }
      .app-top {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 12px;
      }
      .app-links {
        display: flex;
        gap: 6px;
        align-items: flex-start;
        margin-top: 12px;
        flex-direction: column;
      }
      .app-link {
        font-size: 19px;
        letter-spacing: 0.14em;
        text-transform: uppercase;
        font-weight: 600;
        color: #6b3df0;
        text-decoration: none;
      }
      .app-card { background: var(--card); border: 1px solid var(--border); border-radius: var(--radius); padding: 22px; margin-bottom: 18px; box-shadow: 0 8px 24px rgba(25, 22, 70, 0.06); }
      .app-card h3 { margin-top: 0; font-size: 18px; }
      .muted { color: var(--muted); font-size: 12px; margin-top: 6px; }
      .error-text { color: #b00020; font-weight: 600; margin-top: 10px; }
      .mandatory_star { color: var(--accent); margin-left: 4px; }
      .quetzio-question { padding: 14px 0 18px; border-bottom: 1px solid var(--border); }
      .quetzio-question:last-child { border-bottom: none; }
      .quetzio-question label { font-size: 18px; font-weight: 500; color: var(--text); }
      .form-control, .selectize-input { border-radius: 999px; border: 1px solid var(--border); box-shadow: none; }
      #q0.is-placeholder { color: #8c90a4; }
      #q0 option[value=\"\"] { color: #8c90a4; display: none; }
      .select-placeholder-wrap { position: relative; }
      .select-placeholder-text {
        position: absolute;
        left: 16px;
        top: 50%;
        transform: translateY(-50%);
        color: #8c90a4;
        pointer-events: none;
        font-size: 16px;
      }
      .select-placeholder-wrap.has-value .select-placeholder-text { display: none; }
      .form-control:focus, .selectize-input:focus, .selectize-input.focus, .selectize-control .selectize-input.focus {
        border-color: var(--accent);
        box-shadow: 0 0 0 3px rgba(107, 61, 240, 0.18);
        outline: none;
      }
      .selectize-control.single .selectize-input,
      .selectize-control.single .selectize-input.input-active {
        border-color: var(--border);
      }
      .selectize-control.single .selectize-input.focus {
        border-color: var(--accent);
        box-shadow: 0 0 0 3px rgba(107, 61, 240, 0.18);
      }
      .selectize-control.single .selectize-input input:focus {
        outline: none;
        box-shadow: none;
      }
      textarea.form-control { border-radius: 16px; }
      .radio { margin: 10px 0; }
      .radio input { display: none; }
      .radio label { display: block; padding: 12px 16px; border: 1px solid var(--border); border-radius: 999px; color: var(--text); background: #fff; font-weight: 500; }
      .radio label:has(input:checked) { border-color: var(--accent); color: var(--accent); background: var(--accent-soft); }
      #submit { border-radius: 999px; border: 1px solid var(--accent); color: var(--accent); background: #fff; padding: 10px 22px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; }
      #submit:hover { background: var(--accent-soft); }
      .slider-labels { display: flex; justify-content: space-between; font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); margin-top: 6px; }
      .shiny-input-container { width: 100%; max-width: 100%; }
      .quetzio-question.type-sliderInput .shiny-input-container { min-height: 56px; overflow: hidden; position: relative; }
      .quetzio-question.type-sliderInput input[type='range'] { height: 56px; opacity: 0; }
      .irs--shiny .irs-line, .irs--shiny .irs-line::before, .irs--shiny .irs-bar, .irs--shiny .irs-bar::before, .irs--shiny .irs-handle {
        cursor: url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'%3E%3Cpath fill='%236b3df0' d='M10 2V9.5H9V3C9 2.45 8.55 2 8 2S7 2.45 7 3V14.35L4.5 11.53C4.06 11.04 3.32 10.97 2.79 11.35C2.21 11.77 2.07 12.58 2.47 13.17L5.73 17.96C6.85 19.86 8.9 21 11.11 21H13C16.31 21 19 18.31 19 15V6C19 5.45 18.55 5 18 5S17 5.45 17 6V9.5H16V4C16 3.45 15.55 3 15 3S14 3.45 14 4V9.5H13V3C13 2.45 12.55 2 12 2S11 2.45 11 3V9.5H10V2Z'/%3E%3C/svg%3E\") 12 0, pointer !important;
        user-select: none;
        touch-action: pan-y;
      }
      .irs--shiny { height: 56px; clip-path: inset(0); opacity: 1; transition: opacity 325ms ease; }
      .irs--shiny.is-untouched .irs-bar,
      .irs--shiny.is-untouched .irs-bar-edge { opacity: 0.2; }
      .irs--shiny.is-untouched .irs-handle,
      .irs--shiny.is-untouched .irs-slider { border-color: rgba(107, 61, 240, 0.35) !important; }
      .irs--shiny .irs-line { height: 6px; top: 28px; background: var(--slider-track) !important; border: none !important; border-radius: 999px; }
      .irs--shiny .irs-bar { height: 6px; top: 28px; background: var(--slider-accent) !important; border: none !important; border-radius: 999px; }
      .irs--shiny .irs-bar-edge { height: 6px; top: 28px; background: var(--slider-accent) !important; border: none !important; border-radius: 999px; }
      .irs--shiny .irs-handle { top: 20px; width: 22px; height: 22px; border: 2px solid var(--slider-accent) !important; background: #fff !important; box-shadow: 0 2px 6px rgba(30, 20, 70, 0.15); border-radius: 999px; }
      .irs--shiny .irs-slider { border: 2px solid var(--slider-accent) !important; background: #fff !important; }
      .irs--shiny .irs-single { display: none; }
      .irs--shiny .irs-min, .irs--shiny .irs-max { display: none; }
      .irs--shiny .irs-grid, .irs--shiny .irs-grid-text { display: none; }
      .nav-actions { display: flex; gap: 12px; margin-top: 18px; }
      .nav-actions .btn {
        border-radius: 999px;
        padding: 8px 20px;
        font-weight: 700;
        border: 1px solid rgba(107, 61, 240, 0.6);
        color: #6b3df0;
        background: #fff;
        text-transform: uppercase;
        letter-spacing: 0.08em;
      }
      .nav-actions .btn:hover { background: var(--accent-soft); }
      .feedback-note--compact {
        font-size: 0.98rem;
        line-height: 1.5;
        color: #2f3142;
      }
      #next_step:disabled,
      #next_step.is-disabled {
        opacity: 0.45;
        pointer-events: none;
        background: #fff;
      }
      .progress-steps {
        display: grid;
        grid-auto-flow: column;
        grid-auto-columns: 1fr;
        gap: 8px;
        margin: 4px 0 14px;
        align-items: center;
      }
      .progress-step {
        width: 100%;
        display: block;
        height: 6px;
        border-radius: 999px;
        background: rgba(107, 61, 240, 0.18);
        position: relative;
        overflow: hidden;
        border: 0;
        padding: 0;
        appearance: none;
      }
      .progress-step.is-reward {
        --frame: 24px;
        --frames: 11;
        width: var(--frame);
        height: var(--frame);
        justify-self: center;
        border-radius: 0;
        background-color: transparent;
        background-image: url('circleshepherd4.png');
        background-size: calc(var(--frame) * var(--frames)) calc(var(--frame) * var(--frames));
        background-repeat: no-repeat;
        background-position: var(--frame-x, 0px) var(--frame-y, 0px);
        mask-image: none;
        -webkit-mask-image: none;
      }
      @supports ((-webkit-mask-image: url(\"\")) or (mask-image: url(\"\"))) {
        .progress-step.is-reward {
          background-color: rgba(235, 242, 255, 0.85);
          background-image: none;
          mask-image: url('circleshepherd4.png');
          -webkit-mask-image: url('circleshepherd4.png');
          mask-size: calc(var(--frame) * var(--frames)) calc(var(--frame) * var(--frames));
          -webkit-mask-size: calc(var(--frame) * var(--frames)) calc(var(--frame) * var(--frames));
          mask-repeat: no-repeat;
          -webkit-mask-repeat: no-repeat;
          mask-position: var(--frame-x, 0px) var(--frame-y, 0px);
          -webkit-mask-position: var(--frame-x, 0px) var(--frame-y, 0px);
        }
      }
      .progress-step.is-reward::after {
        content: '';
        position: absolute;
        inset: 50%;
        width: 4px;
        height: 4px;
        border-radius: 999px;
        background: rgba(107, 61, 240, 0.0);
        transform: translate(-50%, -50%);
      }
      .progress-step.is-reward.is-active,
      .progress-step.is-reward.is-complete {
        background-color: transparent;
      }
      @supports ((-webkit-mask-image: url(\"\")) or (mask-image: url(\"\"))) {
        .progress-step.is-reward.is-active,
        .progress-step.is-reward.is-complete {
          background-color: rgba(107, 61, 240, 0.9);
        }
      }
      .progress-step.is-clickable { cursor: pointer; }
      .progress-step.is-active::after,
      .progress-step.is-complete::after {
        content: \"\";
        position: absolute;
        inset: 0;
        background: var(--accent);
      }
      .progress-step.is-reward.is-active::after,
      .progress-step.is-reward.is-complete::after {
        content: '';
        position: absolute;
        inset: 50%;
        width: 4px;
        height: 4px;
        border-radius: 999px;
        background: rgba(107, 61, 240, 0.95);
        transform: translate(-50%, -50%);
      }
      .intro-panel {
        display: grid;
        grid-template-rows: auto 1fr auto;
        gap: 28px;
        min-height: 62vh;
        padding: 8px 6px 6px;
      }
      .intro-center {
        display: grid;
        gap: 14px;
        text-align: left;
        align-content: start;
      }
      .intro-title {
        font-family: var(--font-head);
        font-size: 34px;
        letter-spacing: 0.28em;
        font-weight: 700;
        text-transform: uppercase;
        color: rgba(40, 45, 60, 0.65);
      }
      .intro-body {
        max-width: 520px;
        margin: 0;
        color: var(--text);
        font-size: 13px;
      }
      .intro-body ul {
        text-align: left;
        margin: 12px 0 0;
        padding-left: 18px;
      }
      .consent-body {
        color: var(--text);
        font-size: 14px;
        line-height: 1.6;
        display: grid;
        gap: 14px;
      }
      .consent-checkbox {
        margin-top: 8px;
      }
      .consent-pill {
        border-radius: 999px;
        border: 1px solid rgba(107, 61, 240, 0.6);
        color: #6b3df0;
        background: #fff;
        padding: 10px 20px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        font-size: 14px;
        display: inline-flex;
        align-items: center;
        gap: 12px;
        cursor: pointer;
        user-select: none;
      }
      .consent-pill:has(input:checked) {
        background: rgba(107, 61, 240, 0.08);
      }
      .consent-pill input[type='checkbox'] {
        position: absolute;
        opacity: 0;
        width: 1px;
        height: 1px;
        margin: 0;
        pointer-events: none;
      }
      .consent-indicator {
        width: 18px;
        height: 18px;
        border: 2px solid rgba(107, 61, 240, 0.65);
        border-radius: 999px;
        display: grid;
        place-items: center;
        box-sizing: border-box;
        background: transparent;
      }
      .consent-indicator::after {
        content: '';
        width: 10px;
        height: 10px;
        transform: scale(0);
        transition: transform 120ms ease-in-out;
        background: #6b3df0;
        border-radius: 999px;
      }
      .consent-pill input[type='checkbox']:checked + .consent-indicator::after {
        transform: scale(1);
      }
      .prep-body {
        color: var(--text);
        font-size: 14px;
        line-height: 1.6;
        display: grid;
        gap: 12px;
      }
      .prep-eyebrow {
        font-size: 11px;
        letter-spacing: 0.2em;
        text-transform: uppercase;
        font-weight: 700;
        color: rgba(40, 45, 60, 0.55);
        min-height: 14px;
      }
      .experience-header {
        color: var(--accent);
        transition: opacity 210ms ease;
      }
      .experience-header.is-pulsing {
        opacity: 0;
      }
      .intro-start {
        border-radius: 999px;
        border: 1px solid rgba(107, 61, 240, 0.6);
        color: #6b3df0;
        background: #fff;
        padding: 10px 26px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }
      .intro-results {
        border-radius: 999px;
        border: 1px solid rgba(107, 61, 240, 0.35);
        background: #fff;
        color: #6b3df0;
        text-transform: uppercase;
        letter-spacing: 0.18em;
        font-size: 11px;
        font-weight: 700;
        position: relative;
        cursor: default;
        padding: 8px 18px;
      }
      .intro-results:hover::after {
        content: 'When implemented, this will lead you to a page where you can access all of your previous submissions.';
        position: absolute;
        left: 50%;
        transform: translate(-50%, -10px);
        bottom: 100%;
        width: 240px;
        background: rgba(24, 26, 34, 0.9);
        color: #fff;
        padding: 8px 10px;
        border-radius: 8px;
        font-size: 11px;
        letter-spacing: normal;
        text-transform: none;
        z-index: 3;
        text-align: center;
      }
      .reward-card {
        background: linear-gradient(135deg, #ffffff 0%, #f3f0ff 55%, #eaf2ff 100%);
        border: 1px solid rgba(107, 61, 240, 0.22);
        box-shadow: 0 10px 26px rgba(55, 30, 130, 0.12);
      }
      .reward-eyebrow {
        font-size: 12px;
        letter-spacing: 0.22em;
        text-transform: uppercase;
        font-weight: 700;
        color: rgba(107, 61, 240, 0.7);
        margin-bottom: 10px;
      }
      .reward-title {
        font-size: 22px;
        margin: 0 0 10px;
        color: #241b43;
      }
      .reward-body {
        color: #4b4863;
        font-size: 15px;
      }
      .intro-controls {
        display: flex;
        flex-direction: column;
        gap: 8px;
        margin-top: 8px;
        max-width: 520px;
      }
      .intro-controls .form-group {
        margin-bottom: 0;
      }
      .intro-reload {
        border-radius: 999px;
        border: 1px solid rgba(107, 61, 240, 0.6);
        color: #6b3df0;
        background: #fff;
        padding: 8px 20px;
        font-weight: 700;
        letter-spacing: 0.14em;
        text-transform: uppercase;
        font-size: 12px;
        align-self: flex-start;
      }
      .intro-reload:hover {
        background: rgba(107, 61, 240, 0.06);
      }
      .intro-status {
        font-size: 13px;
        color: var(--text);
        margin-top: 4px;
      }
      .submit-disabled {
        border-radius: 999px;
        border: 1px solid rgba(107, 61, 240, 0.35);
        background: #fff;
        color: #6b3df0;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        font-weight: 700;
        padding: 8px 20px;
        position: relative;
        cursor: not-allowed;
      }
      .submit-disabled:hover::after {
        content: 'Will be implemented to store data on the Strato server.';
        position: absolute;
        left: 50%;
        transform: translate(-50%, -10px);
        bottom: 100%;
        width: 220px;
        background: rgba(24, 26, 34, 0.9);
        color: #fff;
        padding: 8px 10px;
        border-radius: 8px;
        font-size: 11px;
        letter-spacing: normal;
        text-transform: none;
        z-index: 3;
        text-align: center;
      }
      /* Beta badge for experimental features */
      .beta-badge {
        display: inline-block;
        background: linear-gradient(135deg, #ff6b6b, #ffa502);
        color: #fff;
        font-size: 10px;
        font-weight: 700;
        letter-spacing: 0.1em;
        padding: 4px 10px;
        border-radius: 4px;
        margin-bottom: 12px;
      }
      .tracer-experimental {
        border: 2px dashed rgba(255, 107, 107, 0.4);
      }
      .tracer-intro {
        font-size: 14px;
        color: var(--muted);
        margin-bottom: 16px;
      }
      .btn-secondary {
        background: transparent !important;
        border: 1px solid rgba(107, 61, 240, 0.5) !important;
        color: #6b3df0 !important;
      }
      .btn-secondary:hover {
        background: rgba(107, 61, 240, 0.08) !important;
      }
      @media (max-width: 520px) {
        .intro-title { font-size: 26px; letter-spacing: 0.2em; }
        .intro-body { font-size: 12px; }
      }
      .boot-overlay, .busy-overlay {
        position: fixed;
        inset: 0;
        z-index: 9999;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #000000;
        color: #b892ff;
        font-family: 'Press Start 2P', 'Courier New', monospace;
        letter-spacing: 0.05em;
        transition: opacity 220ms ease, visibility 220ms ease;
      }
      .boot-overlay.hidden, .busy-overlay.hidden {
        opacity: 0;
        visibility: hidden;
      }
      .boot-terminal {
        width: min(620px, 94vw);
        border: 1px solid rgba(184, 146, 255, 0.55);
        border-radius: 16px;
        background: rgba(4, 6, 8, 0.85);
        padding: 18px 20px 16px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.45);
      }
      .boot-title { font-size: 10px; text-transform: uppercase; color: #9f73ff; }
      .boot-lines { display: none; }
      .boot-progress {
        height: 6px;
        border-radius: 999px;
        background: rgba(140, 96, 255, 0.22);
        overflow: hidden;
      }
      .boot-progress span {
        display: block;
        height: 100%;
        width: 10%;
        background: linear-gradient(90deg, #8f5bff, #d3b1ff);
        transition: width 240ms ease;
      }
      .boot-foot { margin-top: 12px; font-size: 10px; color: #9f73ff; }
      .boot-quip {
        font-size: 13px;
        line-height: 1.6;
        color: #c7a5ff;
        letter-spacing: 0.06em;
        font-weight: 600;
        margin-top: 14px;
        text-shadow: 0 0 8px rgba(155, 115, 255, 0.35);
      }
      .dev-badge {
        position: fixed;
        top: 14px;
        right: 16px;
        z-index: 10000;
        padding: 6px 10px;
        border-radius: 999px;
        background: rgba(20, 20, 28, 0.75);
        color: #fff;
        font-size: 10px;
        letter-spacing: 0.18em;
        text-transform: uppercase;
        font-weight: 700;
        border: 1px solid rgba(255, 255, 255, 0.25);
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.25);
        pointer-events: none;
      }
      .busy-overlay {
        background: rgba(12, 14, 20, 0.6);
        z-index: 9998;
      }
      .busy-pill {
        padding: 10px 16px;
        border-radius: 999px;
        border: 1px solid rgba(120, 140, 200, 0.5);
        background: rgba(8, 10, 16, 0.75);
        font-size: 12px;
        text-transform: uppercase;
        color: #a7b1e9;
      }
      .experience-tracer {
        display: grid;
        gap: 10px;
      }
      .experience-tracer-label {
        font-size: 18px;
        font-weight: 600;
      }
      .experience-tracer-instruction {
        color: var(--muted);
        font-size: 12px;
      }
      .experience-tracer-canvas-wrap {
        position: relative;
        border-radius: 14px;
        border: 1px solid var(--border);
        background: #fbfbff;
        overflow: hidden;
      }
      .experience-tracer-canvas {
        width: 100%;
        height: 100%;
        display: block;
        cursor: crosshair;
        touch-action: none;
        background-color: #f7f9ff;
        background-image:
          linear-gradient(to right, rgba(80, 90, 120, 0.18) 1px, transparent 1px),
          linear-gradient(to bottom, rgba(80, 90, 120, 0.18) 1px, transparent 1px);
        background-size: calc(100% / var(--tracer-cols)) calc(100% / var(--tracer-rows));
        background-position: 0 0;
        background-repeat: repeat;
      }
      .experience-tracer-top-label {
        position: absolute;
        top: 10px;
        right: 12px;
        font-size: 10px;
        font-weight: 700;
        color: rgba(40, 45, 60, 0.8);
        text-transform: uppercase;
        letter-spacing: 0.05em;
        pointer-events: none;
        z-index: 2;
      }
      .experience-tracer-ticks {
        position: absolute;
        inset: 0;
        padding: 12px 16px 14px 16px;
        box-sizing: border-box;
        pointer-events: none;
        z-index: 2;
      }
      .experience-tracer-ticks-x,
      .experience-tracer-ticks-y {
        position: absolute;
        left: 0;
        right: 0;
        bottom: 0;
      }
      .experience-tracer-ticks-y {
        top: 0;
        bottom: 0;
        left: 0;
        width: 100%;
      }
      .tick-label {
        position: absolute;
        font-size: 9px;
        color: rgba(40, 45, 60, 0.6);
        font-weight: 600;
        white-space: nowrap;
      }
      .tick-label-x {
        bottom: 0;
        transform: translate(-50%, 0);
      }
      .tick-label-y {
        left: 0;
        transform: translate(0, 50%);
      }
      .experience-tracer-ticks-x .tick-label-x:first-child {
        left: 0 !important;
        transform: translate(0, 0);
      }
      .experience-tracer-ticks-x .tick-label-x:last-child {
        left: auto !important;
        right: 0;
        transform: translate(0, 0);
      }
      .experience-tracer-ticks-y .tick-label-y:first-child {
        bottom: 0 !important;
        transform: translate(0, 0);
      }
      .experience-tracer-ticks-y .tick-label-y:last-child {
        bottom: auto !important;
        top: 0;
        transform: translate(0, 0);
      }
      @media (max-width: 520px) {
        .experience-tracer-top-label { font-size: 9px; }
        .tick-label { font-size: 8px; }
        .tick-label-x:nth-child(odd) { display: none; }
        .tick-label-y:nth-child(odd) { display: none; }
      }
      .experience-tracer-actions {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .experience-tracer-status {
        color: var(--muted);
        font-size: 12px;
      }
      .feedback-panel {
        overflow: hidden;
        transition: opacity 180ms ease, max-height 220ms ease;
        max-height: 1600px;
        opacity: 1;
      }
      .feedback-note {
        margin: 6px 0 12px;
        font-size: 13px;
        color: var(--muted);
        line-height: 1.5;
      }
      .feedback-panel.is-hidden {
        max-height: 0;
        opacity: 0;
        pointer-events: none;
        margin: 0;
      }
    "))
    ,
    tags$script(HTML({
      js <- "
      (function() {
        var boot = null;
        var busy = null;
        var bootHidden = false;
        var bootBar = null;
        var bootPct = null;
        var bootTimeout = null;
        var bootTarget = 5;
        var bootCurrent = 0;
        var bootTick = null;
        var p6mEnabled = P6M_ENABLED_PLACEHOLDER;
        var appShell = null;

        function hideBoot() {
          if (bootHidden) return;
          bootHidden = true;
          if (boot) boot.classList.add('hidden');
          if (appShell) {
            setTimeout(function() {
              appShell.classList.remove('is-booting');
            }, 120);
          }
        }

        function setBootProgress(pct) {
          bootTarget = Math.max(0, Math.min(100, pct || 0));
        }

        function bootLoop() {
          if (!bootBar || !bootPct || !boot) return;
          if (bootTarget < 25) {
            bootTarget = Math.min(25, bootTarget + 0.08);
          }
          var delta = bootTarget - bootCurrent;
          var step = Math.max(0.6, Math.abs(delta) * 0.08);
          if (Math.abs(delta) < 0.3) {
            bootCurrent = bootTarget;
          } else {
            bootCurrent += Math.sign(delta) * step;
          }
          var pct = Math.max(0, Math.min(100, bootCurrent));
          bootBar.style.width = pct + '%';
          bootPct.textContent = Math.round(pct) + '%';
          if (pct >= 100) {
            hideBoot();
            return;
          }
          bootTick = requestAnimationFrame(bootLoop);
        }

        var scrollAnchorToggle = 0;
        var pageUiObserver = null;
        function scrollToTopHard() {
          try {
            if (document.activeElement && typeof document.activeElement.blur === 'function') {
              document.activeElement.blur();
            }
          } catch (e) {}

          var anchorId = scrollAnchorToggle === 0 ? 'scroll-top-anchor-a' : 'scroll-top-anchor-b';
          scrollAnchorToggle = 1 - scrollAnchorToggle;
          var anchor = document.getElementById(anchorId);
          if (anchor && anchor.scrollIntoView) {
            anchor.scrollIntoView({ block: 'start', behavior: 'auto' });
          }

          var target = document.scrollingElement || document.documentElement || document.body;
          if (target) target.scrollTop = 0;
          if (document.documentElement) document.documentElement.scrollTop = 0;
          if (document.body) document.body.scrollTop = 0;
          window.scrollTo(0, 0);
          try {
            if (window.parent && window.parent !== window) {
              window.parent.scrollTo(0, 0);
              if (window.parent.document && window.parent.document.documentElement) {
                window.parent.document.documentElement.scrollTop = 0;
              }
              if (window.parent.document && window.parent.document.body) {
                window.parent.document.body.scrollTop = 0;
              }
            }
          } catch (e) {}

          if (location.hash !== '#' + anchorId) {
            location.hash = anchorId;
          }
          if (history && history.replaceState) {
            history.replaceState(null, '', location.pathname + location.search);
          }

        }

        function scrollToTopSmooth() {
          try {
            if (document.activeElement && typeof document.activeElement.blur === 'function') {
              document.activeElement.blur();
            }
          } catch (e) {}

          var start = null;
          var duration = 820;
          var startY = (document.scrollingElement || document.documentElement || document.body).scrollTop || 0;
          if (startY <= 0) return;
          function easeInOut(t) {
            return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
          }
          function step(ts) {
            if (!start) start = ts;
            var progress = Math.min(1, (ts - start) / duration);
            var eased = easeInOut(progress);
            var nextY = Math.round(startY * (1 - eased));
            try {
              if (document.scrollingElement) {
                document.scrollingElement.scrollTop = nextY;
              } else if (document.documentElement) {
                document.documentElement.scrollTop = nextY;
              } else if (document.body) {
                document.body.scrollTop = nextY;
              }
              window.scrollTo(0, nextY);
              if (window.parent && window.parent !== window) {
                window.parent.scrollTo(0, nextY);
              }
            } catch (e) {}
            if (progress < 1) {
              requestAnimationFrame(step);
            }
          }
          requestAnimationFrame(step);
        }
        window.__axpScrollTop = scrollToTopHard;

        function scheduleScrollTopHard() {
          scrollToTopHard();
          requestAnimationFrame(scrollToTopHard);
          setTimeout(scrollToTopHard, 50);
          setTimeout(scrollToTopHard, 200);
        }

        function installPageObserver() {
          if (pageUiObserver) return;
          var target = document.getElementById('page_ui');
          if (!target || !window.MutationObserver) return;
          var lastRun = 0;
          pageUiObserver = new MutationObserver(function(mutations) {
            var now = Date.now();
            if (now - lastRun < 80) return;
            lastRun = now;
            var shouldScroll = false;
            for (var i = 0; i < mutations.length; i += 1) {
              var mutation = mutations[i];
              if (mutation.type !== 'childList') continue;
              if ((mutation.addedNodes && mutation.addedNodes.length) || (mutation.removedNodes && mutation.removedNodes.length)) {
                shouldScroll = true;
                break;
              }
            }
            if (shouldScroll) {
              scheduleScrollTopHard();
            }
            updateSliderNextState();
          });
          pageUiObserver.observe(target, { childList: true, subtree: false });
        }

        function waitForPageObserver() {
          var tries = 0;
          function check() {
            installPageObserver();
            if (pageUiObserver) return;
            tries += 1;
            if (tries < 60) setTimeout(check, 100);
          }
          check();
        }

        function installRewardSpriteAnimator() {
          if (window.__rewardSpriteAnimator) return;
          var tiles = 11;
          var totalFrames = tiles * tiles;
          var lastStamp = null;
          var frameFloat = 0;
          function step(ts) {
            if (!lastStamp) lastStamp = ts;
            var dt = (ts - lastStamp) / 1000;
            lastStamp = ts;
            var target = document.querySelector('.progress-step.is-reward');
            if (target) {
              var isActive = target.classList.contains('is-active') || target.classList.contains('is-complete');
              var fps = 60;
              frameFloat += dt * fps;
              var frameIndex = Math.floor(frameFloat) % totalFrames;
              var col = frameIndex % tiles;
              var row = Math.floor(frameIndex / tiles);
              var frameSize = parseFloat(getComputedStyle(target).getPropertyValue('--frame')) || 24;
              var x = (-col * frameSize) + 'px';
              var y = (-row * frameSize) + 'px';
              target.style.setProperty('--frame-x', x);
              target.style.setProperty('--frame-y', y);
            } else {
              lastStamp = ts;
            }
            requestAnimationFrame(step);
          }
          window.__rewardSpriteAnimator = true;
          requestAnimationFrame(step);
        }

        function updateSliderNextState() {
          var card = document.querySelector('.slider-page[data-slider-ids]');
          var nextBtn = document.getElementById('next_step');
          if (!card || !nextBtn) return;
          var ids = card.getAttribute('data-slider-ids') || '';
          var list = ids.split(',').map(function(x){ return x.trim(); }).filter(Boolean);
          if (!list.length) return;
          var values = (window.Shiny && Shiny.shinyapp && Shiny.shinyapp.$inputValues) ? Shiny.shinyapp.$inputValues : {};
          var allTouched = list.every(function(id) {
            var val = values[id + '__touched'];
            return val === 1 || val === '1';
          });
          nextBtn.disabled = !allTouched;
          nextBtn.classList.toggle('is-disabled', !allTouched);
        }
        window.__axpUpdateSliderNextState = updateSliderNextState;

        function ensureSlidersReady() {
          var sliders = document.querySelectorAll('.irs--shiny');
          sliders.forEach(function(node) {
            node.classList.add('is-ready');
          });
        }
        window.__axpEnsureSlidersReady = ensureSlidersReady;


        function showBusy() {
          if (!busy) return;
          if (!bootHidden) return;
          busy.classList.remove('hidden');
        }

        function hideBusy() {
          if (!busy) return;
          busy.classList.add('hidden');
        }

        document.addEventListener('DOMContentLoaded', function() {
          if ('scrollRestoration' in history) {
            history.scrollRestoration = 'manual';
          }
          boot = document.getElementById('boot-overlay');
          busy = document.getElementById('busy-overlay');
          bootBar = document.getElementById('boot-progress-bar');
          bootPct = document.getElementById('boot-progress-pct');
          appShell = document.querySelector('.app-shell');

          var assets = ['circe-logo.png', 'circe-bg.png'];
          if (p6mEnabled) {
            assets.push('p6m-bg.js');
          }
          assets.forEach(function(src) {
            var link = document.createElement('link');
            link.rel = 'preload';
            link.as = src.endsWith('.js') ? 'script' : 'image';
            link.href = src;
            if (link.as === 'image') {
              link.fetchPriority = 'high';
              link.setAttribute('fetchpriority', 'high');
            }
            document.head.appendChild(link);
          });

          if (!p6mEnabled) {
            var bgImg = new Image();
            bgImg.decoding = 'async';
            bgImg.loading = 'eager';
            bgImg.src = 'circe-bg.png';
            bgImg.onload = function() {
              document.body.classList.add('bg-ready');
            };
          }

          if (boot) boot.classList.remove('hidden');
          if (busy) busy.classList.add('hidden');
          installRewardSpriteAnimator();
          ensureSlidersReady();
          updateSliderNextState();

          // Failsafe in case Shiny events don't fire
          bootTimeout = setTimeout(function() {
            setBootProgress(100);
          }, 4000);
          bootLoop();
          setBootProgress(0);
          waitForPageObserver();
        });

        document.addEventListener('shiny:connected', function() {
          setBootProgress(55);
          waitForPageObserver();
          installRewardSpriteAnimator();
          ensureSlidersReady();
          updateSliderNextState();
        });

        document.addEventListener('shiny:inputchanged', function() {
          ensureSlidersReady();
          updateSliderNextState();
        });

        document.addEventListener('shiny:busy', function() {
          showBusy();
        });

        document.addEventListener('shiny:idle', function() {
          hideBusy();
        });

        if (window.Shiny) {
          function pulseHeader(node) {
            if (!node) return;
            if (node.__pulseTimer) {
              clearTimeout(node.__pulseTimer);
              node.__pulseTimer = null;
            }
            if (node.__pulsePending) return;
            node.__pulsePending = true;
            requestAnimationFrame(function() {
              node.__pulsePending = false;
              node.classList.remove('is-pulsing');
              void node.offsetWidth;
              node.classList.add('is-pulsing');
              node.__pulseTimer = setTimeout(function() {
                node.classList.remove('is-pulsing');
                node.__pulseTimer = null;
              }, 210);
            });
          }

          function waitForUIAndFonts(cb) {
            var tries = 0;
            function check() {
              tries += 1;
              var cardReady = document.querySelector('.app-card') !== null;
              if (cardReady) {
                if (document.fonts && document.fonts.ready) {
                  document.fonts.ready.then(cb).catch(cb);
                } else {
                  cb();
                }
                return;
              }
              if (tries < 60) {
                requestAnimationFrame(check);
              } else {
                cb();
              }
            }
            check();
          }

          function waitForSliders(cb) {
            var tries = 0;
            function check() {
              tries += 1;
              var sliders = document.querySelectorAll('.irs--shiny');
              if (!sliders.length) return cb();
              var allReady = true;
              sliders.forEach(function(node) {
                if (!node.classList.contains('is-ready')) allReady = false;
              });
              if (allReady || tries >= 60) {
                cb();
              } else {
                requestAnimationFrame(check);
              }
            }
            check();
          }

          function clearTransitionAfter(delayMs) {
            var delay = typeof delayMs === 'number' ? delayMs : 0;
            waitForSliders(function() {
              if (!appShell) return;
              if (delay > 0) {
                setTimeout(function() {
                  appShell.classList.remove('is-transitioning');
                }, delay);
              } else {
                appShell.classList.remove('is-transitioning');
              }
            });
          }

          Shiny.addCustomMessageHandler('bootReady', function() {
            if (bootTimeout) clearTimeout(bootTimeout);
            waitForUIAndFonts(function() {
              waitForSliders(function() {
                installRewardSpriteAnimator();
                setBootProgress(100);
                if (appShell) {
                  setTimeout(function() {
                    appShell.classList.remove('is-booting');
                  }, 120);
                }
              });
            });
          });
          Shiny.addCustomMessageHandler('bootProgress', function(msg) {
            setBootProgress(msg.pct || 0);
          });
          Shiny.addCustomMessageHandler('busyShow', function() {
            if (busy) busy.classList.remove('hidden');
            if (appShell) appShell.classList.add('is-transitioning');
          });
          Shiny.addCustomMessageHandler('busyHide', function() {
            if (busy) busy.classList.add('hidden');
            if (appShell) clearTransitionAfter(525);
          });
          Shiny.addCustomMessageHandler('pulseTransition', function() {
            if (!appShell) return;
            appShell.classList.remove('is-transitioning');
            void appShell.offsetWidth;
            appShell.classList.add('is-transitioning');
            clearTransitionAfter(525);
          });
          Shiny.addCustomMessageHandler('pulseHeaders', function() {
            var headers = document.querySelectorAll('.experience-header');
            headers.forEach(function(node) {
              pulseHeader(node);
            });
          });
          var lastPulseAt = 0;
          var suppressPulseUntil = 0;
          function pulsesAllowed() {
            return Date.now() >= suppressPulseUntil;
          }
          function pulseHeadersOnce() {
            if (!pulsesAllowed()) return;
            var now = Date.now();
            if (now - lastPulseAt < 180) return;
            lastPulseAt = now;
            var headers = document.querySelectorAll('.experience-header');
            headers.forEach(function(node) {
              pulseHeader(node);
            });
          }

          document.addEventListener('click', function(evt) {
            var target = evt.target;
            if (!target) return;
            if (target.dataset && target.dataset.step) {
              var step = parseInt(target.dataset.step, 10);
              if (!isNaN(step) && window.Shiny && Shiny.setInputValue) {
                Shiny.setInputValue('dev_step_jump', step, {priority: 'event'});
              }
            }
            var navButton = target.closest ? target.closest('#next_step, #prev_step') : null;
            if (navButton) {
              if (appShell) appShell.classList.add('is-transitioning');
              if (busy && bootHidden) busy.classList.remove('hidden');
              scheduleScrollTopHard();
              waitForSliders(function() {
                setTimeout(function() {
                  if (appShell) appShell.classList.remove('is-transitioning');
                  if (busy) busy.classList.add('hidden');
                }, 750);
              });
            }
          }, true);

          Shiny.addCustomMessageHandler('suppressHeaderPulse', function(msg) {
            var ms = (msg && msg.ms) ? msg.ms : 300;
            suppressPulseUntil = Date.now() + ms;
          });
        }
      })();
    "
      js <- gsub("P6M_ENABLED_PLACEHOLDER", ifelse(P6M_ENABLED, "true", "false"), js, fixed = TRUE)
      js
    })),
    if (!P6M_ENABLED) tags$style(HTML("
      html, body {
        min-height: 100%;
        background-color: var(--bg);
      }
      body {
        background-color: var(--bg);
      }
      .app-shell {
        min-height: 100vh;
        background-color: transparent;
      }
      body::before {
        content: '';
        position: fixed;
        inset: 0;
        background-image: url('circe-bg.png');
        background-repeat: no-repeat;
        background-position: center;
        background-size: cover;
        z-index: 0;
        pointer-events: none;
        transform: translateZ(0);
        opacity: 1;
      }
    "))
  ),
  div(
    id = "boot-overlay",
    class = "boot-overlay",
    div(
      class = "boot-terminal",
      div(class = "boot-title", "AXP / SYSTEM BOOT"),
      div(class = "boot-quip", "PLEASE WAIT WHILE THE MACHINE ELVES SCRAMBLE FOR THEIR SCIENCE HATS"),
      div(class = "boot-progress", tags$span(id = "boot-progress-bar")),
      div(class = "boot-foot", tags$span(id = "boot-progress-pct", "0%"))
    )
  ),
  div(
    id = "busy-overlay",
    class = "busy-overlay hidden",
    div(class = "busy-pill", "Loading")
  ),
  if (DEV_MODE) div(class = "dev-badge", "Dev Mode"),
  if (P6M_ENABLED) div(id = "p6m-layer"),
    div(
      id = "app-shell",
      tabindex = "-1",
      class = "app-shell is-booting",
      div(id = "scroll-top-anchor-a", tabindex = "-1"),
      div(id = "scroll-top-anchor-b", tabindex = "-1"),
      div(
        class = "app-top",
        tags$img(src = "circe-logo.png", alt = "Circe logo", class = "app-logo"),
        div(
          class = "app-links",
          tags$a(
            href = "https://osf.io/c3zq5/overview",
            target = "_blank",
            rel = "noopener",
            class = "app-link",
            "About AXP"
          ),
          tags$a(
            href = "https://circe-science.com/",
            target = "_blank",
            rel = "noopener",
            class = "app-link",
            "About Circe"
          )
        )
      ),
      div(class = "app-eyebrow", "AXP survey"),
      div(class = "app-title", "Participant Questionnaire"),
      conditionalPanel(
        condition = "output.showExperienceHeader == 'TRUE'",
        div(class = "prep-eyebrow experience-header", textOutput("experience_header_persistent"))
      ),
      uiOutput("progress_steps"),
      uiOutput("page_ui"),
      uiOutput("feedback_panel")
    )
  )

server <- function(input, output, session) {
  cfg <- get_config(required = FALSE)
  boot_progress <- function(pct) {
    session$sendCustomMessage("bootProgress", list(pct = pct))
  }
  boot_progress(0)

  format_load_status <- function(sheet_name, is_error = FALSE, message = NULL) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    if (is_error) {
      return(paste0("Sheet load failed (", timestamp, "): ", message))
    }
    if (is.null(sheet_name) || sheet_name == "") {
      return(paste0("Loaded sheet: configured default tab (", timestamp, ")."))
    }
    paste0("Loaded sheet: ", sheet_name, " (", timestamp, ").")
  }

  update_questionnaire <- function(sheet_name_override = NULL) {
    sheet_name <- cfg$GOOGLE_SHEET_SHEETNAME
    if (!is.null(sheet_name_override) && sheet_name_override != "") {
      sheet_name <- sheet_name_override
    }

    df <- NULL
    if (sheet_name != "" && cfg$GOOGLE_SHEET_ID != "") {
      df <- try(load_questionnaire_from_gsheet(cfg$GOOGLE_SHEET_ID, sheet_name, cfg), silent = TRUE)
      if (inherits(df, "try-error")) {
        load_status(format_load_status(sheet_name, is_error = TRUE, message = "Sheet tab not found (check spelling) or access denied."))
        return(invisible(NULL))
      }
    } else {
      df <- load_questionnaire()
    }

    questionnaire_df(df)
    definition_hash(compute_definition_hash(df))
    instrument_id(df$instrument_id[1])
    instrument_version(df$instrument_version[1])
    language(df$language[1])
    load_status(format_load_status(sheet_name))
  }

  initial_df <- NULL
  boot_progress(25)
  initial_status <- ""
  if (cfg$GOOGLE_SHEET_ID != "" && cfg$GOOGLE_SHEET_SHEETNAME != "") {
    boot_progress(35)
    initial_df <- try(load_questionnaire_from_gsheet(cfg$GOOGLE_SHEET_ID, cfg$GOOGLE_SHEET_SHEETNAME, cfg), silent = TRUE)
    if (inherits(initial_df, "try-error")) {
      initial_status <- format_load_status(cfg$GOOGLE_SHEET_SHEETNAME, is_error = TRUE, message = "Sheet tab not found (check spelling) or access denied.")
      initial_df <- load_questionnaire()
    } else {
      initial_status <- format_load_status(cfg$GOOGLE_SHEET_SHEETNAME)
    }
  } else {
    boot_progress(35)
    initial_df <- load_questionnaire()
    initial_status <- format_load_status(cfg$GOOGLE_SHEET_SHEETNAME)
  }
  boot_progress(65)

  questionnaire_df <- reactiveVal(initial_df)
  boot_progress(80)
  definition_hash <- reactiveVal(compute_definition_hash(initial_df))
  instrument_id <- reactiveVal(initial_df$instrument_id[1])
  instrument_version <- reactiveVal(initial_df$instrument_version[1])
  language <- reactiveVal(initial_df$language[1])
  load_status <- reactiveVal(initial_status)
  current_step <- reactiveVal(1)
  navigation_error <- reactiveVal("")
  validation_error <- reactiveVal("")
  progress_start_step <- 1
  progress_end_step <- 14  # Tracer moved to optional step 15

  observeEvent(input$reload_questionnaire, {
    sheet_name <- if (is.null(input$sheet_name_override)) "" else trimws(input$sheet_name_override)
    update_questionnaire(sheet_name_override = sheet_name)
  })

  output$load_status <- renderText(load_status())
  output$showExperienceHeader <- renderText({
    step <- current_step()
    step >= progress_start_step && step <= (progress_end_step - 1)
  })
  outputOptions(output, "showExperienceHeader", suspendWhenHidden = FALSE)
  output$progress_steps <- renderUI({
    step <- current_step()
    if (step < progress_start_step || step > progress_end_step) {
      return(NULL)
    }
    total <- progress_end_step - progress_start_step + 1
    index <- step - progress_start_step + 1
    steps_ui <- lapply(seq_len(total), function(i) {
      cls <- if (i < index) {
        "progress-step is-complete"
      } else if (i == index) {
        "progress-step is-active"
      } else {
        "progress-step"
      }
      if (i == total) {
        cls <- paste(cls, "is-reward")
      }
      if (DEV_MODE) {
        jump_step <- progress_start_step + i - 1
        tags$button(
          type = "button",
          class = paste(cls, "is-clickable"),
          `data-step` = jump_step,
          `aria-label` = paste0("Jump to step ", jump_step),
          onclick = sprintf("if (window.Shiny) { Shiny.setInputValue('dev_step_jump', %d, {priority: 'event'}); }", jump_step)
        )
      } else {
        div(class = cls)
      }
    })
    div(class = "progress-steps", steps_ui)
  })

  observeEvent(input$animated_bg, {
    session$sendCustomMessage("p6mToggle", list(enabled = isTRUE(input$animated_bg)))
  }, ignoreInit = FALSE)

  session$onFlushed(function() {
    boot_progress(100)
    session$sendCustomMessage("bootReady", list(ready = TRUE))
  }, once = TRUE)

  show_transition_busy <- function() {
    session$sendCustomMessage("busyShow", list())
    session$onFlushed(function() {
      session$sendCustomMessage("busyHide", list())
    }, once = TRUE)
  }

  slider_group_complete <- function(ids) {
    ids <- ids[!is.na(ids) & ids != ""]
    if (length(ids) == 0) return(TRUE)
    all(vapply(ids, function(id) {
      touched <- input[[paste0(id, "__touched")]]
      isTRUE(touched == 1) || identical(touched, "1")
    }, logical(1)))
  }

  observeEvent(input$next_step, {
    step <- current_step()
    if (step == 1) {
      validation_error("")
      navigation_error("")
      current_step(2)
      show_transition_busy()
    } else if (step == 2) {
      if (!isTRUE(input$consent)) {
        navigation_error("Consent is required before continuing.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(3)
        show_transition_busy()
      }
    } else if (step == 3) {
      validation_error("")
      navigation_error("")
      current_step(4)
      show_transition_busy()
    } else if (step == 4) {
      if (is.null(input$q0) || input$q0 == "") {
        validation_error("Please select a substance to continue.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(5)
        show_transition_busy()
      }
    } else if (step == 5) {
      if (is.null(input$q1) || input$q1 == "") {
        validation_error("Please select a dose to continue.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(6)
        show_transition_busy()
      }
    } else if (step == 6) {
      validation_error("")
      navigation_error("")
      current_step(7)
      show_transition_busy()
    } else if (step == 7) {
      validation_error("")
      navigation_error("")
      current_step(8)
      show_transition_busy()
    } else if (step == 8) {
      if (!slider_group_complete(slider_group_ids1())) {
        validation_error("Please move each slider before continuing.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(9)
        show_transition_busy()
      }
    } else if (step == 9) {
      if (!slider_group_complete(slider_group_ids2())) {
        validation_error("Please move each slider before continuing.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(10)
        show_transition_busy()
      }
    } else if (step == 10) {
      if (!slider_group_complete(slider_group_ids3())) {
        validation_error("Please move each slider before continuing.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(11)
        show_transition_busy()
      }
    } else if (step == 11) {
      if (!slider_group_complete(slider_group_ids4())) {
        validation_error("Please move each slider before continuing.")
      } else {
        validation_error("")
        navigation_error("")
        current_step(12)
        show_transition_busy()
      }
    } else if (step == 12) {
      validation_error("")
      navigation_error("")
      current_step(13)  # Skip to final reveal (tracer is now optional step 15)
      show_transition_busy()
    } else if (step == 13) {
      # Final reveal page - submit happens here, nav to step 14 handled by submit button
      validation_error("")
      navigation_error("")
    }
  })

  observeEvent(input$prev_step, {
    step <- current_step()
    if (step > 1) {
      validation_error("")
      navigation_error("")
      current_step(step - 1)
      show_transition_busy()
    }
  })

  observeEvent(input$dev_step_jump, {
    if (!isTRUE(DEV_MODE)) return()
    step <- input$dev_step_jump
    if (is.null(step) || is.na(step)) return()
    step <- as.integer(step)
    if (step < progress_start_step || step > progress_end_step) return()
    validation_error("")
    navigation_error("")
    current_step(step)
    show_transition_busy()
  })

  selected_drug <- reactiveVal("")
  selected_dose <- reactiveVal("")
  suppress_pulse_server <- reactiveVal(FALSE)
  question_type_map <- list()

  observeEvent(input$q0, {
    if (!is.null(input$q0) && input$q0 != "") {
      validation_error("")
      selected_drug(input$q0)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$q1, {
    if (!is.null(input$q1) && input$q1 != "") {
      validation_error("")
      selected_dose(input$q1)
    }
  }, ignoreInit = TRUE)

  suppress_header_pulse <- function(ms = 350) {
    suppress_pulse_server(TRUE)
    session$sendCustomMessage("suppressHeaderPulse", list(ms = ms))
    session$onFlushed(function() {
      suppress_pulse_server(FALSE)
    }, once = TRUE)
  }

  restore_question_input <- function(item_id, value, input_type) {
    if (is.null(value) || value == "") return()
    if (is.null(input_type) || input_type == "") return()
    suppress_header_pulse()
    if (input_type == "selectInput") {
      updateSelectInput(session, item_id, selected = value)
    } else if (input_type == "selectizeInput") {
      updateSelectizeInput(session, item_id, selected = value, server = TRUE)
    } else if (input_type == "radioButtons") {
      updateRadioButtons(session, item_id, selected = value)
    }
  }

  observeEvent(current_step(), {
    step <- current_step()
    drug <- selected_drug()
    dose <- selected_dose()
    q0_type <- question_type_map[["q0"]]
    q1_type <- question_type_map[["q1"]]
    session$onFlushed(function() {
      if (step == 4) {
        restore_question_input("q0", drug, q0_type)
      } else if (step == 5) {
        restore_question_input("q1", dose, q1_type)
        if (is.null(dose) || dose == "") {
          session$sendCustomMessage("clearRadioSelection", list(id = "q1"))
        }
      }
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(current_step(), {
    step <- current_step()
    ids1 <- slider_group_ids1()
    ids2 <- slider_group_ids2()
    ids3 <- slider_group_ids3()
    ids4 <- slider_group_ids4()
    session$onFlushed(function() {
      if (step == 8) {
        restore_slider_values(ids1)
      } else if (step == 9) {
        restore_slider_values(ids2)
      } else if (step == 10) {
        restore_slider_values(ids3)
      } else if (step == 11) {
        restore_slider_values(ids4)
      }
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$q0, {
    if (isTRUE(suppress_pulse_server())) return()
    if (!is.null(input$q0) && input$q0 != "") {
      session$onFlushed(function() {
        session$sendCustomMessage("pulseHeaders", list())
      }, once = TRUE)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$q1, {
    if (isTRUE(suppress_pulse_server())) return()
    if (!is.null(input$q1) && input$q1 != "") {
      session$onFlushed(function() {
        session$sendCustomMessage("pulseHeaders", list())
      }, once = TRUE)
    }
  }, ignoreInit = TRUE)

  experience_header_value <- function(include_dose = TRUE) {
    drug <- selected_drug()
    dose <- selected_dose()
    if (is.null(drug) || drug == "") {
      drug <- "Each experience is unique"
    }
    parts <- c(drug, if (include_dose && !is.null(dose) && dose != "") dose else NULL)
    toupper(paste(parts, collapse = " - "))
  }

  output$experience_header_persistent <- renderText({
    step <- current_step()
    include_dose <- step >= 5
    experience_header_value(include_dose = include_dose)
  })

  output$page_ui <- renderUI({
    step <- current_step()

    if (step == 1) {
      return(tagList(
        div(
          class = "app-card",
          div(
            class = "intro-panel",
            div(
              class = "intro-center",
              div(class = "intro-title", "Intro"),
              div(
                class = "intro-body",
                p(
                  "This survey can be sourced from a local CSV file or from a shared Google Sheet (",
                  tags$a(
                    href = "https://docs.google.com/spreadsheets/d/1o2eCjyVRHiIYzVaQ8Z4wAA0XmOwGKWfTj0d36wfw_jc/edit?usp=sharing",
                    target = "_blank",
                    rel = "noopener",
                    "open sheet"
                  ),
                  "). Choose whichever workflow is easiest for you."
                ),
                tags$ul(
                  tags$li("Local CSV: edit docs/sample_questionnaire.csv for quick, offline changes on this machine."),
                  tags$li("Google Sheets: edit the shared sheet so collaborators can update content without touching code.")
                ),
                p("Tabs can represent versions (e.g., v0.2, v0.3) or different languages. Set the default tab in .Renviron, or type a tab name below and press Reload."),
                p("Recommended workflow: develop locally using the CSV, run the app and validate changes, then push to the repo. After the server pulls, upload the CSV to Google Drive, open it as a Google Sheet, and copy the full sheet into a new tab in the shared survey sheet that the server’s service account can access.")
              )
            ),
            if (P6M_ENABLED) checkboxInput("animated_bg", "Animated p6m waves", value = P6M_ANIMATED_DEFAULT),
            div(
              class = "intro-controls",
              textInput("sheet_name_override", "Sheet tab (optional)", value = ""),
              actionButton("reload_questionnaire", "Reload questionnaire", class = "intro-reload"),
              div(class = "intro-status", textOutput("load_status"))
            )
          )
        ),
        div(
          class = "nav-actions",
          actionButton("next_step", "Start", class = "intro-start"),
          tags$button(type = "button", class = "intro-results", "See all my results")
        )
      ))
    }

    if (step == 2) {
      return(tagList(
        div(
          class = "app-card",
          h3("Before we start"),
          div(
            class = "consent-body",
            p("The Altered eXperience Project is an effort to organize and systematize our knowledge about human subjective experience during different states of consciousness."),
            p("Some of these states are very different from our ordinary experience and different people experience these states in their own particular ways. That is why your participation is very important."),
            p("In this experiment we’re focusing on drug induced altered states with cannabis, psilocybin, alcohol and MDMA. If you agree to participate, you will be asked questions about one of your own altered experiences. It will take 5–10 minutes."),
            p("Every experience you share will be fully anonymous and all data openly available for researchers all over the world. Once you finish, we will show you how your experience compares to other people’s experiences.")
          ),
          div(
            class = "consent-checkbox",
            tags$label(
              class = "consent-pill",
              tags$input(type = "checkbox", id = "consent", class = "shiny-input-checkbox"),
              tags$span(class = "consent-indicator"),
              tags$span("I agree to partake")
            )
          ),
          div(class = "error-text", textOutput("navigation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 3) {
      return(tagList(
        div(
          class = "app-card",
          h3("Visualize your experience"),
          div(
            class = "prep-body",
            p("Think of a time when you took either cannabis, psilocybin, alcohol or MDMA and visualize your experience."),
            p("Focus on one single, altered state experience. Visualize it. Think of where you were, the time it was, the sounds and smells around you."),
            p("Try recapturing the feel of your whole body and mind entering the experience. Once you have focused on that single experience, we can move on.")
          )
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }
    if (step == 4) {
      return(tagList(
        div(
          class = "app-card",
          uiOutput("questionnaire_ui_page1"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 5) {
      return(tagList(
        div(
          class = "app-card",
          uiOutput("questionnaire_ui_page2"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 6) {
      return(tagList(
        div(
          class = "app-card",
          h3("Describe the context in which you had this experience."),
          uiOutput("questionnaire_ui_page3"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 7) {
      return(tagList(
        div(
          class = "app-card",
          h3("Perfect!"),
          div(
            class = "prep-body",
            p("Next, we will ask you a series of questions for you to answer what you experienced.")
          )
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 8) {
      return(tagList(
        div(
          class = "app-card slider-page",
          `data-slider-ids` = paste(slider_group_ids1(), collapse = ","),
          h3("Questions"),
          uiOutput("questionnaire_ui_slider1"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 9) {
      return(tagList(
        div(
          class = "app-card slider-page",
          `data-slider-ids` = paste(slider_group_ids2(), collapse = ","),
          h3("Questions"),
          uiOutput("questionnaire_ui_slider2"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 10) {
      return(tagList(
        div(
          class = "app-card slider-page",
          `data-slider-ids` = paste(slider_group_ids3(), collapse = ","),
          h3("Questions"),
          uiOutput("questionnaire_ui_slider3"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 11) {
      return(tagList(
        div(
          class = "app-card slider-page",
          `data-slider-ids` = paste(slider_group_ids4(), collapse = ","),
          h3("Questions"),
          uiOutput("questionnaire_ui_slider4"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 12) {
      return(tagList(
        div(
          class = "app-card",
          h3("Freely describe your experience in your own words"),
          uiOutput("questionnaire_ui_free"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    # Step 13: Final reveal (submit triggers feedback)
    if (step == 13) {
      return(tagList(
        div(
          class = "app-card reward-card",
          div(class = "reward-eyebrow", "Final reveal"),
          h3(class = "reward-title", "Your feedback is ready"),
          div(
            class = "reward-body",
            p("We are about to generate a personalized snapshot of your experience and compare it with others."),
            p("This is the reward for your contribution. Ready to see how you map onto the spectrum?")
          )
        ),
        div(class = "error-text", textOutput("validation_error")),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("submit", "Reveal my feedback")
        )
      ))
    }

    # Step 14: Feedback display
    if (step == 14) {
      return(NULL)  # Feedback is rendered in feedback_panel
    }

    # Step 15: Optional Experience Tracer (experimental)
    if (step == 15) {
      return(tagList(
        div(
          class = "app-card tracer-experimental",
          div(class = "beta-badge", "BETA / EXPERIMENTAL"),
          h3("Experience Tracer"),
          p(class = "tracer-intro", "Draw a curve representing your subjective experience intensity over time. This feature is experimental and your trace will not be saved yet."),
          uiOutput("tracer_ui"),
          div(class = "error-text", textOutput("validation_error"))
        ),
        div(
          class = "nav-actions",
          actionButton("back_to_feedback", "Back to Feedback")
        )
      ))
    }
  })

  output$navigation_error <- renderText(navigation_error())

questionnaire_ui_page1 <- reactiveVal(NULL)
questionnaire_ui_page2 <- reactiveVal(NULL)
questionnaire_ui_page3 <- reactiveVal(NULL)
questionnaire_ui_slider1 <- reactiveVal(NULL)
questionnaire_ui_slider2 <- reactiveVal(NULL)
questionnaire_ui_slider3 <- reactiveVal(NULL)
questionnaire_ui_slider4 <- reactiveVal(NULL)
questionnaire_ui_free <- reactiveVal(NULL)
tracer_ui_cached <- reactiveVal(NULL)
  slider_group_ids1 <- reactiveVal(character(0))
  slider_group_ids2 <- reactiveVal(character(0))
  slider_group_ids3 <- reactiveVal(character(0))
  slider_group_ids4 <- reactiveVal(character(0))
  slider_values <- reactiveValues()
observeEvent(questionnaire_df(), {
  df <- questionnaire_df()
  df_questions <- df[df$type != "experience_tracer", ]
  type_map <- list()
  if (!is.null(df_questions) && nrow(df_questions) > 0) {
    type_map <- setNames(as.character(df_questions$type), as.character(df_questions$item_id))
  }
  question_type_map <<- type_map
  page1_df <- df_questions[df_questions$item_id == "q0", ]
  page2_df <- df_questions[df_questions$item_id == "q1", ]
  page3_df <- df_questions[df_questions$item_id == "q_context", ]
  free_df <- df_questions[df_questions$item_id == "q_free", ]
  slider_df <- df_questions[df_questions$type == "sliderInput", ]
  slider_df <- slider_df[order(as.numeric(slider_df$order)), ]
  slider_count <- nrow(slider_df)
  slider_sizes <- if (slider_count == 0) {
    rep(0, 4)
  } else {
    base <- floor(slider_count / 4)
    extra <- slider_count %% 4
    sizes <- rep(base, 4)
    if (extra > 0) sizes[seq_len(extra)] <- sizes[seq_len(extra)] + 1
    sizes
  }
  slider_groups <- vector("list", 4)
  idx <- 1
  for (i in seq_len(4)) {
    if (slider_sizes[i] > 0) {
      slider_groups[[i]] <- slider_df[idx:(idx + slider_sizes[i] - 1), ]
    } else {
      slider_groups[[i]] <- slider_df[0, ]
    }
    idx <- idx + slider_sizes[i]
  }
  questionnaire_ui_page1(questionnaire_ui_vendor(page1_df))
  questionnaire_ui_page2(questionnaire_ui_vendor(page2_df))
  questionnaire_ui_page3(questionnaire_ui_vendor(page3_df))
  questionnaire_ui_slider1(questionnaire_ui_vendor(slider_groups[[1]]))
  questionnaire_ui_slider2(questionnaire_ui_vendor(slider_groups[[2]]))
  questionnaire_ui_slider3(questionnaire_ui_vendor(slider_groups[[3]]))
  questionnaire_ui_slider4(questionnaire_ui_vendor(slider_groups[[4]]))
  questionnaire_ui_free(questionnaire_ui_vendor(free_df))
  slider_group_ids1(as.character(slider_groups[[1]]$item_id))
  slider_group_ids2(as.character(slider_groups[[2]]$item_id))
  slider_group_ids3(as.character(slider_groups[[3]]$item_id))
  slider_group_ids4(as.character(slider_groups[[4]]$item_id))
  tracer_ui_cached(questionnaire_ui_vendor(df[df$type == "experience_tracer", ]))
}, ignoreInit = FALSE)

  observe({
    ids <- c(
      slider_group_ids1(),
      slider_group_ids2(),
      slider_group_ids3(),
      slider_group_ids4()
    )
    ids <- ids[!is.na(ids) & ids != ""]
    if (length(ids) == 0) return()
    for (id in ids) {
      val <- input[[id]]
      if (!is.null(val) && !is.na(val) && val != "") {
        slider_values[[id]] <- val
      }
    }
  })

  restore_slider_values <- function(ids) {
    ids <- ids[!is.na(ids) & ids != ""]
    if (length(ids) == 0) return()
    for (id in ids) {
      val <- slider_values[[id]]
      if (!is.null(val) && !is.na(val) && val != "") {
        updateSliderInput(session, id, value = val)
      }
    }
  }

output$questionnaire_ui_page1 <- renderUI({
  cached <- questionnaire_ui_page1()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_page2 <- renderUI({
  cached <- questionnaire_ui_page2()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_page3 <- renderUI({
  cached <- questionnaire_ui_page3()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_slider1 <- renderUI({
  cached <- questionnaire_ui_slider1()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_slider2 <- renderUI({
  cached <- questionnaire_ui_slider2()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_slider3 <- renderUI({
  cached <- questionnaire_ui_slider3()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_slider4 <- renderUI({
  cached <- questionnaire_ui_slider4()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$questionnaire_ui_free <- renderUI({
  cached <- questionnaire_ui_free()
  if (is.null(cached)) {
    NULL
  } else {
    cached
  }
})

output$tracer_ui <- renderUI({
  cached <- tracer_ui_cached()
  if (is.null(cached)) {
    div(class = "muted", "Loading experience tracer...")
  } else if (length(cached) == 0) {
    div(class = "muted", "No experience tracer items configured.")
  } else {
    cached
  }
})

  submission_status <- reactiveVal("")
  latest_scores <- reactiveVal(data.frame())
  peer_points_cached <- reactiveVal(data.frame())

  mock_scores_df <- function() {
    mock_scales <- c(
      "Experience of Unity",
      "Spiritual Experience",
      "Blissful State",
      "Insightfulness",
      "Disembodiment",
      "Impaired Control and Cognition",
      "Anxiety",
      "Complex Imagery",
      "Elementary Imagery",
      "Audio-Visual Synesthesia",
      "Changed Meaning of Percepts"
    )
    data.frame(
      scale_id = mock_scales,
      score_value = c(68, 52, 72, 60, 38, 44, 32, 55, 48, 41, 64),
      stringsAsFactors = FALSE
    )
  }

  build_peer_points <- function(scale_ids, seed_key) {
    seed_val <- sum(utf8ToInt(seed_key))
    set.seed(seed_val)
    data.frame(
      scale_id = rep(scale_ids, each = 28),
      value = pmin(100, pmax(0, rnorm(length(scale_ids) * 28, mean = 55, sd = 18))),
      stringsAsFactors = FALSE
    )
  }

  output$validation_error <- renderText(validation_error())
  output$feedback_summary <- renderUI({
    status_line <- submission_status()
    scores_ready <- nrow(latest_scores()) > 0
    status_text <- if (status_line != "") {
      status_line
    } else if (!scores_ready) {
      "Preparing feedback…"
    } else {
      ""
    }

    tagList(
      p(
        class = "feedback-note feedback-note--compact",
        tags$strong("How to read this chart:"),
        " The purple shape shows your scores from this submission.",
        " Farther from the center means a stronger reported experience.",
        " The gray dots summarize how other people tended to respond (mock data for now)."
      ),
      if (status_text != "") p(class = "muted", status_text)
    )
  })

  output$feedback_panel <- renderUI({
    step <- current_step()
    hidden <- step != 14  # Feedback now shows on step 14
    nav_actions <- if (step == 14) {
      div(
        class = "nav-actions",
        actionButton("prev_step", "Back"),
        actionButton("try_tracer", "Try Experience Tracer (Beta)", class = "btn-secondary")
      )
    } else {
      NULL
    }
    div(
      class = if (hidden) "feedback-panel is-hidden" else "feedback-panel",
      tagList(
        div(
          class = "app-card",
          h3("Feedback"),
          uiOutput("feedback_summary"),
          plotOutput("radar_plot", height = "540px", width = "100%"),
          NULL
        ),
        nav_actions
      )
    )
  })

  observeEvent(list(input$q0, input$q1), {
    drug <- if (is.null(input$q0)) "" else input$q0
    dose <- if (is.null(input$q1)) "" else input$q1
    if (drug == "" || dose == "") {
      return()
    }
    scores_preview <- latest_scores()
    if (nrow(scores_preview) == 0) {
      scores_preview <- mock_scores_df()
    }
    peer_points_cached(build_peer_points(scores_preview$scale_id, paste0(drug, "-", dose)))
  }, ignoreInit = FALSE)

  output$radar_plot <- renderPlot({
    scores <- latest_scores()
    if (nrow(scores) == 0) {
      scores <- mock_scores_df()
    }

    peer_points <- peer_points_cached()
    if (is.null(peer_points) || nrow(peer_points) == 0) {
      peer_points <- build_peer_points(scores$scale_id, "default")
    }

    width <- session$clientData$output_radar_plot_width
    if (is.null(width) || is.na(width) || width <= 0) {
      width <- 700
    }
    base_size <- max(8, min(12, width / 55))
    is_phone <- width < 420
    label_width <- if (is_phone) 16 else 20
    label_radius <- if (is_phone) 1.44 else 1.58
    label_size <- if (is_phone) base_size * 0.13 else base_size * 0.176
    safe_plot <- function(scores_df, peer_points_df) {
      tryCatch(
        plot_scores_radar(
          scores_df,
          peer_points_df = peer_points_df,
          base_size = base_size,
          label_size = label_size,
          label_width = label_width,
          label_radius = label_radius
        ),
        error = function(e) NULL
      )
    }
    p <- safe_plot(scores, peer_points)
    if (is.null(p)) {
      scores <- mock_scores_df()
      peer_points <- build_peer_points(scores$scale_id, "default")
      p <- safe_plot(scores, peer_points)
    }
    if (!is.null(p)) print(p)
  }, height = function() {
    width <- session$clientData$output_radar_plot_width
    if (is.null(width) || is.na(width) || width <= 0) {
      return(540)
    }
    max(360, min(540, width * 0.85))
  }, res = 200)

  outputOptions(output, "radar_plot", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_page1", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_page2", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_page3", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_slider1", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_slider2", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_slider3", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_slider4", suspendWhenHidden = FALSE)
  outputOptions(output, "questionnaire_ui_free", suspendWhenHidden = FALSE)

  observeEvent(input$submit, {
    validation_error("")
    submission_status("")

    if (!isTRUE(input$consent)) {
      validation_error("Consent is required before continuing.")
      return()
    }

    items <- questionnaire_df()[questionnaire_df()$active == 1, ]
    required_items <- items[items$required == 1, ]

    missing <- c()
    for (i in seq_len(nrow(required_items))) {
      row <- required_items[i, ]
      id <- row$item_id
      value <- input[[id]]
      if (row$type == "sliderInput") {
        touched <- input[[paste0(id, "__touched")]]
        if (is.null(touched) || touched != 1) missing <- c(missing, id)
      } else if (row$type == "experience_tracer") {
        next
      } else if (is.null(value) || value == "") {
        missing <- c(missing, id)
      }
    }

    if (length(missing) > 0) {
      validation_error(paste0("Missing required items: ", paste(missing, collapse = ", ")))
      return()
    }

    # Filter out experience_tracer items (tracer is optional/experimental)
    items_no_tracer <- items[items$type != "experience_tracer", ]

    responses <- lapply(seq_len(nrow(items_no_tracer)), function(i) {
      row <- items_no_tracer[i, ]
      id <- row$item_id
      value <- input[[id]]
      list(
        item_id = id,
        type = row$type,
        value = value
      )
    })

    responses_df <- do.call(rbind, lapply(responses, function(x) {
      data.frame(
        item_id = x$item_id,
        type = x$type,
        value = ifelse(is.null(x$value), NA, x$value),
        stringsAsFactors = FALSE
      )
    }))

    numeric_types <- c("numericInput", "sliderInput")
    response_numeric <- responses_df[responses_df$type %in% numeric_types, ]
    response_numeric$value <- suppressWarnings(as.numeric(response_numeric$value))
    response_numeric <- response_numeric[!is.na(response_numeric$value), c("item_id", "value")]
    response_numeric$created_at <- Sys.time()

    response_text <- responses_df[!(responses_df$type %in% numeric_types), ]
    response_text <- response_text[!is.na(response_text$value) & response_text$value != "", c("item_id", "value")]
    response_text$created_at <- Sys.time()
    names(response_text) <- c("field_id", "text", "created_at")

    scales_df <- load_scales(file.path(root_dir, "docs/scales.csv"))
    scores_df <- compute_scores(response_numeric, scales_df)

    cfg <- get_config(required = FALSE)
    if (has_db_config(cfg)) {
      tryCatch({
        conn <- db_connect(cfg)
        on.exit(DBI::dbDisconnect(conn), add = TRUE)

        DBI::dbWithTransaction(conn, {
          # Schema auto-detects MariaDB vs Postgres variant
          db_init_schema(conn, file.path(root_dir, "sql/001_init.sql"))
          submission_id <- db_insert_submission(
            conn,
            list(
              instrument_id = instrument_id(),
              instrument_version = instrument_version(),
              language = language(),
              consent_version = "v1",
              definition_hash = definition_hash()
            )
          )
          db_insert_responses_numeric(conn, submission_id, response_numeric)
          db_insert_responses_text(conn, submission_id, response_text)
          db_insert_scores(conn, submission_id, scores_df)
        })

        submission_status("Submission stored successfully.")
      }, error = function(e) {
        message("Database error: ", conditionMessage(e))
        submission_status(paste0("Feedback generated (DB write failed: ", conditionMessage(e), ")"))
      })
    } else {
      submission_status("Feedback generated (DB not configured).")
    }

    latest_scores(scores_df)
    current_step(14)  # Go to feedback page (step 14)
    show_transition_busy()
  })

  # Navigate to optional Experience Tracer (Beta)
  observeEvent(input$try_tracer, {
    current_step(15)
    show_transition_busy()
  })

  # Return from tracer to feedback
  observeEvent(input$back_to_feedback, {
    current_step(14)
    show_transition_busy()
  })
}

shinyApp(ui, server)
