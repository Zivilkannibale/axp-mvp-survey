load_questionnaire_from_sheet <- function(url) {
  if (is.null(url) || url == "") {
    stop("GOOGLE_SHEET_CSV_URL is empty.", call. = FALSE)
  }

  df <- readr::read_csv(url, show_col_types = FALSE, progress = FALSE)
  validate_questionnaire_df(df)
  df
}

load_questionnaire_from_csv <- function(path) {
  df <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  validate_questionnaire_df(df)
  df
}

validate_questionnaire_df <- function(df) {
  required_cols <- c(
    "instrument_id",
    "instrument_version",
    "language",
    "item_id",
    "type",
    "label",
    "required",
    "active",
    "order",
    "page",
    "section"
  )

  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(
      paste0(
        "Questionnaire is missing required columns: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  df
}

compute_definition_hash <- function(df) {
  normalized <- df[, order(names(df))]
  csv_text <- paste(capture.output(utils::write.csv(normalized, row.names = FALSE)), collapse = "\n")
  digest::digest(csv_text, algo = "sha256")
}
