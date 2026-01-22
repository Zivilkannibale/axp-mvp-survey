get_config <- function(required = TRUE) {
  names <- c(
    "GOOGLE_SHEET_CSV_URL",
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

  missing <- names[cfg == ""]
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
