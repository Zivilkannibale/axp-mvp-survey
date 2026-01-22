#!/usr/bin/env Rscript

source("R/config.R")
source("R/db.R")

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
})

cfg <- get_config(required = TRUE)
if (!has_db_config(cfg)) {
  stop("Database configuration is incomplete.", call. = FALSE)
}

conn <- db_connect(cfg)
on.exit(DBI::dbDisconnect(conn), add = TRUE)

db_init_schema(conn)

scores <- DBI::dbGetQuery(conn, "SELECT submission_id, scale_id, score_value FROM score")
submissions <- DBI::dbGetQuery(conn, "SELECT submission_id, instrument_version FROM submission")

scores <- scores %>%
  inner_join(submissions, by = "submission_id")

if (nrow(scores) == 0) {
  message("No scores found; skipping norms update.")
  quit(status = 0)
}

norms <- scores %>%
  group_by(instrument_version, scale_id) %>%
  summarise(
    n = n(),
    mean = mean(score_value, na.rm = TRUE),
    sd = sd(score_value, na.rm = TRUE),
    p05 = quantile(score_value, 0.05, na.rm = TRUE),
    p50 = quantile(score_value, 0.50, na.rm = TRUE),
    p95 = quantile(score_value, 0.95, na.rm = TRUE),
    .groups = "drop"
  )

for (i in seq_len(nrow(norms))) {
  row <- norms[i, ]
  DBI::dbExecute(
    conn,
    "DELETE FROM aggregate_norms WHERE instrument_version = $1 AND scale_id = $2",
    params = list(row$instrument_version, row$scale_id)
  )
}

DBI::dbWriteTable(conn, "aggregate_norms", norms, append = TRUE, row.names = FALSE)
message("Norms updated.")
