# -----------------------------------------------------------------------------
# Database connector supporting MariaDB (primary) and PostgreSQL (legacy)
# -----------------------------------------------------------------------------
# Environment variables:
#   DB_DIALECT     - "mariadb" (default) or "postgres"
#   DB_HOST        - Database hostname
#   DB_PORT        - Database port (3306 for MariaDB, 5432 for Postgres)
#   DB_NAME        - Database name
#   DB_USER        - Database username
#   DB_PASSWORD    - Database password (NEVER log this)
#   DB_TLS         - "1" to enable TLS (recommended for MariaDB)
#   DB_TLS_VERIFY  - "1" to verify server certificate
#   DB_TLS_CA_PATH - Path to CA certificate (optional; uses system CA if blank)
#
# Legacy Postgres env vars (still supported for backward compatibility):
#   STRATO_PG_HOST, STRATO_PG_DB, STRATO_PG_USER, STRATO_PG_PASSWORD, STRATO_PG_PORT
# -----------------------------------------------------------------------------

#' Determine database dialect from environment
#' @return "mariadb" or "postgres"
get_db_dialect <- function() {

  dialect <- Sys.getenv("DB_DIALECT", "")
  if (dialect != "") {
    return(tolower(dialect))
  }
  # Legacy: if STRATO_PG_* vars are set but DB_* are not, assume postgres

  if (Sys.getenv("STRATO_PG_HOST", "") != "" && Sys.getenv("DB_HOST", "") == "") {
    return("postgres")
  }
  "mariadb"  # Default to MariaDB
}

#' Create database connection
#' @param cfg Configuration list from get_config()
#' @return DBI connection object
db_connect <- function(cfg) {
  dialect <- get_db_dialect()
  

  if (dialect == "mariadb") {
    db_connect_mariadb(cfg)
  } else {
    db_connect_postgres(cfg)
  }
}

#' Connect to MariaDB
#' @param cfg Configuration list
#' @return DBI connection to MariaDB
db_connect_mariadb <- function(cfg) {
  if (!requireNamespace("RMariaDB", quietly = TRUE)) {
    stop("RMariaDB package is required for MariaDB connections. Install with: install.packages('RMariaDB')", call. = FALSE)
  }
  
  host <- cfg$DB_HOST
  port <- as.integer(cfg$DB_PORT)
  dbname <- cfg$DB_NAME
  user <- cfg$DB_USER
  password <- cfg$DB_PASSWORD
  
  # Validate required parameters
  missing <- c()
  if (is.null(host) || host == "") missing <- c(missing, "DB_HOST")
  if (is.null(dbname) || dbname == "") missing <- c(missing, "DB_NAME")
  if (is.null(user) || user == "") missing <- c(missing, "DB_USER")
  if (is.null(password) || password == "") missing <- c(missing, "DB_PASSWORD")
  
  if (length(missing) > 0) {
    stop(paste0(
      "Missing required MariaDB environment variables: ", paste(missing, collapse = ", "),
      "\nSet these in app/.Renviron on the server."
    ), call. = FALSE)
  }
  
  if (is.na(port) || port == 0) port <- 3306L
  
  # TLS configuration
  tls_enabled <- tolower(cfg$DB_TLS) %in% c("1", "true", "yes")
  tls_verify <- tolower(cfg$DB_TLS_VERIFY) %in% c("1", "true", "yes")
  tls_ca_path <- cfg$DB_TLS_CA_PATH
  
  # Build connection arguments
  conn_args <- list(
    drv = RMariaDB::MariaDB(),
    host = host,
    port = port,
    dbname = dbname,
    user = user,
    password = password
  )
  
  # Add TLS options if enabled
  # RMariaDB uses ssl.* parameters or mysql_ssl_set() options

  if (tls_enabled) {
    # ssl = TRUE enables TLS with system CA
    conn_args$ssl <- TRUE
    
    # If a custom CA path is provided, use it
    if (!is.null(tls_ca_path) && tls_ca_path != "") {
      conn_args$ssl.ca <- tls_ca_path
    }
    
    # Note: ssl verification is typically controlled by the CA trust chain
    # RMariaDB doesn't have a direct ssl_verify parameter; verification happens

    # automatically when ssl=TRUE and a valid CA is available
  }
  
  tryCatch({
    do.call(DBI::dbConnect, conn_args)
  }, error = function(e) {
    # Sanitize error message to avoid leaking password
    msg <- conditionMessage(e)
    msg <- gsub(password, "[REDACTED]", msg, fixed = TRUE)
    stop(paste0("MariaDB connection failed: ", msg), call. = FALSE)
  })
}

#' Connect to PostgreSQL (legacy)
#' @param cfg Configuration list
#' @return DBI connection to PostgreSQL
db_connect_postgres <- function(cfg) {
  if (!requireNamespace("RPostgres", quietly = TRUE)) {
    stop("RPostgres package is required for PostgreSQL connections. Install with: install.packages('RPostgres')", call. = FALSE)
  }
  
  # Support both new DB_* and legacy STRATO_PG_* variables
  host <- if (cfg$DB_HOST != "") cfg$DB_HOST else cfg$STRATO_PG_HOST
  port <- if (cfg$DB_PORT != "") cfg$DB_PORT else cfg$STRATO_PG_PORT
  dbname <- if (cfg$DB_NAME != "") cfg$DB_NAME else cfg$STRATO_PG_DB
  user <- if (cfg$DB_USER != "") cfg$DB_USER else cfg$STRATO_PG_USER
  password <- if (cfg$DB_PASSWORD != "") cfg$DB_PASSWORD else cfg$STRATO_PG_PASSWORD
  
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = host,
    dbname = dbname,
    user = user,
    password = password,
    port = as.integer(port)
  )
}

