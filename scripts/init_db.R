#!/usr/bin/env Rscript
# Initialize database schema
# Run this once after setting up DB_* environment variables
#
# Usage:
#   Rscript scripts/init_db.R
#   # or in R:
#   source("scripts/init_db.R")

source("R/config.R")
source("R/db.R")

suppressPackageStartupMessages({
  library(DBI)
})

cfg <- get_config(required = FALSE)

if (!has_db_config(cfg)) {
  message("Database configuration not found.")
  message("Set DB_* environment variables in app/.Renviron:")
  message("  DB_DIALECT=mariadb")
  message("  DB_HOST=database-5019530911.webspace-host.com")
  message("  DB_PORT=3306")
  message("  DB_NAME=dbs15265782")
  message("  DB_USER=dbu4550099")
  message("  DB_PASSWORD=<your_password>")
  message("  DB_TLS=1")
  quit(status = 1)
}

dialect <- get_db_dialect()
message("Connecting to ", dialect, " database...")

conn <- tryCatch({
  db_connect(cfg)
}, error = function(e) {
  message("Connection failed: ", conditionMessage(e))
  quit(status = 1)
})

on.exit(DBI::dbDisconnect(conn), add = TRUE)

message("Connection successful!")

# Determine schema file path
if (dialect == "mariadb") {
  sql_path <- "sql/001_init_mariadb.sql"
} else {
  sql_path <- "sql/001_init.sql"
}

if (!file.exists(sql_path)) {
  message("Schema file not found: ", sql_path)
  quit(status = 1)
}

message("Initializing schema from: ", sql_path)

tryCatch({
  db_init_schema(conn, sql_path)
  message("Schema initialization complete!")
}, error = function(e) {
  message("Schema initialization failed: ", conditionMessage(e))
  quit(status = 1)
})

# Verify tables exist
tables <- DBI::dbListTables(conn)
expected <- c("submission", "response_numeric", "response_text", "score", "aggregate_norms")
found <- expected[expected %in% tables]
missing <- setdiff(expected, tables)

message("\nTables found: ", paste(found, collapse = ", "))
if (length(missing) > 0) {
  message("Tables missing: ", paste(missing, collapse = ", "))
  message("(Some tables may be created on first use)")
}

message("\nDatabase initialization complete.")
