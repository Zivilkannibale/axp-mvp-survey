get_config <- function(required = TRUE) {
  names <- c(
    "GOOGLE_SHEET_CSV_URL",
    "GOOGLE_SHEET_ID",
    "GOOGLE_SHEET_SHEETNAME",
    "GOOGLE_SHEET_AUTH_JSON",
    "GOOGLE_SHEET_AUTH_EMAIL",
    "GOOGLE_SHEET_USE_OAUTH",
    "STRATO_PG_HOST",
    "STRATO_PG_DB",
    "STRATO_PG_USER",
    "STRATO_PG_PASSWORD",
    "STRATO_PG_PORT",
    "OSF_PROJECT_ID",
    "OSF_TOKEN",
    "APP_BASE_URL"
  )

  values <- lapply(names, function(nm) Sys.getenv(nm, unset = ""))
  cfg <- setNames(values, names)

  optional <- c(
    "GOOGLE_SHEET_CSV_URL",
    "GOOGLE_SHEET_ID",
    "GOOGLE_SHEET_SHEETNAME",
    "GOOGLE_SHEET_AUTH_JSON",
    "GOOGLE_SHEET_AUTH_EMAIL",
    "GOOGLE_SHEET_USE_OAUTH"
  )
  missing <- setdiff(names[cfg == ""], optional)
  if (required && length(missing) > 0) {
    stop(
      paste0(
        "Missing required environment variables: ",
        paste(missing, collapse = ", "),
        "\nUse config/.env.example as a template and load into your environment."
      ),
      call. = FALSE
    )
  }

  cfg
}

has_db_config <- function(cfg) {
  required <- c("STRATO_PG_HOST", "STRATO_PG_DB", "STRATO_PG_USER", "STRATO_PG_PASSWORD", "STRATO_PG_PORT")
  all(cfg[required] != "")
}
