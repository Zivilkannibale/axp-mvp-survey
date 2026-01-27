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
source(file.path(root_dir, "R/quetzio/vendor_ui.R"))

suppressPackageStartupMessages({
  library(shiny)
})

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
P6M_ENABLED <- env_flag(cfg_ui$P6M_ENABLED, TRUE)
P6M_ANIMATED_DEFAULT <- env_flag(cfg_ui$P6M_ANIMATED, TRUE)

ui <- fluidPage(
  tags$head(
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = "anonymous"),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600&family=Space+Grotesk:wght@500;600&family=Press+Start+2P&display=swap"
    ),
    tags$link(rel = "preload", href = "circe-logo.png", as = "image"),
    if (!P6M_ENABLED) tags$link(rel = "preload", href = "circe-bg.png", as = "image"),
    if (P6M_ENABLED) tags$link(rel = "preload", href = "p6m-bg.js", as = "script"),
    if (P6M_ENABLED) tags$script(src = "p6m-bg.js", defer = "defer"),
    tags$style(HTML("
      :root {
        --accent: #6b3df0;
        --accent-soft: #f0ecff;
        --text: #262632;
        --muted: #7b7f8c;
        --border: #e6e7eb;
        --bg: #f9f9fb;
        --card: #ffffff;
        --radius: 20px;
        --font-body: 'Manrope', 'Segoe UI', sans-serif;
        --font-head: 'Space Grotesk', 'Segoe UI', sans-serif;
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
      .app-shell { position: relative; z-index: 1; max-width: 720px; margin: 0 auto; padding: 28px 20px 48px; }
      .app-logo { display: block; width: 120px; height: auto; margin: 0 0 12px; }
      .app-eyebrow { text-transform: uppercase; font-size: 16px; letter-spacing: 0.18em; color: #000000; font-weight: 700; margin: -4px 0 6px; }
      .app-title { font-size: 28px; margin: 8px 0 12px; }
      .app-card { background: var(--card); border: 1px solid var(--border); border-radius: var(--radius); padding: 22px; margin-bottom: 18px; box-shadow: 0 8px 24px rgba(25, 22, 70, 0.06); }
      .app-card h3 { margin-top: 0; font-size: 18px; }
      .muted { color: var(--muted); font-size: 12px; margin-top: 6px; }
      .error-text { color: #b00020; font-weight: 600; margin-top: 10px; }
      .mandatory_star { color: var(--accent); margin-left: 4px; }
      .quetzio-question { padding: 14px 0 18px; border-bottom: 1px solid var(--border); }
      .quetzio-question:last-child { border-bottom: none; }
      .quetzio-question label { font-size: 18px; font-weight: 500; color: var(--text); }
      .form-control, .selectize-input { border-radius: 999px; border: 1px solid var(--border); box-shadow: none; }
      textarea.form-control { border-radius: 16px; }
      .radio { margin: 10px 0; }
      .radio input { display: none; }
      .radio label { display: block; padding: 12px 16px; border: 1px solid var(--border); border-radius: 999px; color: var(--text); background: #fff; font-weight: 500; }
      .radio label:has(input:checked) { border-color: var(--accent); color: var(--accent); background: var(--accent-soft); }
      #submit { border-radius: 999px; border: 1px solid var(--accent); color: var(--accent); background: #fff; padding: 10px 22px; font-weight: 600; }
      #submit:hover { background: var(--accent-soft); }
      .slider-labels { display: flex; justify-content: space-between; font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); margin-top: 6px; }
      .shiny-input-container { width: 100%; max-width: 100%; }
      .irs { width: 100%; margin: 0; }
      .irs--shiny { height: 56px; }
      .irs--shiny .irs-line { height: 6px; top: 28px; background: var(--slider-track) !important; border: none; border-radius: 999px; }
      .irs--shiny .irs-bar { height: 6px; top: 28px; background: var(--slider-accent) !important; border: none; border-radius: 999px; }
      .irs--shiny .irs-bar-edge { height: 6px; top: 28px; background: var(--slider-accent) !important; border: none; border-radius: 999px; }
      .irs--shiny .irs-handle { top: 17px; width: 22px; height: 22px; border: 2px solid var(--slider-accent) !important; background: #fff !important; box-shadow: 0 2px 6px rgba(30, 20, 70, 0.15); border-radius: 999px; }
      .irs--shiny .irs-slider { border: 2px solid var(--slider-accent) !important; background: #fff !important; }
      .irs--shiny .irs-single { display: none; }
      .irs--shiny .irs-min, .irs--shiny .irs-max { display: none; }
      .irs--shiny .irs-grid, .irs--shiny .irs-grid-text { display: none; }
      .nav-actions { display: flex; gap: 12px; margin-top: 18px; }
      .nav-actions .btn { border-radius: 999px; padding: 8px 20px; font-weight: 600; }
      .boot-overlay, .busy-overlay {
        position: fixed;
        inset: 0;
        z-index: 9999;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #000000;
        color: #9bff6a;
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
        border: 1px solid rgba(155, 255, 106, 0.5);
        border-radius: 16px;
        background: rgba(4, 6, 8, 0.85);
        padding: 18px 20px 16px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.45);
      }
      .boot-title { font-size: 10px; text-transform: uppercase; color: #6bdc58; }
      .boot-lines { display: none; }
      .boot-progress {
        height: 6px;
        border-radius: 999px;
        background: rgba(100, 255, 120, 0.18);
        overflow: hidden;
      }
      .boot-progress span {
        display: block;
        height: 100%;
        width: 10%;
        background: linear-gradient(90deg, #66ff7a, #c6ff8f);
        transition: width 240ms ease;
      }
      .boot-foot { margin-top: 12px; font-size: 10px; color: #6bdc58; }
      .boot-quip {
        font-size: 13px;
        line-height: 1.6;
        color: #9bff6a;
        letter-spacing: 0.06em;
        font-weight: 600;
        margin-top: 14px;
        text-shadow: 0 0 8px rgba(155, 255, 106, 0.25);
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
    "))
    ,
    tags$script(HTML(sprintf("
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
        var p6mEnabled = %s;

        function hideBoot() {
          if (bootHidden) return;
          bootHidden = true;
          if (boot) boot.classList.add('hidden');
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
          boot = document.getElementById('boot-overlay');
          busy = document.getElementById('busy-overlay');
          bootBar = document.getElementById('boot-progress-bar');
          bootPct = document.getElementById('boot-progress-pct');

          var assets = ['circe-logo.png'];
          if (p6mEnabled) {
            assets.push('p6m-bg.js');
          } else {
            assets.push('circe-bg.png');
          }
          assets.forEach(function(src) {
            var link = document.createElement('link');
            link.rel = 'preload';
            link.as = src.endsWith('.js') ? 'script' : 'image';
            link.href = src;
            document.head.appendChild(link);
          });

          if (boot) boot.classList.remove('hidden');
          if (busy) busy.classList.add('hidden');

          // Failsafe in case Shiny events don't fire
          bootTimeout = setTimeout(function() {
            setBootProgress(100);
          }, 4000);
          bootLoop();
          setBootProgress(12);
        });

        document.addEventListener('shiny:connected', function() {
          setBootProgress(55);
        });

        document.addEventListener('shiny:busy', function() {
          showBusy();
        });

        document.addEventListener('shiny:idle', function() {
          hideBusy();
        });

        if (window.Shiny) {
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

          Shiny.addCustomMessageHandler('bootReady', function() {
            if (bootTimeout) clearTimeout(bootTimeout);
            waitForUIAndFonts(function() {
              setBootProgress(100);
            });
          });
          Shiny.addCustomMessageHandler('bootProgress', function(msg) {
            setBootProgress(msg.pct || 0);
          });
          Shiny.addCustomMessageHandler('busyShow', function() {
            if (busy) busy.classList.remove('hidden');
          });
          Shiny.addCustomMessageHandler('busyHide', function() {
            if (busy) busy.classList.add('hidden');
          });
        }
      })();
    ", ifelse(P6M_ENABLED, "true", "false")))),
    if (!P6M_ENABLED) tags$style(HTML("
      body {
        background-image: url('circe-bg.png');
        background-repeat: no-repeat;
        background-position: center;
        background-size: cover;
        background-attachment: fixed;
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
  if (P6M_ENABLED) div(id = "p6m-layer"),
  div(
    class = "app-shell",
    tags$img(src = "circe-logo.png", alt = "Circe logo", class = "app-logo"),
    div(class = "app-eyebrow", "AXP survey"),
    div(class = "app-title", "Participant Questionnaire"),
    uiOutput("page_ui")
  )
)

server <- function(input, output, session) {
  cfg <- get_config(required = FALSE)
  boot_progress <- function(pct) {
    session$sendCustomMessage("bootProgress", list(pct = pct))
  }
  boot_progress(10)

  format_load_status <- function(sheet_name, is_error = FALSE, message = NULL) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    if (is_error) {
      return(paste0("Load failed at ", timestamp, ": ", message))
    }
    if (is.null(sheet_name) || sheet_name == "") {
      return(paste0("Loaded at ", timestamp, " from configured sheet tab."))
    }
    paste0("Loaded at ", timestamp, " from sheet tab: ", sheet_name)
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

  observeEvent(input$reload_questionnaire, {
    sheet_name <- if (is.null(input$sheet_name_override)) "" else trimws(input$sheet_name_override)
    update_questionnaire(sheet_name_override = sheet_name)
  })

  output$load_status <- renderText(load_status())

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

  observeEvent(input$next_step, {
    step <- current_step()
    if (step == 1) {
      navigation_error("")
      current_step(2)
      show_transition_busy()
    } else if (step == 2) {
      if (!isTRUE(input$consent)) {
        navigation_error("Consent is required before continuing.")
      } else {
        navigation_error("")
        current_step(3)
        show_transition_busy()
      }
    } else if (step == 3) {
      navigation_error("")
      current_step(4)
      show_transition_busy()
    }
  })

  observeEvent(input$prev_step, {
    step <- current_step()
    if (step > 1) {
      navigation_error("")
      current_step(step - 1)
      show_transition_busy()
    }
  })

  output$page_ui <- renderUI({
    step <- current_step()

    if (step == 1) {
      return(tagList(
        div(
          class = "app-card",
          h3("Introduction"),
          p("Use this page to reload the questionnaire and select a specific sheet tab."),
          if (P6M_ENABLED) checkboxInput("animated_bg", "Animated p6m waves", value = P6M_ANIMATED_DEFAULT),
          textInput("sheet_name_override", "Sheet tab (optional)", value = ""),
          actionButton("reload_questionnaire", "Reload questionnaire"),
          div(class = "muted", textOutput("load_status"))
        ),
        div(
          class = "nav-actions",
          actionButton("next_step", "Continue")
        )
      ))
    }

    if (step == 2) {
      return(tagList(
        div(
          class = "app-card",
          h3("Consent"),
          checkboxInput("consent", "I agree to participate.", value = FALSE),
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
          h3("Questions"),
          uiOutput("questionnaire_ui"),
          div(class = "error-text", textOutput("validation_error")),
          actionButton("submit", "Submit")
        ),
        div(
          class = "nav-actions",
          actionButton("prev_step", "Back"),
          actionButton("next_step", "Continue")
        )
      ))
    }

    tagList(
      div(
        class = "app-card",
        h3("Feedback"),
        div(id = "feedback_loading", class = "muted", "Preparing feedback..."),
        plotOutput("radar_plot", height = "540px", width = "100%"),
        verbatimTextOutput("submission_status")
      ),
      div(
        class = "nav-actions",
        actionButton("prev_step", "Back")
      )
    )
  })

  output$navigation_error <- renderText(navigation_error())

  questionnaire_ui_cached <- reactiveVal(NULL)
  observeEvent(questionnaire_df(), {
    questionnaire_ui_cached(questionnaire_ui_vendor(questionnaire_df()))
  }, ignoreInit = FALSE)

  output$questionnaire_ui <- renderUI({
    cached <- questionnaire_ui_cached()
    if (is.null(cached)) {
      div(class = "muted", "Loading questions...")
    } else {
      cached
    }
  })

  validation_error <- reactiveVal("")
  submission_status <- reactiveVal("")
  latest_scores <- reactiveVal(data.frame())

  output$validation_error <- renderText(validation_error())
  output$submission_status <- renderText(submission_status())

    output$radar_plot <- renderPlot({
      scores <- latest_scores()

      if (nrow(scores) == 0) {
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
        scores <- data.frame(
          scale_id = mock_scales,
          score_value = c(68, 52, 72, 60, 38, 44, 32, 55, 48, 41, 64),
          stringsAsFactors = FALSE
        )
      }

      set.seed(42)
      peer_points <- data.frame(
        scale_id = rep(scores$scale_id, each = 28),
        value = pmin(100, pmax(0, rnorm(length(scores$scale_id) * 28, mean = 55, sd = 18))),
        stringsAsFactors = FALSE
      )

      p <- plot_scores_radar(scores, peer_points_df = peer_points)
      if (!is.null(p)) print(p)
    }, height = 540, res = 120, antialias = "default")

  outputOptions(output, "radar_plot", suspendWhenHidden = TRUE)
  outputOptions(output, "questionnaire_ui", suspendWhenHidden = FALSE)

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
      } else if (is.null(value) || value == "") {
        missing <- c(missing, id)
      }
    }

    if (length(missing) > 0) {
      validation_error(paste0("Missing required items: ", paste(missing, collapse = ", ")))
      return()
    }

    responses <- lapply(seq_len(nrow(items)), function(i) {
      row <- items[i, ]
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
      conn <- db_connect(cfg)
      on.exit(DBI::dbDisconnect(conn), add = TRUE)

      DBI::dbWithTransaction(conn, {
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
    } else {
      submission_status("Submission received locally (DB not configured).")
    }

    latest_scores(scores_df)
  })
}

shinyApp(ui, server)
