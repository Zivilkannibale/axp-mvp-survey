source("R/config.R")
source("R/questionnaire_loader.R")
source("R/db.R")
source("R/scoring.R")
source("R/plots.R")
source("R/quetzio/vendor_ui.R")

suppressPackageStartupMessages({
  library(shiny)
})

load_questionnaire <- function() {
  cfg <- get_config(required = FALSE)
  df <- NULL
  if (cfg$GOOGLE_SHEET_CSV_URL != "") {
    df <- try(load_questionnaire_from_sheet(cfg$GOOGLE_SHEET_CSV_URL), silent = TRUE)
    if (inherits(df, "try-error")) df <- NULL
  }

  if (is.null(df)) {
    df <- load_questionnaire_from_csv("docs/sample_questionnaire.csv")
  }

  df
}

questionnaire_df <- load_questionnaire()
definition_hash <- compute_definition_hash(questionnaire_df)

instrument_id <- questionnaire_df$instrument_id[1]
instrument_version <- questionnaire_df$instrument_version[1]
language <- questionnaire_df$language[1]

ui <- fluidPage(
  titlePanel("AXP MVP Survey"),
  tags$style(HTML(".error-text { color: #b00020; font-weight: 600; } .mandatory_star { color: #b00020; }")),
  fluidRow(
    column(
      8,
      h3("Consent"),
      checkboxInput("consent", "I agree to participate.", value = FALSE),
      hr(),
      h3("Questionnaire"),
      uiOutput("questionnaire_ui"),
      div(class = "error-text", textOutput("validation_error")),
      actionButton("submit", "Submit")
    ),
    column(
      4,
      h3("Feedback"),
      plotOutput("radar_plot", height = "300px"),
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
    if (nrow(scores) == 0) return(NULL)

    cfg <- get_config(required = FALSE)
    if (!has_db_config(cfg)) return(NULL)

    conn <- db_connect(cfg)
    on.exit(DBI::dbDisconnect(conn), add = TRUE)

    norms <- db_read_norms(conn, instrument_version)
    if (nrow(norms) == 0) return(NULL)

    plot_scores_radar(scores, norms)
  })

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

    scales_df <- load_scales("docs/scales.csv")
    scores_df <- compute_scores(response_numeric, scales_df)

    cfg <- get_config(required = FALSE)
    if (has_db_config(cfg)) {
      conn <- db_connect(cfg)
      on.exit(DBI::dbDisconnect(conn), add = TRUE)

      DBI::dbWithTransaction(conn, {
        db_init_schema(conn)
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
