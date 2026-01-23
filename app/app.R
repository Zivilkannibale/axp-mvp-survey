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

load_questionnaire <- function() {
  cfg <- get_config(required = FALSE)
  df <- NULL
  if (cfg$GOOGLE_SHEET_ID != "" && cfg$GOOGLE_SHEET_SHEETNAME != "") {
    df <- try(load_questionnaire_from_gsheet(cfg$GOOGLE_SHEET_ID, cfg$GOOGLE_SHEET_SHEETNAME, cfg), silent = TRUE)
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

questionnaire_df <- load_questionnaire()
definition_hash <- compute_definition_hash(questionnaire_df)

instrument_id <- questionnaire_df$instrument_id[1]
instrument_version <- questionnaire_df$instrument_version[1]
language <- questionnaire_df$language[1]

ui <- fluidPage(
  tags$head(
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = "anonymous"),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600&family=Space+Grotesk:wght@500;600&display=swap"
    ),
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
      body { background: var(--bg); color: var(--text); font-family: var(--font-body); }
      h1, h2, h3 { font-family: var(--font-head); letter-spacing: -0.01em; }
      .app-shell { max-width: 720px; margin: 0 auto; padding: 28px 20px 48px; }
      .app-eyebrow { text-transform: uppercase; font-size: 12px; letter-spacing: 0.12em; color: var(--muted); margin-bottom: 6px; }
      .app-title { font-size: 28px; margin: 8px 0 12px; }
      .app-card { background: var(--card); border: 1px solid var(--border); border-radius: var(--radius); padding: 22px; margin-bottom: 18px; box-shadow: 0 8px 24px rgba(25, 22, 70, 0.06); }
      .app-card h3 { margin-top: 0; font-size: 18px; }
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
    "))
  ),
  div(
    class = "app-shell",
    div(class = "app-eyebrow", "AXP survey"),
    div(class = "app-title", "Participant Questionnaire"),
    div(
      class = "app-card",
      h3("Consent"),
      checkboxInput("consent", "I agree to participate.", value = FALSE)
    ),
    div(
      class = "app-card",
      h3("Questions"),
      uiOutput("questionnaire_ui"),
      div(class = "error-text", textOutput("validation_error")),
      actionButton("submit", "Submit")
    ),
    div(
      class = "app-card",
      h3("Feedback"),
      plotOutput("radar_plot", height = "540px", width = "100%"),
      verbatimTextOutput("submission_status")
    )
  )
)

server <- function(input, output, session) {
  output$questionnaire_ui <- renderUI({
    questionnaire_ui_vendor(questionnaire_df)
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

  observeEvent(input$submit, {
    validation_error("")
    submission_status("")

    if (!isTRUE(input$consent)) {
      validation_error("Consent is required before continuing.")
      return()
    }

    items <- questionnaire_df[questionnaire_df$active == 1, ]
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
            instrument_id = instrument_id,
            instrument_version = instrument_version,
            language = language,
            consent_version = "v1",
            definition_hash = definition_hash
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
