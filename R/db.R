db_connect <- function(cfg) {
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = cfg$STRATO_PG_HOST,
    dbname = cfg$STRATO_PG_DB,
    user = cfg$STRATO_PG_USER,
    password = cfg$STRATO_PG_PASSWORD,
    port = as.integer(cfg$STRATO_PG_PORT)
  )
}

db_init_schema <- function(conn, sql_path = "sql/001_init.sql") {
  sql <- readr::read_file(sql_path)
  DBI::dbExecute(conn, sql)
}

db_insert_submission <- function(conn, submission) {
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
  res$submission_id[1]
}

db_insert_responses_numeric <- function(conn, submission_id, responses_df) {
  if (nrow(responses_df) == 0) return(invisible(NULL))
  responses_df$submission_id <- submission_id
  DBI::dbWriteTable(conn, "response_numeric", responses_df, append = TRUE, row.names = FALSE)
}

db_insert_responses_text <- function(conn, submission_id, responses_df) {
  if (nrow(responses_df) == 0) return(invisible(NULL))
  responses_df$submission_id <- submission_id
  DBI::dbWriteTable(conn, "response_text", responses_df, append = TRUE, row.names = FALSE)
}

db_insert_scores <- function(conn, submission_id, scores_df) {
  if (nrow(scores_df) == 0) return(invisible(NULL))
  scores_df$submission_id <- submission_id
  DBI::dbWriteTable(conn, "score", scores_df, append = TRUE, row.names = FALSE)
}

db_read_norms <- function(conn, instrument_version) {
  DBI::dbGetQuery(
    conn,
    "SELECT * FROM aggregate_norms WHERE instrument_version = $1",
    params = list(instrument_version)
  )
}