db_init_schema <- function(conn, sql_path = "sql/001_init.sql") {
  dialect <- get_db_dialect()
  
  # Choose the appropriate schema file based on dialect
  if (dialect == "mariadb") {
    mariadb_path <- sub("\\.sql$", "_mariadb.sql", sql_path)
    if (file.exists(mariadb_path)) {
      sql_path <- mariadb_path
    }
  }
  
  sql <- readr::read_file(sql_path)
  
  # MariaDB: execute statements one at a time (doesn't support multiple statements in one call reliably)
  if (dialect == "mariadb") {
    # Split by semicolon, handling potential edge cases
    statements <- strsplit(sql, ";\\s*(?=\\S)", perl = TRUE)[[1]]
    statements <- trimws(statements)
    statements <- statements[statements != ""]
    
    for (stmt in statements) {
      if (nchar(trimws(stmt)) > 0) {
        tryCatch({
          DBI::dbExecute(conn, stmt)
        }, error = function(e) {
          # Ignore "table already exists" type errors for idempotent schema init
          if (!grepl("already exists|Duplicate", conditionMessage(e), ignore.case = TRUE)) {
            warning("Schema statement failed: ", conditionMessage(e))
          }
        })
      }
    }
    invisible(NULL)
  } else {
    DBI::dbExecute(conn, sql)
  }
}

db_insert_submission <- function(conn, submission) {
  dialect <- get_db_dialect()
  
  if (dialect == "mariadb") {
    # MariaDB: use ? placeholders and UUID() function or generate UUID in R
    submission_id <- uuid::UUIDgenerate()
    
    sql <- paste0(
      "INSERT INTO submission (submission_id, created_at, instrument_id, instrument_version, language, consent_version, definition_hash) ",
      "VALUES (?, NOW(), ?, ?, ?, ?, ?)"
    )
    
    DBI::dbExecute(
      conn,
      sql,
      params = list(
        submission_id,
        submission$instrument_id,
        submission$instrument_version,
        submission$language,
        submission$consent_version,
        submission$definition_hash
      )
    )
    return(submission_id)
  } else {
    # PostgreSQL: use $N placeholders and RETURNING
    sql <- paste0(
      "INSERT INTO submission (created_at, instrument_id, instrument_version, language, consent_version, definition_hash) ",
      "VALUES (NOW(), $1, $2, $3, $4, $5) RETURNING submission_id"
    )
    res <- DBI::dbGetQuery(
      conn,
      sql,
      params = list(
        submission$instrument_id,
        submission$instrument_version,
        submission$language,
        submission$consent_version,
        submission$definition_hash
      )
    )
    return(res$submission_id[1])
  }
}

db_insert_responses_numeric <- function(conn, submission_id, responses_df) {
  if (nrow(responses_df) == 0) return(invisible(NULL))
  responses_df$submission_id <- submission_id
  DBI::dbWriteTable(conn, "response_numeric", responses_df, append = TRUE, row.names = FALSE)
}

db_insert_responses_text <- function(conn, submission_id, responses_df) {
  if (nrow(responses_df) == 0) return(invisible(NULL))
  
  # Limit free-text length to reduce risk (max 10k chars)
  max_text_len <- 10000L
  if ("text" %in% names(responses_df)) {
    responses_df$text <- substr(responses_df$text, 1, max_text_len)
  }
  
  responses_df$submission_id <- submission_id
  DBI::dbWriteTable(conn, "response_text", responses_df, append = TRUE, row.names = FALSE)
}

db_insert_scores <- function(conn, submission_id, scores_df) {
  if (nrow(scores_df) == 0) return(invisible(NULL))
  scores_df$submission_id <- submission_id
  DBI::dbWriteTable(conn, "score", scores_df, append = TRUE, row.names = FALSE)
}

db_read_norms <- function(conn, instrument_version) {
  dialect <- get_db_dialect()
  
  if (dialect == "mariadb") {
    DBI::dbGetQuery(
      conn,
      "SELECT * FROM aggregate_norms WHERE instrument_version = ?",
      params = list(instrument_version)
    )
  } else {
    DBI::dbGetQuery(
      conn,
      "SELECT * FROM aggregate_norms WHERE instrument_version = $1",
      params = list(instrument_version)
    )
  }
}

# -----------------------------------------------------------------------------
# Export helpers (for export_public.R)
# -----------------------------------------------------------------------------

#' Read all submissions for export
#' @param conn DBI connection
#' @return data.frame of submissions
db_read_submissions <- function(conn) {
  DBI::dbGetQuery(conn, "SELECT submission_id, created_at, instrument_id, instrument_version, language, definition_hash FROM submission")
}

#' Read all numeric responses for export
#' @param conn DBI connection
#' @return data.frame of numeric responses
db_read_responses_numeric <- function(conn) {
  DBI::dbGetQuery(conn, "SELECT submission_id, item_id, value FROM response_numeric")
}

#' Read all scores for export
#' @param conn DBI connection
#' @return data.frame of scores
db_read_scores <- function(conn) {
  DBI::dbGetQuery(conn, "SELECT submission_id, scale_id, score_value FROM score")
}
