auth_google_sheets <- function(cfg) {
  if (!requireNamespace("googlesheets4", quietly = TRUE)) {
    stop("Package 'googlesheets4' is required for Google Sheets API loading.", call. = FALSE)
  }

  auth_json <- cfg$GOOGLE_SHEET_AUTH_JSON
  auth_email <- cfg$GOOGLE_SHEET_AUTH_EMAIL
  use_oauth <- tolower(cfg$GOOGLE_SHEET_USE_OAUTH) %in% c("1", "true", "yes")
  cache_path <- Sys.getenv("GARGLE_OAUTH_CACHE", unset = "")
  scopes <- "https://www.googleapis.com/auth/spreadsheets.readonly"

  # Auth flow aligned with shiny.quetzio usage (reference only).
  if (!is.null(auth_json) && auth_json != "") {
    if (!file.exists(auth_json)) {
      stop("GOOGLE_SHEET_AUTH_JSON does not exist: ", auth_json, call. = FALSE)
    }
    if (!is.null(auth_email) && auth_email != "") {
      googlesheets4::gs4_auth(path = auth_json, email = auth_email, scopes = scopes)
    } else {
      googlesheets4::gs4_auth(path = auth_json, scopes = scopes)
    }
  } else if (!is.null(auth_email) && auth_email != "") {
    googlesheets4::gs4_auth(email = auth_email, scopes = scopes)
  } else if (isTRUE(use_oauth)) {
    if (interactive()) {
      if (cache_path != "") {
        googlesheets4::gs4_auth(scopes = scopes, cache = cache_path)
      } else {
        googlesheets4::gs4_auth(scopes = scopes)
      }
    } else {
      if (cache_path != "") {
        auth_result <- try(googlesheets4::gs4_auth(cache = cache_path, scopes = scopes), silent = TRUE)
      } else {
        auth_result <- try(googlesheets4::gs4_auth(cache = TRUE, scopes = scopes), silent = TRUE)
      }
      if (inherits(auth_result, "try-error")) {
        stop(
          paste0(
            "OAuth requested but no cached token is available in non-interactive mode. ",
            "Run googlesheets4::gs4_auth() in an interactive R session once, ",
            "or configure GOOGLE_SHEET_AUTH_JSON for a service account."
          ),
          call. = FALSE
        )
      }
    }
  } else {
    googlesheets4::gs4_deauth()
  }
}

normalize_questionnaire_df <- function(df) {
  # Drop unnamed columns that can appear when Sheets has trailing blanks.
  if (ncol(df) > 0) {
    drop_cols <- names(df) == "" | grepl("^\\.\\.\\.[0-9]+$", names(df))
    if (any(drop_cols)) {
      df <- df[, !drop_cols, drop = FALSE]
    }
  }

  # Coerce list columns (from read_sheet) to character for hashing/validation.
  for (col in names(df)) {
    if (is.list(df[[col]])) {
      df[[col]] <- vapply(df[[col]], function(x) {
        if (length(x) == 0) "" else paste(as.character(x), collapse = ";")
      }, character(1))
    }
  }

  normalize_width <- function(x) {
    if (is.null(x)) return(x)
    if (is.numeric(x)) {
      ifelse(
        is.na(x),
        NA_character_,
        ifelse(
          x <= 1,
          paste0(x * 100, "%"),
          ifelse(x <= 100, paste0(x, "%"), paste0(x, "px"))
        )
      )
    } else if (is.character(x)) {
      trimmed <- trimws(x)
      num <- suppressWarnings(as.numeric(trimmed))
      ifelse(
        !is.na(num) & !grepl("%|px$", trimmed),
        ifelse(num <= 1, paste0(num * 100, "%"), ifelse(num <= 100, paste0(num, "%"), paste0(num, "px"))),
        trimmed
      )
    } else {
      as.character(x)
    }
  }

  coerce_bool_numeric <- function(x) {
    if (is.logical(x)) return(as.numeric(x))
    if (is.character(x)) {
      lower <- tolower(trimws(x))
      if (all(lower %in% c("", "na", "true", "false", "1", "0"))) {
        return(ifelse(lower %in% c("true", "1"), 1, ifelse(lower %in% c("false", "0"), 0, NA_real_)))
      }
    }
    suppressWarnings(as.numeric(x))
  }

  numeric_cols <- c(
    "required",
    "active",
    "order",
    "page",
    "section",
    "min",
    "max",
    "slider_min",
    "slider_max",
    "slider_value",
    "slider_step",
    "slider_ticks"
  )
  for (col in intersect(numeric_cols, names(df))) {
    if (col %in% c("required", "active", "slider_ticks")) {
      df[[col]] <- coerce_bool_numeric(df[[col]])
    } else {
      df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
    }
  }

  if ("width" %in% names(df)) {
    df$width <- normalize_width(df$width)
  }
  if ("placeholder" %in% names(df)) {
    df$placeholder <- as.character(df$placeholder)
  }
  if ("options" %in% names(df)) {
    df$options <- as.character(df$options)
  }

  df
}

load_questionnaire_from_sheet <- function(url) {
  if (is.null(url) || url == "") {
    stop("GOOGLE_SHEET_CSV_URL is empty.", call. = FALSE)
  }

  df <- readr::read_csv(url, show_col_types = FALSE, progress = FALSE)
  df <- normalize_questionnaire_df(df)
  validate_questionnaire_df(df)
  df
}

load_questionnaire_from_gsheet <- function(sheet_id, sheet_name, cfg) {
  if (is.null(sheet_id) || sheet_id == "" || is.null(sheet_name) || sheet_name == "") {
    stop("GOOGLE_SHEET_ID or GOOGLE_SHEET_SHEETNAME is empty.", call. = FALSE)
  }

  auth_google_sheets(cfg)
  df <- googlesheets4::read_sheet(ss = sheet_id, sheet = sheet_name)
  df <- normalize_questionnaire_df(df)
  validate_questionnaire_df(df)
  df
}

load_questionnaire_from_csv <- function(path) {
  df <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  df <- normalize_questionnaire_df(df)
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
