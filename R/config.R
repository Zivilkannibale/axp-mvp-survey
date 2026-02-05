get_config <- function(required = TRUE) {
  names <- c(
    "GOOGLE_SHEET_CSV_URL",
    "GOOGLE_SHEET_ID",
    "GOOGLE_SHEET_SHEETNAME",
    "GOOGLE_SHEET_AUTH_JSON",
    "GOOGLE_SHEET_AUTH_EMAIL",
    "GOOGLE_SHEET_USE_OAUTH",
    # DB_* variables (MariaDB)
    "DB_HOST",
    "DB_PORT",
    "DB_NAME",
    "DB_USER",
    "DB_PASSWORD",
    "DB_TLS",
    "DB_TLS_VERIFY",
    "DB_TLS_CA_PATH",
    # OSF export
    "OSF_PROJECT_ID",
    "OSF_TOKEN",
    # App settings
    "APP_BASE_URL",
    "P6M_ENABLED",
    "P6M_ANIMATED",
    "DEV_MODE"
  )

  values <- lapply(names, function(nm) Sys.getenv(nm, unset = ""))
  cfg <- setNames(values, names)

  optional <- c(
    "GOOGLE_SHEET_CSV_URL",
    "GOOGLE_SHEET_ID",
    "GOOGLE_SHEET_SHEETNAME",
    "GOOGLE_SHEET_AUTH_JSON",
    "GOOGLE_SHEET_AUTH_EMAIL",
    "GOOGLE_SHEET_USE_OAUTH",
    # DB vars are optional (app works without DB)
    "DB_HOST",
    "DB_PORT",
    "DB_NAME",
    "DB_USER",
    "DB_PASSWORD",
    "DB_TLS",
    "DB_TLS_VERIFY",
    "DB_TLS_CA_PATH",
    "OSF_PROJECT_ID",
    "OSF_TOKEN",
    "P6M_ENABLED",
    "P6M_ANIMATED",
    "DEV_MODE"
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

#' Check if database config is available
#' @param cfg Configuration list from get_config()
#' @return TRUE if sufficient DB config is present
has_db_config <- function(cfg) {
  new_vars <- c("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD")
  all(cfg[new_vars] != "")
}
